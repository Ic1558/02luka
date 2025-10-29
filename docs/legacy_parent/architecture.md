# 02luka Architecture (summary)
Gateways:
- MCP Docker Gateway (HTTP) : 5012
- FS MCP (stdio/JSON-RPC)  : 8765
- Ollama (OpenAI-compatible): 11434
- Bridge Daemon (internal), Redis Bridge (streams)

Luka (HTML) talks HTTP:
- MCP probe: `/.well-known/mcp/tools`
- Generic chat: `POST /chat`
- OpenAI-compatible: `POST /v1/chat/completions`
