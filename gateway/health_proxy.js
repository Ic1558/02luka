// Simple health proxy for smoke tests
const http = require('http');

const port = process.env.PORT || 3002;

const requestListener = (req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ ok: true }));
  } else if (req.url === '/metrics') {
    res.writeHead(200, { 'Content-Type': 'text/plain' });
    res.end('service_up 1\n');
  } else {
    res.writeHead(404);
    res.end();
  }
};

const server = http.createServer(requestListener);

server.listen(port, () => {
  console.log(`Health proxy running on port ${port}`);
});
