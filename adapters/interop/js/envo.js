// envo.js: the host for Envo programs built with `envoc build --target wasm32-web`
// (PLAN D49). It gives the program its one import, envo.host(k, a, b, c, d), whose
// functions are listed in compiler/runtime/wasm.envo, and runs it.
//
// Node.js:  node envo.js program.wasm [arguments…]
// Browser:  const r = await EnvoWeb.run(bytes, { args, stdout, stderr, canvas });
//
// Standard output and error go to callbacks (in Node, to the process's own); files open
// through Node's fs where there is one. The program's exit code is the result of run.
//
// With a canvas, the program's Window port draws on it and gets its keys and pointer
// (the browser host, PLAN D72, M14.8). A program's loop polls for events without end; in
// a browser with JSPI (WebAssembly.Suspending), a poll that finds nothing waits for the
// next animation frame, so the page stays alive. Without JSPI a windowed program would
// hold the page: EnvoWeb.canYield() tells a page to say so instead of running it.
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
    const win = options.canvas ? canvasWindow(options.canvas, options) : null;
    const yields = win !== null && canYield();
    let clip = null;                // the clipboard, within the page
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
        case 20:                   // window open(title ptr, len, width, height): 1, or 0 for none
          if (!win || win.isOpen()) return 0n;
          win.open(new TextDecoder().decode(view().slice(n(a), n(a) + n(b))), n(c), n(d));
          return 1n;
        case 21: {                 // window poll(ptr): 1 and an event there, or 0
          if (!win || !win.isOpen()) return 0n;
          const e = win.next();
          if (e) {
            const v = new DataView(memory.buffer, n(a), 20);
            e.forEach((x, i) => v.setInt32(4 * i, x, true));
            return 1n;
          }
          // nothing: wait for the next frame, if the program can wait
          if (yields) return new Promise((done) => win.frame(() => done(0n)));
          return 0n;
        }
        case 22:                   // window present(ptr, width, height)
          if (win && win.isOpen()) win.present(view().slice(n(a), n(a) + n(b) * n(c) * 4), n(b), n(c));
          return 0n;
        case 23:                   // window title(ptr, len)
          if (win) win.title(new TextDecoder().decode(view().slice(n(a), n(a) + n(b))));
          return 0n;
        case 24:                   // window close
          if (win) win.close();
          return 0n;
        case 25:                   // window size: width << 16 | height
          return win ? BigInt(win.width()) * 65536n + BigInt(win.height()) : 0n;
        case 26:                   // clipboard text: its length staged, or -1
          if (clip === null) return -1n;
          staged = encoder.encode(clip);
          return BigInt(staged.length);
        case 27:                   // clipboard set(ptr, len)
          clip = new TextDecoder().decode(view().slice(n(a), n(a) + n(b)));
          try {
            if (typeof navigator !== 'undefined' && navigator.clipboard) navigator.clipboard.writeText(clip).catch(() => {});
          } catch (e) { /* the page keeps its own copy */ }
          return 1n;
        default:
          return -1n;
      }
    }

    const imports = { envo: { host: yields ? new WebAssembly.Suspending(host) : host } };
    const { instance } = await WebAssembly.instantiate(bytes, imports);
    memory = instance.exports.memory;
    try {
      if (yields) await WebAssembly.promising(instance.exports._start)();
      else instance.exports._start();
      return 0;
    } catch (e) {
      if (e instanceof Exit) return e.code;
      throw e;
    } finally {
      if (win) win.close();
    }
  }

  // Whether a program can wait for the page (JSPI): windowed programs need it.
  function canYield() {
    return typeof WebAssembly.Suspending === 'function' && typeof WebAssembly.promising === 'function';
  }

  // The port's key codes (lib/ports: KEY_*) for KeyboardEvent.key and .code.
  const KEYS = {
    Backspace: 8, Tab: 9, Enter: 13, Shift: 16, Control: 17, Alt: 18, Escape: 27, ' ': 32,
    PageUp: 33, PageDown: 34, End: 35, Home: 36, ArrowLeft: 37, ArrowUp: 38, ArrowRight: 39,
    ArrowDown: 40, Insert: 45, Delete: 46,
  };
  function keyCode(e) {
    if (KEYS[e.key] !== undefined) return KEYS[e.key];
    const c = e.code || '';
    if (/^Key[A-Z]$/.test(c)) return c.charCodeAt(3);
    if (/^Digit[0-9]$/.test(c)) return c.charCodeAt(5);
    const f = /^F([0-9]+)$/.exec(e.key || '');
    if (f && +f[1] >= 1 && +f[1] <= 12) return 111 + +f[1];
    return 0;
  }
  const mods = (e) => (e.shiftKey ? 1 : 0) | (e.ctrlKey ? 2 : 0) | (e.altKey ? 4 : 0) | (e.metaKey ? 8 : 0);

  // The Window port on a canvas: events as the port's (kind, x, y, code, mods), kinds
  // numbered as ports.EventKind is: Close 1, Resize 2, KeyDown 3, KeyUp 4, Char 5,
  // MouseMove 6, MouseDown 7, MouseUp 8, Wheel 9.
  function canvasWindow(canvas, options) {
    let open = false;
    let queue = [];
    const listeners = [];
    const listen = (type, f) => {
      canvas.addEventListener(type, f);
      listeners.push([type, f]);
    };
    // pointer positions in the canvas's pixels, whatever size the page shows it at
    const at = (e) => {
      const sx = canvas.clientWidth ? canvas.width / canvas.clientWidth : 1;
      const sy = canvas.clientHeight ? canvas.height / canvas.clientHeight : 1;
      return [Math.floor((e.offsetX || 0) * sx), Math.floor((e.offsetY || 0) * sy)];
    };
    const button = (b) => (b === 0 ? 1 : b === 2 ? 2 : b === 1 ? 3 : 0);
    const push = (...e) => queue.push(e);
    const frame = options.frame || ((f) => (typeof requestAnimationFrame === 'function' ? requestAnimationFrame(f) : setTimeout(f, 16)));
    const win = {
      isOpen: () => open,
      width: () => canvas.width,
      height: () => canvas.height,
      open(title, w, h) {
        canvas.width = w;
        canvas.height = h;
        if (canvas.tabIndex !== undefined && canvas.tabIndex < 0) canvas.tabIndex = 0;
        open = true;
        queue = [];
        listen('keydown', (e) => {
          const k = keyCode(e);
          if (k) push(3, 0, 0, k, mods(e));
          const ch = e.key && [...e.key].length === 1 && !e.ctrlKey && !e.metaKey ? e.key.codePointAt(0) : 0;
          if (ch) push(5, 0, 0, ch, mods(e));
          // keys the program takes are not the page's (Tab, arrows, Space, shortcuts)
          if ((k || ch) && e.preventDefault) e.preventDefault();
        });
        listen('keyup', (e) => {
          const k = keyCode(e);
          if (k) push(4, 0, 0, k, mods(e));
        });
        listen('mousemove', (e) => push(6, ...at(e), 0, mods(e)));
        listen('mousedown', (e) => {
          if (canvas.focus) canvas.focus();
          const b = button(e.button);
          if (b) push(7, ...at(e), b, mods(e));
        });
        listen('mouseup', (e) => {
          const b = button(e.button);
          if (b) push(8, ...at(e), b, mods(e));
        });
        listen('wheel', (e) => {
          if (e.deltaY) push(9, ...at(e), e.deltaY < 0 ? 120 : -120, mods(e));
          if (e.preventDefault) e.preventDefault();
        });
        listen('contextmenu', (e) => e.preventDefault && e.preventDefault());
        win.title(title);
        if (options.onOpen) options.onOpen(canvas);
      },
      next: () => queue.shift(),
      frame,
      present(rgba, w, h) {
        const g = canvas.getContext('2d');
        const img = g.createImageData(w, h);
        img.data.set(rgba);
        g.putImageData(img, 0, 0);
      },
      title(t) {
        if (options.onTitle) options.onTitle(t);
      },
      close() {
        for (const [type, f] of listeners) canvas.removeEventListener(type, f);
        listeners.length = 0;
        open = false;
        queue = [];
      },
    };
    return win;
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

  return { run, memoryFs, canYield };
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
