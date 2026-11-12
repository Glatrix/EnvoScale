// lsp.js: a Language Server Protocol client over a child process's standard streams, in
// plain Node.js (no npm packages). It frames JSON-RPC messages with Content-Length headers,
// matches responses to requests, hands notifications to the caller, and answers requests
// from the server it does not know with null. It knows nothing of VS Code, so tests drive
// it directly (test/session.test.js).
'use strict';
const { spawn } = require('child_process');

// One message as the protocol frames it.
function frame(message) {
  const body = Buffer.from(JSON.stringify(message), 'utf8');
  return Buffer.concat([Buffer.from(`Content-Length: ${body.length}\r\n\r\n`, 'ascii'), body]);
}

// Splits a stream of bytes into messages: push chunks in as they come; onMessage gets
// each whole message, parsed. Bytes that do not parse are dropped with onError.
class Framer {
  constructor(onMessage, onError = () => {}) {
    this.buf = Buffer.alloc(0);
    this.onMessage = onMessage;
    this.onError = onError;
  }

  push(chunk) {
    this.buf = Buffer.concat([this.buf, chunk]);
    for (;;) {
      const end = this.buf.indexOf('\r\n\r\n');
      if (end < 0) return;
      const head = this.buf.subarray(0, end).toString('ascii');
      const m = /Content-Length:\s*(\d+)/i.exec(head);
      if (!m) {
        // not a header: skip past it
        this.onError(new Error(`bad header: ${head}`));
        this.buf = this.buf.subarray(end + 4);
        continue;
      }
      const len = parseInt(m[1], 10);
      if (this.buf.length < end + 4 + len) return;
      const body = this.buf.subarray(end + 4, end + 4 + len).toString('utf8');
      this.buf = this.buf.subarray(end + 4 + len);
      let msg;
      try {
        msg = JSON.parse(body);
      } catch (e) {
        this.onError(e);
        continue;
      }
      this.onMessage(msg);
    }
  }
}

// A client of one server process: `new Client(command, args, options)`, then `start()`.
// options: onNotification(method, params), onLog(text), onExit(code), cwd.
class Client {
  constructor(command, args, options = {}) {
    this.command = command;
    this.args = args;
    this.options = options;
    this.nextId = 1;
    this.pending = new Map();
    this.proc = null;
    this.capabilities = null;
  }

  // Starts the server and initializes it; resolves to its capabilities, or rejects if it
  // cannot be started.
  start(rootUri = null) {
    return new Promise((resolve, reject) => {
      let proc;
      try {
        proc = spawn(this.command, this.args, { cwd: this.options.cwd, stdio: ['pipe', 'pipe', 'pipe'] });
      } catch (e) {
        reject(e);
        return;
      }
      this.proc = proc;
      const framer = new Framer((m) => this.receive(m), (e) => this.log(`envo lsp: ${e.message}`));
      proc.stdout.on('data', (c) => framer.push(c));
      proc.stderr.on('data', (c) => this.log(c.toString('utf8')));
      proc.on('error', (e) => {
        this.failAll(e);
        reject(e);
      });
      proc.on('exit', (code) => {
        this.failAll(new Error(`envo lsp exited (${code})`));
        this.proc = null;
        if (this.options.onExit) this.options.onExit(code);
      });
      this.request('initialize', { processId: process.pid, rootUri, capabilities: {} })
        .then((r) => {
          this.capabilities = (r && r.capabilities) || {};
          this.notify('initialized', {});
          resolve(this.capabilities);
        })
        .catch(reject);
    });
  }

  log(text) {
    if (this.options.onLog) this.options.onLog(text);
  }

  send(message) {
    if (!this.proc) return false;
    if (this.options.trace) this.log(`-> ${JSON.stringify(message)}`);
    this.proc.stdin.write(frame(message));
    return true;
  }

  // A request; resolves to its result, rejects with its error.
  request(method, params) {
    const id = this.nextId++;
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
      if (!this.send({ jsonrpc: '2.0', id, method, params })) {
        this.pending.delete(id);
        reject(new Error('envo lsp is not running'));
      }
    });
  }

  notify(method, params) {
    this.send({ jsonrpc: '2.0', method, params });
  }

  receive(m) {
    if (this.options.trace) this.log(`<- ${JSON.stringify(m)}`);
    if (m.id !== undefined && m.method === undefined) {
      const p = this.pending.get(m.id);
      if (!p) return;
      this.pending.delete(m.id);
      if (m.error) p.reject(Object.assign(new Error(m.error.message), { code: m.error.code }));
      else p.resolve(m.result === undefined ? null : m.result);
      return;
    }
    if (m.id !== undefined) {
      // a request from the server: nothing here needs answering with more than null
      this.send({ jsonrpc: '2.0', id: m.id, result: null });
      return;
    }
    if (this.options.onNotification) this.options.onNotification(m.method, m.params);
  }

  failAll(e) {
    for (const p of this.pending.values()) p.reject(e);
    this.pending.clear();
  }

  // Asks the server to shut down and exit; resolves once it has (or after a second).
  async stop() {
    if (!this.proc) return;
    const proc = this.proc;
    const gone = new Promise((done) => proc.once('exit', done));
    try {
      await Promise.race([this.request('shutdown', null), new Promise((r) => setTimeout(r, 1000))]);
    } catch (e) {
      // it may have gone already
    }
    this.notify('exit', null);
    const timer = setTimeout(() => proc.kill(), 1000);
    await gone;
    clearTimeout(timer);
  }
}

module.exports = { Client, Framer, frame };
