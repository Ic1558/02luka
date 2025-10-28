import { assess } from "../../packages/security/secure_ocr.mjs";
import fs from "fs";
import os from "os";
import crypto from "crypto";

function sha256(s){return crypto.createHash("sha256").update(String(s)).digest("hex");}

export function guardOcr(rawText, {humanConfirm=false} = {}) {
  const res = assess(rawText);
  const line = JSON.stringify({
    ts: new Date().toISOString(),
    host: os.hostname(),
    risk: res.risk,
    matches: res.matches,
    hash: sha256(res.raw),
    humanConfirm
  }) + "\n";
  try {
    fs.mkdirSync(`${process.env.HOME}/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka/02luka-repo/g/telemetry`, {recursive:true});
    fs.appendFileSync(`${process.env.HOME}/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka/02luka-repo/g/telemetry/secure_ocr.ndjson`, line);
  } catch {}

  if (res.risk >= 0.8) return { allow:false, need_confirm:true, ...res };
  if (res.risk >= 0.6 && !humanConfirm) return { allow:false, need_confirm:true, ...res };
  return { allow:true, need_confirm:false, ...res };
}
