// envo.js: the host for Envo programs built with `envoc build --target wasm32-web`
// (PLAN D49). It gives the program its one import, envo.host(k, a, b, c, d), whose
// functions are listed in compiler/runtime/wasm.envo, and runs it.
//
// Node.js:  node envo.js program.wasm [arguments…]
// Browser:  const r = await EnvoWeb.run(bytes, { args, stdout, stderr });
//
// Standard output and error go to callbacks (in Node, to the process's own); files open
// through Node's fs where there is one. The program's exit code is the result of run.
'use strict';

const EnvoWeb = (() => {
  // Thrown by host function 3 (exit) to unwind out of the program.
  class Exit {
    constructor(code) { this.code = code; }
  }

  async function run(bytes, options = {}) {
    const args = options.args || ['program'];
    const encoder = new TextEncoder();
    const argBytes = args.map((a) => encoder.encode(a));
    const stdout = options.stdout || (() => {});
    const stderr = options.stderr || (() => {});
    const stdin = options.stdin || (() => new Uint8Array(0));
    const fs = options.fs || null;
    let memory = null;
    const view = () => new Uint8Array(memory.buffer);
    const files = new Map();       // fd -> Node fd
    let nextFd = 3;
    let staged = new Uint8Array(0); // the last result too long to return (names, values)
    // a path the program gave; "" is the working directory
    const text = (p, len) => new TextDecoder().decode(view().slice(Number(p), Number(p) + Number(len))) || '.';
    // an fs error as an error kind: 1 not found, 2 exists, 3 not empty, 4 denied, 5 invalid, 6 other
    const errorKind = (e) => ({ ENOENT: 1, EEXIST: 2, ENOTEMPTY: 3, EACCES: 4, EPERM: 4, ENOTDIR: 5, EISDIR: 5, EINVAL: 5 })[e && e.code] || 6;
    const fsCall = (f) => {
      if (!fs) return -4n;
      try {
        f();
        return 0n;
      } catch (e) {
        return BigInt(-errorKind(e));
      }
    };

    function host(k, a, b, c, d) {
      const n = (x) => Number(BigInt.asIntN(64, x));
      switch (Number(k)) {
        case 0: {                  // grow the memory by a bytes
          const pages = Math.ceil(n(a) / 65536);
          const old = memory.grow(pages);
          return old < 0 ? -1n : BigInt(old) * 65536n;
        }
        case 1: {                  // write(fd, ptr, len)
          const bytes = view().slice(n(b), n(b) + n(c));
          const fd = n(a);
          if (fd === 1) stdout(bytes);
          else if (fd === 2) stderr(bytes);
          else if (files.has(fd) && fs) fs.writeSync(files.get(fd), bytes);
          else return -1n;
          return c;
        }
        case 2: {                  // read(fd, ptr, len)
          const fd = n(a);
          const into = view().subarray(n(b), n(b) + n(c));
          if (fd === 0) {
            const got = stdin(into.length);
            into.set(got.subarray(0, into.length));
            return BigInt(Math.min(got.length, into.length));
          }
          if (files.has(fd) && fs) return BigInt(fs.readSync(files.get(fd), into, 0, into.length, null));
          return -1n;
        }
        case 3:                    // exit(code)
          throw new Exit(n(a));
        case 4:                    // the argument count
          return BigInt(argBytes.length);
        case 5:                    // argument a's length
          return BigInt(argBytes[n(a)].length);
        case 6:                    // copy argument a to ptr b
          view().set(argBytes[n(a)], n(b));
          return 0n;
        case 7: {                  // open(ptr, len, mode): 0 read, 1 or 2 write
          if (!fs) return -1n;
          const path = new TextDecoder().decode(view().slice(n(a), n(a) + n(b)));
          try {
            const nodeFd = fs.openSync(path, n(c) === 0 ? 'r' : 'w', n(c) === 2 ? 0o755 : 0o644);
            const fd = nextFd++;
            files.set(fd, nodeFd);
            return BigInt(fd);
          } catch (e) {
            return -1n;
          }
        }
        case 8: {                  // close(fd)
          const fd = n(a);
          if (files.has(fd) && fs) fs.closeSync(files.get(fd));
          files.delete(fd);
          return 0n;
        }
        case 9: {                  // stat(ptr, len): 0 nothing, 1 file, 2 directory
          if (!fs) return 0n;
          try {
            const st = fs.statSync(text(a, b));
            return st.isDirectory() ? 2n : st.isFile() ? 1n : 0n;
          } catch (e) {
            return 0n;
          }
        }
        case 10:                   // delete(ptr, len)
          return fsCall(() => fs.unlinkSync(text(a, b)));
        case 11:                   // mkdir(ptr, len)
          return fsCall(() => fs.mkdirSync(text(a, b)));
        case 12:                   // rmdir(ptr, len)
          return fsCall(() => fs.rmdirSync(text(a, b)));
        case 13: {                 // list(ptr, len): names, one per line, staged
          if (!fs) return -1n;
          try {
            const names = fs.readdirSync(text(a, b)).map((x) => encoder.encode(x));
            names.sort((x, y) => Buffer.compare(Buffer.from(x), Buffer.from(y)));
            const parts = [];
            for (const x of names) parts.push(...x, 10);
            staged = new Uint8Array(parts);
            return BigInt(staged.length);
          } catch (e) {
            return BigInt(-errorKind(e));
          }
        }
        case 14:                   // copy the staged bytes to ptr
          view().set(staged, n(a));
          return 0n;
        case 15:                   // now, nanoseconds since 1970
          return BigInt(Date.now()) * 1000000n;
        case 16:                   // a clock that never goes back
          return typeof process !== 'undefined' && process.hrtime ? process.hrtime.bigint() : BigInt(Math.floor(performance.now() * 1e6));
        case 17: {                 // random(ptr, len)
          const into = view().subarray(n(a), n(a) + n(b));
          for (let at = 0; at < into.length; at += 65536) crypto.getRandomValues(into.subarray(at, Math.min(at + 65536, into.length)));
          return 0n;
        }
        case 18: {                 // getenv(ptr, len): the value staged, or -1
          const env = options.env || (typeof process !== 'undefined' ? process.env : {});
          const v = env[text(a, b)];
          if (v === undefined) return -1n;
          staged = encoder.encode(v);
          return BigInt(staged.length);
        }
        case 19:                   // the working directory, staged
          staged = encoder.encode(options.cwd || (typeof process !== 'undefined' ? process.cwd() : '/'));
          return BigInt(staged.length);
        default:
          return -1n;
      }
    }

    const { instance } = await WebAssembly.instantiate(bytes, { envo: { host } });
    memory = instance.exports.memory;
    try {
      instance.exports._start();
      return 0;
    } catch (e) {
      if (e instanceof Exit) return e.code;
      throw e;
    }
  }

  // A file system in memory, for a page (or a test): files maps paths to bytes, and the
  // program's writes land in it. It answers the calls run makes of Node's fs.
  function memoryFs(files) {
    const open = new Map();
    let next = 100;
    const norm = (p) => p.replace(/\\/g, '/').replace(/^\.\//, '');
    const fail = (code) => Object.assign(new Error(code), { code });
    const isDir = (p) => p === '.' || p === '' || [...files.keys()].some((k) => k.startsWith(p + '/'));
    return {
      openSync(path, flags) {
        const p = norm(path);
        if (flags === 'r') {
          if (!files.has(p)) throw fail('ENOENT');
        } else {
          files.set(p, new Uint8Array(0));
        }
        open.set(next, { p, pos: 0 });
        return next++;
      },
      readSync(fd, buf, off, len) {
        const f = open.get(fd);
        const data = files.get(f.p);
        const n = Math.max(0, Math.min(len, data.length - f.pos));
        buf.set(data.subarray(f.pos, f.pos + n), off);
        f.pos += n;
        return n;
      },
      writeSync(fd, bytes) {
        const f = open.get(fd);
        const old = files.get(f.p);
        const grown = new Uint8Array(old.length + bytes.length);
        grown.set(old);
        grown.set(bytes, old.length);
        files.set(f.p, grown);
        return bytes.length;
      },
      closeSync(fd) {
        open.delete(fd);
      },
      statSync(path) {
        const p = norm(path);
        if (files.has(p)) return { isFile: () => true, isDirectory: () => false };
        if (isDir(p)) return { isFile: () => false, isDirectory: () => true };
        throw fail('ENOENT');
      },
      unlinkSync(path) {
        if (!files.delete(norm(path))) throw fail('ENOENT');
      },
      mkdirSync() {},
      rmdirSync() {},
      readdirSync(path) {
        const p = norm(path);
        const pre = p === '.' || p === '' ? '' : p + '/';
        const names = new Set();
        for (const k of files.keys()) if (k.startsWith(pre)) names.add(k.slice(pre.length).split('/')[0]);
        return [...names];
      },
    };
  }

  return { run, memoryFs };
})();

if (typeof module !== 'undefined' && module.exports) module.exports = EnvoWeb;

// Node.js: run the program named on the command line.
if (typeof require !== 'undefined' && typeof process !== 'undefined' && require.main === module) {
  const fs = require('fs');
  const path = process.argv[2];
  if (!path) {
    process.stderr.write('usage: node envo.js program.wasm [arguments…]\n');
    process.exit(2);
  }
  const bytes = fs.readFileSync(path);
  const writeAll = (fd) => (b) => {
    let at = 0;
    while (at < b.length) at += fs.writeSync(fd, b, at, b.length - at);
  };
  const stdin = (max) => {
    const buf = Buffer.alloc(max);
    try {
      const n = fs.readSync(0, buf, 0, max, null);
      return buf.subarray(0, n);
    } catch (e) {
      return new Uint8Array(0);
    }
  };
  EnvoWeb.run(bytes, { args: [path, ...process.argv.slice(3)], stdout: writeAll(1), stderr: writeAll(2), stdin, fs })
    .then((code) => {
      // Node ends on its own: process.exit() here can trip libuv on Windows
      process.exitCode = code;
    })
    .catch((e) => {
      process.stderr.write(`envo.js: ${e && e.stack ? e.stack : e}\n`);
      process.exitCode = 70;
    });
}
