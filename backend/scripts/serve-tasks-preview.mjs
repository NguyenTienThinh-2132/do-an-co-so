import { createServer, request as proxyRequest } from 'node:http';
import { createReadStream, existsSync, statSync } from 'node:fs';
import { resolve, relative, extname, isAbsolute } from 'node:path';
import { fileURLToPath } from 'node:url';
import { NestFactory } from '@nestjs/core';
import { AppModule } from '../dist/app.module.js';

// Server xem thử riêng, không đổi main/CORS của backend.
const root = fileURLToPath(new URL('../../build/tasks_preview_host/build/web/', import.meta.url));
if (!existsSync(resolve(root, 'index.html'))) {
  throw new Error('Cần build web preview host trước.');
}
const app = await NestFactory.create(AppModule, { logger: false, abortOnError: false });
await app.listen(0, '127.0.0.1');
const backend = new URL(await app.getUrl());
const types = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript',
  '.json': 'application/json', '.wasm': 'application/wasm',
  '.png': 'image/png', '.svg': 'image/svg+xml', '.ttf': 'font/ttf',
  '.woff2': 'font/woff2', '.otf': 'font/otf',
};
const server = createServer((req, res) => {
  try {
    const url = new URL(req.url, 'http://127.0.0.1:3111');
    if (url.pathname === '/api' || url.pathname.startsWith('/api/')) {
      const upstream = proxyRequest({
        hostname: '127.0.0.1', port: backend.port,
        path: url.pathname.slice(4) + url.search || '/',
        method: req.method, headers: { ...req.headers, host: backend.host },
      }, (reply) => {
        res.writeHead(reply.statusCode, reply.headers);
        reply.pipe(res);
      });
      upstream.on('error', () => { if (!res.headersSent) res.writeHead(502); res.end(); });
      req.pipe(upstream);
      return;
    }
    const path = resolve(root, '.' + decodeURIComponent(url.pathname === '/' ? '/index.html' : url.pathname));
    const rel = relative(root, path);
    if (rel.startsWith('..') || isAbsolute(rel) || !existsSync(path) || !statSync(path).isFile()) {
      res.writeHead(404); res.end(); return;
    }
    res.writeHead(200, { 'Content-Type': types[extname(path)] || 'application/octet-stream',
      'Cache-Control': 'no-store' });
    const stream = createReadStream(path);
    stream.on('error', () => res.destroy());
    stream.pipe(res);
  } catch { res.writeHead(400); res.end(); }
});
server.on('error', async () => { await app.close(); process.exitCode = 1; });
server.listen(3111, '127.0.0.1', () => console.log('PREVIEW_URL: http://127.0.0.1:3111'));
for (const signal of ['SIGINT', 'SIGTERM']) {
  process.on(signal, () => server.close(async () => { await app.close(); process.exit(0); }));
}