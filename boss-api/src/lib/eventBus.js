import { EventEmitter } from 'node:events';

const emitter = new EventEmitter();
const clients = new Set();

function send(res, payload) {
  res.write(`data: ${JSON.stringify(payload)}\n\n`);
}

export function publish(event) {
  emitter.emit('event', event);
}

export function registerClient(res) {
  clients.add(res);
  res.on('close', () => {
    clients.delete(res);
  });
}

emitter.on('event', (event) => {
  for (const client of clients) {
    try {
      send(client, event);
    } catch (error) {
      client.end();
      clients.delete(client);
    }
  }
});

export function clientCount() {
  return clients.size;
}

