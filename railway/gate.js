// Public-port gate for Railway. Returns 503 until bootstrap.sh has created the
// first administrator, then transparently proxies HTTP and WebSocket traffic to
// Silo on 127.0.0.1:$PORT.
'use strict';
const http = require('http');
const net = require('net');
const fs = require('fs');
const PUBLIC_PORT = parseInt(process.env.GATE_PORT || '8080', 10);
const UPSTREAM_PORT = parseInt(process.env.PORT || '8081', 10);
const READY = '/run/railway-bootstrap/ready';
let ready = false;
const isReady = () => ready || (ready = fs.existsSync(READY));

const server = http.createServer((req, res) => {
  if (!isReady()) {
    res.writeHead(503, { 'content-type': 'text/plain', 'retry-after': '10' });
    return res.end('Starting up: creating the administrator account. Try again shortly.\n');
  }
  const headers = { ...req.headers };
  const xff = headers['x-forwarded-for'];
  headers['x-forwarded-for'] = xff ? xff : req.socket.remoteAddress;
  if (!headers['x-forwarded-proto']) headers['x-forwarded-proto'] = 'https';
  const up = http.request({ host: '127.0.0.1', port: UPSTREAM_PORT, method: req.method, path: req.url, headers }, (ur) => {
    res.writeHead(ur.statusCode, ur.statusMessage, ur.rawHeaders);
    ur.pipe(res);
  });
  up.on('error', () => { if (!res.headersSent) res.writeHead(502); res.end(); });
  req.pipe(up);
});

server.on('upgrade', (req, socket, head) => {
  if (!isReady()) { socket.end('HTTP/1.1 503 Service Unavailable\r\n\r\n'); return; }
  const up = net.connect(UPSTREAM_PORT, '127.0.0.1', () => {
    let raw = `${req.method} ${req.url} HTTP/${req.httpVersion}\r\n`;
    for (let i = 0; i < req.rawHeaders.length; i += 2) raw += `${req.rawHeaders[i]}: ${req.rawHeaders[i + 1]}\r\n`;
    up.write(raw + '\r\n');
    if (head && head.length) up.write(head);
    socket.pipe(up).pipe(socket);
  });
  up.on('error', () => socket.destroy());
  socket.on('error', () => up.destroy());
});
server.keepAliveTimeout = 65000;
server.headersTimeout = 66000;
server.requestTimeout = 0;
server.listen(PUBLIC_PORT, '::', () => console.log(`[railway-gate] listening on :${PUBLIC_PORT}, upstream 127.0.0.1:${UPSTREAM_PORT}`));
