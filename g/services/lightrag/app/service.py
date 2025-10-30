import asyncio
import glob
import json
import logging
import os
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Dict, List, Optional, Any

import yaml
from fastapi import FastAPI, HTTPException
from fastapi.concurrency import run_in_threadpool
from pydantic import BaseModel

from lightrag import Lightrag

try:
    from redis.asyncio import Redis
except ImportError:  # pragma: no cover - redis optional at import time
    Redis = None  # type: ignore


LOGGER = logging.getLogger("lightrag.service")
logging.basicConfig(level=logging.INFO)

BASE = Path(os.environ.get("LT_BASE", str(Path.home() / "02luka/g/services/lightrag")))
CFG = BASE / "config" / "agents.yaml"
DEFAULT_INDEX_BASE = BASE / "indexes"

REDIS_URL = os.environ.get("LT_REDIS_URL", "redis://127.0.0.1:6379/0")
REDIS_DISABLED = os.environ.get("LT_REDIS_DISABLE", "0").lower() in {"1", "true", "yes", "on"}
REDIS_CHANNEL_INGEST = os.environ.get("LT_REDIS_CHANNEL_INGEST", "lightrag:ingest")
REDIS_CHANNEL_QUERY = os.environ.get("LT_REDIS_CHANNEL_QUERY", "lightrag:query")
REDIS_CHANNEL_RELOAD = os.environ.get("LT_REDIS_CHANNEL_RELOAD", "lightrag:reload")
REDIS_CHANNEL_RESULTS_QUERY = os.environ.get("LT_REDIS_CHANNEL_RESULTS_QUERY", "lightrag:query:results")
REDIS_CHANNEL_RESULTS_INGEST = os.environ.get("LT_REDIS_CHANNEL_RESULTS_INGEST", "lightrag:ingest:results")


class QueryReq(BaseModel):
    agent: str
    q: str
    top_k: int = 5


class IngestReq(BaseModel):
    agent: str
    sources: Optional[List[str]] = None


def _load_cfg() -> Dict[str, Any]:
    if not CFG.exists():
        raise RuntimeError(f"config file missing: {CFG}")
    with open(CFG, "r", encoding="utf-8") as handle:
        return yaml.safe_load(handle) or {}


CONFIG_DATA = _load_cfg()
AGENTS: Dict[str, Dict[str, Any]] = CONFIG_DATA.get("agents", {}) or {}
INDEX_BASE = Path(os.path.expanduser(CONFIG_DATA.get("index_base", str(DEFAULT_INDEX_BASE))))
EMBED_MODEL = CONFIG_DATA.get("embedding_model", "text-embedding-3-small")
LLM_MODEL = CONFIG_DATA.get("llm_model", "gpt-4o-mini")

LT: Dict[str, Lightrag] = {}
CONFIG_LOCK = asyncio.Lock()
REDIS_CLIENT: Optional[Redis] = None
REDIS_LISTENER_TASK: Optional[asyncio.Task] = None


def expand_globs(patterns: List[str]) -> List[str]:
    files: List[str] = []
    for pattern in patterns:
        expanded = glob.glob(os.path.expanduser(pattern), recursive=True)
        files.extend([path for path in expanded if os.path.isfile(path)])
    deduped = sorted(set(files))
    LOGGER.debug("expand_globs(%s) -> %s", patterns, len(deduped))
    return deduped


def _reset_cache(changed_models: bool, new_agents: Dict[str, Dict[str, Any]]) -> None:
    global LT
    if changed_models:
        LT.clear()
        return
    for agent in list(LT.keys()):
        if agent not in new_agents:
            LT.pop(agent, None)


def _apply_config(config_data: Dict[str, Any]) -> None:
    global CONFIG_DATA, AGENTS, INDEX_BASE, EMBED_MODEL, LLM_MODEL
    new_agents = config_data.get("agents", {}) or {}
    new_index_base = Path(os.path.expanduser(config_data.get("index_base", str(DEFAULT_INDEX_BASE))))
    new_embed = config_data.get("embedding_model", EMBED_MODEL)
    new_llm = config_data.get("llm_model", LLM_MODEL)

    changed_models = new_embed != EMBED_MODEL or new_llm != LLM_MODEL or new_index_base != INDEX_BASE
    _reset_cache(changed_models, new_agents)

    CONFIG_DATA = config_data
    AGENTS = new_agents
    INDEX_BASE = new_index_base
    EMBED_MODEL = new_embed
    LLM_MODEL = new_llm


async def reload_config() -> Dict[str, Any]:
    async with CONFIG_LOCK:
        config_data = _load_cfg()
        _apply_config(config_data)
        LOGGER.info("Config reloaded. Agents: %s", ", ".join(sorted(AGENTS.keys())))
        return config_data


def lt_for(agent: str) -> Lightrag:
    if agent not in AGENTS:
        raise HTTPException(status_code=404, detail=f"unknown agent: {agent}")
    if agent not in LT:
        agent_idx = INDEX_BASE / agent
        agent_idx.mkdir(parents=True, exist_ok=True)
        LT[agent] = Lightrag(embedding_model=EMBED_MODEL, llm_model=LLM_MODEL, index_path=str(agent_idx))
    return LT[agent]


async def ingest_agent(agent: str, sources: Optional[List[str]] = None) -> Dict[str, Any]:
    cfg = AGENTS.get(agent)
    if not cfg:
        raise HTTPException(status_code=404, detail=f"unknown agent: {agent}")
    patterns = sources if sources is not None else cfg.get("sources", [])
    files = expand_globs(patterns)
    if not files:
        raise HTTPException(status_code=400, detail=f"no files matched for {agent}")
    rag = lt_for(agent)
    await run_in_threadpool(rag.ingest, files)
    LOGGER.info("Ingested %s documents for %s", len(files), agent)
    return {"agent": agent, "ingested": len(files), "sources": patterns}


