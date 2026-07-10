// 웹 빌드 로컬 테스트 서버 (COOP/COEP 헤더 포함 - 스레드 빌드도 동작)
// 사용법: node tools/serve.mjs [포트]   (기본 8060)
import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import { extname, join, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(fileURLToPath(new URL(".", import.meta.url)), "..", "builds", "web");
const port = Number(process.argv[2] ?? 8060);

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript",
  ".wasm": "application/wasm",
  ".pck": "application/octet-stream",
  ".png": "image/png",
  ".ico": "image/x-icon",
  ".svg": "image/svg+xml",
  ".css": "text/css",
  ".json": "application/json",
  ".mp3": "audio/mpeg",
  ".ogg": "audio/ogg",
  ".wav": "audio/wav",
};

createServer(async (req, res) => {
  let pathname = decodeURIComponent(new URL(req.url, "http://localhost").pathname);
  if (pathname.endsWith("/")) pathname += "index.html";
  const file = resolve(join(root, pathname));
  if (!file.startsWith(root + sep) && file !== root) {
    res.writeHead(403);
    return res.end("403");
  }
  try {
    const body = await readFile(file);
    res.writeHead(200, {
      "Content-Type": MIME[extname(file).toLowerCase()] ?? "application/octet-stream",
      "Cross-Origin-Opener-Policy": "same-origin",
      "Cross-Origin-Embedder-Policy": "require-corp",
      "Cache-Control": "no-store",
    });
    res.end(body);
  } catch {
    res.writeHead(404);
    res.end("404 - 먼저 웹 내보내기를 실행하세요 (builds/web)");
  }
}).listen(port, () => {
  console.log(`builds/web 서빙 중: http://localhost:${port}`);
});
