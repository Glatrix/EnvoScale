// Runs window-loop.wasm (built by test-wasm.js) on a stand-in canvas under JSPI: the page
// sends Escape after 100 ms, which the program only sees if its polls let the page run.
//
//   node --experimental-wasm-jspi window-loop.js window-loop.wasm
'use strict';
const fs = require('fs');
const EnvoWeb = require('./envo.js');

if (!EnvoWeb.canYield()) {
  process.stdout.write('no JSPI\n');
  process.exit(0);
}
const listeners = {};
const canvas = {
  width: 0, height: 0,
  addEventListener(type, f) { (listeners[type] = listeners[type] || []).push(f); },
  removeEventListener() {},
  getContext() {
    return { createImageData: (w, h) => ({ data: new Uint8ClampedArray(w * h * 4) }), putImageData() {} };
  },
};
setTimeout(() => (listeners.keydown || []).forEach((f) => f({ key: 'Escape', code: 'Escape', preventDefault() {} })), 100);
let out = '';
EnvoWeb.run(fs.readFileSync(process.argv[2]), { canvas, frame: (f) => setTimeout(f, 5), stdout: (x) => { out += new TextDecoder().decode(x); } })
  .then((code) => {
    process.stdout.write(out);
    process.exitCode = code;
  });