async def query_agent(agent: str, question: str, top_k: int = 5) -> Dict[str, Any]:
    rag = lt_for(agent)
    answer = await run_in_threadpool(rag.query, question, top_k)
    LOGGER.info("Query for %s (top_k=%s)", agent, top_k)
    return {"agent": agent, "q": question, "top_k": top_k, "answer": answer}


async def publish(redis: Redis, channel: str, payload: Dict[str, Any]) -> None:
    data = json.dumps(payload)
    await redis.publish(channel, data)


async def _handle_redis_message(message: Dict[str, Any]) -> None:
    if message.get("type") != "message":
        return
    channel = message.get("channel")
    data = message.get("data")
    if isinstance(channel, bytes):
        channel = channel.decode()
    if isinstance(data, bytes):
        data = data.decode()
    try:
        payload = json.loads(data)
    except Exception as exc:  # pragma: no cover - defensive guard
        LOGGER.error("Invalid payload on %s: %s", channel, exc)
        return

    reply_channel = payload.get("reply_channel")
    request_id = payload.get("request_id")
    result: Dict[str, Any]

    try:
        if channel == REDIS_CHANNEL_INGEST:
            result = await ingest_agent(payload["agent"], payload.get("sources"))
        elif channel == REDIS_CHANNEL_QUERY:
            top_k = int(payload.get("top_k", 5))
            result = await query_agent(payload["agent"], payload["q"], top_k=top_k)
        elif channel == REDIS_CHANNEL_RELOAD:
            await reload_config()
            result = {"status": "reloaded", "agents": list(AGENTS.keys())}
        else:  # pragma: no cover - unknown channel guard
            LOGGER.warning("Ignoring unknown channel %s", channel)
            return
        if request_id is not None:
            result["request_id"] = request_id
        publish_channel = reply_channel or (
            REDIS_CHANNEL_RESULTS_QUERY if channel == REDIS_CHANNEL_QUERY else REDIS_CHANNEL_RESULTS_INGEST
        )
        if REDIS_CLIENT is not None:
            await publish(REDIS_CLIENT, publish_channel, {"ok": True, **result})
    except Exception as exc:  # pragma: no cover - runtime error path
        LOGGER.exception("Redis command failed")
        if REDIS_CLIENT is not None and (reply_channel or channel in {REDIS_CHANNEL_QUERY, REDIS_CHANNEL_INGEST}):
            publish_channel = reply_channel or (
                REDIS_CHANNEL_RESULTS_QUERY if channel == REDIS_CHANNEL_QUERY else REDIS_CHANNEL_RESULTS_INGEST
            )
            error_payload = {
                "ok": False,
                "error": str(exc),
                "channel": channel,
                "request_id": request_id,
            }
            await publish(REDIS_CLIENT, publish_channel, error_payload)


async def redis_listener(redis: Redis) -> None:
    pubsub = redis.pubsub()
    await pubsub.subscribe(REDIS_CHANNEL_INGEST, REDIS_CHANNEL_QUERY, REDIS_CHANNEL_RELOAD)
    LOGGER.info(
        "Subscribed to redis channels: %s", ", ".join([REDIS_CHANNEL_INGEST, REDIS_CHANNEL_QUERY, REDIS_CHANNEL_RELOAD])
    )
    try:
        async for message in pubsub.listen():  # type: ignore[attr-defined]
            await _handle_redis_message(message)
    finally:
        await pubsub.close()


async def start_redis_listener() -> None:
    global REDIS_CLIENT, REDIS_LISTENER_TASK
    if REDIS_DISABLED:
        LOGGER.info("Redis integration disabled via LT_REDIS_DISABLE")
        return
    if Redis is None:
        LOGGER.warning("redis-py is not installed; skipping Redis integration")
        return
    client = Redis.from_url(REDIS_URL)
    try:
        await client.ping()
    except Exception as exc:
        LOGGER.error("Unable to connect to redis at %s: %s", REDIS_URL, exc)
        await client.close()
        return
    REDIS_CLIENT = client
    REDIS_LISTENER_TASK = asyncio.create_task(redis_listener(client))


async def stop_redis_listener() -> None:
    global REDIS_CLIENT, REDIS_LISTENER_TASK
    if REDIS_LISTENER_TASK is not None:
        REDIS_LISTENER_TASK.cancel()
        try:
            await REDIS_LISTENER_TASK
        except asyncio.CancelledError:  # pragma: no cover
            pass
        REDIS_LISTENER_TASK = None
    if REDIS_CLIENT is not None:
        await REDIS_CLIENT.close()
        REDIS_CLIENT = None


@asynccontextmanager
async def lifespan(_: FastAPI):
    await start_redis_listener()
    try:
        yield
    finally:
        await stop_redis_listener()


app = FastAPI(title="02LUKA Lightrag Service", lifespan=lifespan)


@app.get("/health")
async def health() -> Dict[str, Any]:
    return {"ok": True, "agents": list(AGENTS.keys())}


@app.post("/ingest")
async def ingest(req: IngestReq) -> Dict[str, Any]:
    return await ingest_agent(req.agent, req.sources)


@app.post("/query")
async def query(req: QueryReq) -> Dict[str, Any]:
    return await query_agent(req.agent, req.q, top_k=req.top_k)


@app.post("/reload-config")
async def reload_endpoint() -> Dict[str, Any]:
    data = await reload_config()
    return {"ok": True, "agents": list(data.get("agents", {}).keys())}


__all__ = ["app"]
