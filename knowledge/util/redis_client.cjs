#!/usr/bin/env node

const net = require('net');
const { EventEmitter } = require('events');
const { URL } = require('url');

function encodeCommand(args) {
  const parts = [`*${args.length}\r\n`];
  for (const arg of args) {
    const value = Buffer.isBuffer(arg) ? arg : Buffer.from(String(arg));
    parts.push(`$${value.length}\r\n`);
    parts.push(value);
    parts.push('\r\n');
  }
  return Buffer.concat(parts.map((part) => (typeof part === 'string' ? Buffer.from(part) : part)));
}

function parseSimple(buffer) {
  const end = buffer.indexOf('\r\n');
  if (end === -1) {
    return null;
  }
  const value = buffer.slice(1, end).toString();
  return { value, rest: buffer.slice(end + 2) };
}

function parseInteger(buffer) {
  const res = parseSimple(buffer);
  if (!res) return null;
  return { value: parseInt(res.value, 10), rest: res.rest };
}

function parseBulk(buffer) {
  const end = buffer.indexOf('\r\n');
  if (end === -1) return null;
  const size = parseInt(buffer.slice(1, end).toString(), 10);
  if (Number.isNaN(size)) {
    throw new Error('Invalid bulk string length');
  }
  if (size === -1) {
    return { value: null, rest: buffer.slice(end + 2) };
  }
  const start = end + 2;
  const stop = start + size;
  if (buffer.length < stop + 2) {
    return null;
  }
  const value = buffer.slice(start, stop).toString();
  return { value, rest: buffer.slice(stop + 2) };
}

function parseArray(buffer) {
  const end = buffer.indexOf('\r\n');
  if (end === -1) return null;
  const count = parseInt(buffer.slice(1, end).toString(), 10);
  if (Number.isNaN(count)) {
    throw new Error('Invalid array length');
  }
  let rest = buffer.slice(end + 2);
  const values = [];
  for (let i = 0; i < count; i += 1) {
    const parsed = parseRESP(rest);
    if (!parsed) {
      return null;
    }
    values.push(parsed.value);
    rest = parsed.rest;
  }
  return { value: values, rest };
}

function parseRESP(buffer) {
  if (!buffer || buffer.length === 0) return null;
  const prefix = buffer[0];
  switch (prefix) {
    case 43: // +
      return parseSimple(buffer);
    case 45: { // -
      const res = parseSimple(buffer);
      if (!res) return null;
      const err = new Error(res.value);
      err.code = 'REDIS_ERROR';
      return { value: err, rest: res.rest };
    }
    case 58: // :
      return parseInteger(buffer);
    case 36: // $
      return parseBulk(buffer);
    case 42: // *
      return parseArray(buffer);
    default:
      throw new Error(`Unsupported RESP prefix: ${String.fromCharCode(prefix)} (${prefix})`);
  }
}

function parseRedisUrl(urlString) {
  if (!urlString) {
    return {
      host: '127.0.0.1',
      port: 6379,
      db: 0,
    };
  }
  const url = new URL(urlString);
  const password = url.password ? decodeURIComponent(url.password) : undefined;
  const db = url.pathname && url.pathname.length > 1 ? Number(url.pathname.slice(1)) : 0;
  return {
    host: url.hostname,
    port: Number(url.port || 6379),
    password,
    db,
  };
}

class RedisCommandConnection {
  constructor(options = {}) {
    this.options = options;
    this.socket = null;
    this.buffer = Buffer.alloc(0);
    this.queue = [];
    this.connected = false;
    this.connecting = null;
  }

  async connect() {
    if (this.connected) {
      return;
    }
    if (this.connecting) {
      return this.connecting;
    }
    this.connecting = new Promise((resolve, reject) => {
      const { host, port } = this.options;
      const socket = net.createConnection({ host, port }, async () => {
        try {
          await this.performHandshake(socket);
          this.socket = socket;
          this.connected = true;
          this.connecting = null;
          socket.on('data', (chunk) => this.handleData(chunk));
          socket.on('error', (err) => this.handleError(err));
          socket.on('close', () => this.handleClose());
          resolve();
        } catch (err) {
          socket.destroy();
          this.connecting = null;
          reject(err);
        }
      });
      socket.on('error', (err) => {
        if (this.connecting) {
          this.connecting = null;
          reject(err);
        } else {
          this.handleError(err);
        }
      });
    });
    return this.connecting;
  }

  async performHandshake(socket) {
    const { password, db } = this.options;
    if (password) {
      await this.writeAndWait(socket, ['AUTH', password]);
    }
    if (typeof db === 'number' && db > 0) {
      await this.writeAndWait(socket, ['SELECT', db]);
    }
  }

  write(buffer) {
    if (!this.socket) {
      throw new Error('Socket not connected');
    }
    this.socket.write(buffer);
  }

  async writeAndWait(socket, args) {
    const command = encodeCommand(args);
    socket.write(command);
    const reply = await new Promise((resolve, reject) => {
      const onData = (chunk) => {
        this.buffer = Buffer.concat([this.buffer, chunk]);
        try {
          const parsed = parseRESP(this.buffer);
          if (!parsed) {
            return;
          }
          this.buffer = parsed.rest;
          socket.removeListener('data', onData);
          resolve(parsed.value);
        } catch (err) {
          socket.removeListener('data', onData);
          reject(err);
        }
      };
      socket.on('data', onData);
      socket.once('error', reject);
    });
    if (reply instanceof Error) {
      throw reply;
    }
    return reply;
  }

  async send(args) {
    await this.connect();
    return new Promise((resolve, reject) => {
      this.queue.push({ resolve, reject });
      try {
        const command = encodeCommand(args);
        this.socket.write(command);
      } catch (err) {
        this.queue.pop();
        reject(err);
      }
    });
  }

