// Fake de la API de Ollama para tests/agentes/agentes.sh (CA-06 y CA-07 de
// spec 0086 (not in this snapshot)).
//
// uso: node fake-ollama.js <port_file> <requests_jsonl> <modo_file>
// Escucha en 127.0.0.1 con un puerto libre y lo escribe en <port_file>
// (tmp + rename, para que el test nunca lea un archivo a medias).
// GET /api/tags devuelve el modelo; POST /api/chat agrega el body a
// <requests_jsonl> y responde según el modo de <modo_file>, releído en cada
// request: ok | fuera | traversal | git | sin-schema | no-json.
'use strict';
const fs = require('fs');
const http = require('http');

const [portFile, requestsFile, modoFile] = process.argv.slice(2);
if (!portFile || !requestsFile || !modoFile) {
  process.stderr.write('uso: node fake-ollama.js <port_file> <requests_jsonl> <modo_file>\n');
  process.exit(2);
}

const MODEL = 'qwen2.5-coder:7b';
const resumen = 'fake-ollama';

function contenido(modo) {
  const hola = { path: 'salida.txt', contenido: 'hola\n' };
  switch (modo) {
    case 'ok': return JSON.stringify({ archivos: [hola], resumen });
    case 'fuera': return JSON.stringify({ archivos: [hola, { path: 'otro.txt', contenido: 'otro\n' }], resumen });
    case 'traversal': return JSON.stringify({ archivos: [hola, { path: '../x', contenido: 'x\n' }], resumen });
    case 'git': return JSON.stringify({ archivos: [hola, { path: '.git/hooks/x', contenido: 'x\n' }], resumen });
    case 'sin-schema': return JSON.stringify({ archivos: [hola] });
    case 'no-json': return 'esto no es JSON: salida.txt = hola';
    default: return 'modo desconocido: ' + modo;
  }
}

function leerModo() {
  try { return fs.readFileSync(modoFile, 'utf8').trim(); } catch (e) { return 'ok'; }
}

const server = http.createServer((req, res) => {
  const chunks = [];
  req.on('data', (c) => chunks.push(c));
  req.on('end', () => {
    const send = (code, obj) => {
      res.writeHead(code, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(obj));
    };
    if (req.method === 'GET' && req.url === '/api/tags') {
      return send(200, { models: [{ name: MODEL, model: MODEL }] });
    }
    if (req.method === 'POST' && req.url === '/api/chat') {
      const body = Buffer.concat(chunks).toString('utf8');
      let line = body;
      try { line = JSON.stringify(JSON.parse(body)); } catch (e) { line = JSON.stringify({ crudo: body }); }
      fs.appendFileSync(requestsFile, line + '\n');
      return send(200, {
        model: MODEL,
        created_at: '2026-10-27T00:00:00Z',
        message: { role: 'assistant', content: contenido(leerModo()) },
        done: true,
      });
    }
    return send(404, { error: 'no encontrado' });
  });
});

server.listen(0, '127.0.0.1', () => {
  const tmp = portFile + '.tmp';
  fs.writeFileSync(tmp, String(server.address().port) + '\n');
  fs.renameSync(tmp, portFile);
});

// Sin server.close(): esperaría a las conexiones keep-alive y el trap del
// test no puede quedar colgado.
const bye = () => process.exit(0);
process.on('SIGTERM', bye);
process.on('SIGINT', bye);