  handleData(chunk) {
    this.buffer = Buffer.concat([this.buffer, chunk]);
    while (this.buffer.length > 0 && this.queue.length > 0) {
      let parsed;
      try {
        parsed = parseRESP(this.buffer);
      } catch (err) {
        const pending = this.queue.shift();
        if (pending) {
          pending.reject(err);
        }
        this.buffer = Buffer.alloc(0);
        break;
      }
      if (!parsed) {
        break;
      }
      this.buffer = parsed.rest;
      const { resolve, reject } = this.queue.shift();
      if (parsed.value instanceof Error) {
        reject(parsed.value);
      } else {
        resolve(parsed.value);
      }
    }
  }

  handleError(err) {
    while (this.queue.length > 0) {
      const pending = this.queue.shift();
      pending.reject(err);
    }
    this.connected = false;
    if (this.socket) {
      this.socket.destroy();
      this.socket = null;
    }
  }

  handleClose() {
    this.connected = false;
    this.socket = null;
  }

  async quit() {
    if (!this.connected) {
      return;
    }
    try {
      await this.send(['QUIT']);
    } catch (err) {
      // ignore
    }
    if (this.socket) {
      this.socket.destroy();
    }
    this.connected = false;
  }
}

class RedisSubscriber extends EventEmitter {
  constructor(options = {}) {
    super();
    this.options = options;
    this.socket = null;
    this.buffer = Buffer.alloc(0);
    this.connected = false;
    this.connecting = null;
    this.active = new Set();
  }

  async connect() {
    if (this.connected) return;
    if (this.connecting) return this.connecting;
    this.connecting = new Promise((resolve, reject) => {
      const { host, port } = this.options;
      const socket = net.createConnection({ host, port }, async () => {
        try {
          await this.performHandshake(socket);
          this.socket = socket;
          this.connected = true;
          this.connecting = null;
          socket.on('data', (chunk) => this.handleData(chunk));
          socket.on('error', (err) => this.emit('error', err));
          socket.on('close', () => {
            this.connected = false;
            this.emit('close');
          });
          resolve();
        } catch (err) {
          socket.destroy();
          this.connecting = null;
          reject(err);
        }
      });
      socket.on('error', (err) => {
        if (this.connecting) {
          this.connecting = null;
          reject(err);
        } else {
          this.emit('error', err);
        }
      });
    });
    return this.connecting;
  }

  async performHandshake(socket) {
    const { password, db } = this.options;
    if (password) {
      await this.writeAndWait(socket, ['AUTH', password]);
    }
    if (typeof db === 'number' && db > 0) {
      await this.writeAndWait(socket, ['SELECT', db]);
    }
  }

  async writeAndWait(socket, args) {
    const command = encodeCommand(args);
    socket.write(command);
    const reply = await new Promise((resolve, reject) => {
      const onData = (chunk) => {
        this.buffer = Buffer.concat([this.buffer, chunk]);
        const parsed = parseRESP(this.buffer);
        if (!parsed) {
          return;
        }
        this.buffer = parsed.rest;
        socket.removeListener('data', onData);
        resolve(parsed.value);
      };
      socket.on('data', onData);
      socket.once('error', reject);
    });
    if (reply instanceof Error) {
      throw reply;
    }
    return reply;
  }

  async ensureConnection() {
    await this.connect();
    if (!this.socket) {
      throw new Error('Subscriber socket not ready');
    }
  }

  async subscribe(channel) {
    await this.ensureConnection();
    if (this.active.has(channel)) {
      return;
    }
    this.socket.write(encodeCommand(['SUBSCRIBE', channel]));
    this.active.add(channel);
  }

  async unsubscribe(channel) {
    if (!this.connected || !this.socket || !this.active.has(channel)) {
      return;
    }
    this.socket.write(encodeCommand(['UNSUBSCRIBE', channel]));
    this.active.delete(channel);
  }

  handleData(chunk) {
    this.buffer = Buffer.concat([this.buffer, chunk]);
    while (this.buffer.length > 0) {
      const parsed = parseRESP(this.buffer);
      if (!parsed) break;
      this.buffer = parsed.rest;
      const payload = parsed.value;
      if (Array.isArray(payload) && payload[0] === 'message') {
        const [, channel, message] = payload;
        this.emit('message', channel, message);
      } else if (payload instanceof Error) {
        this.emit('error', payload);
      } else {
        this.emit('meta', payload);
      }
    }
  }

  async quit() {
    if (!this.connected || !this.socket) {
      return;
    }
    try {
      await new Promise((resolve) => {
        this.socket.end(resolve);
      });
    } finally {
      this.connected = false;
      this.socket = null;
    }
  }
}

class RedisClient {
  constructor(options = {}) {
    const parsed = parseRedisUrl(options.url || process.env.REDIS_URL);
    this.options = { ...parsed, ...options };
    this.commands = new RedisCommandConnection(this.options);
  }

  async publish(channel, message) {
    const result = await this.commands.send(['PUBLISH', channel, message]);
    return Number(result) || 0;
  }

  async send(args) {
    return this.commands.send(args);
  }

  async quit() {
    await this.commands.quit();
  }
}

function createRedisClient(options = {}) {
  return new RedisClient(options);
}

function createRedisSubscriber(options = {}) {
  const parsed = parseRedisUrl(options.url || process.env.REDIS_URL);
  return new RedisSubscriber({ ...parsed, ...options });
}

module.exports = {
  createRedisClient,
  createRedisSubscriber,
  encodeCommand,
  parseRESP,
  parseRedisUrl,
};

if (require.main === module) {
  const url = process.env.REDIS_URL || 'redis://127.0.0.1:6379/0';
  console.log(`Redis helper ready for ${url}`);
}
