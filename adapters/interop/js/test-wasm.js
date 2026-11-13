// Runs the spec run programs (tests/spec/core-run, s1-run, s2-run) and the library tests
// as WebAssembly under Node.js (PLAN D48). Each spec program is built with `envoc build
// --target wasm32-web` at -O0 and -O2 and must print what its `// expect:` lines say,
// exit as `// expect-exit:` says, and panic as `// expect-panic:` says, exactly as the
// native build does. The bootstrap scripts run it where Node.js is installed. Naming
// suites runs only those spec suites.
//
//   node adapters/interop/js/test-wasm.js <envoc> [suite…]
'use strict';
const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const envoc = process.argv[2] && path.resolve(process.argv[2]);
if (!envoc) {
  process.stderr.write('usage: node test-wasm.js <envoc> [suite…]\n');
  process.exit(2);
}
const suites = process.argv.length > 3 ? process.argv.slice(3) : ['core-run', 's1-run', 's2-run'];
const root = path.resolve(__dirname, '..', '..', '..');
const work = path.join(root, 'build', 'run-wasm');
fs.rmSync(work, { recursive: true, force: true });
fs.mkdirSync(work, { recursive: true });
const host = path.join(__dirname, 'envo.js');

const lines = (text, prefix) => text.split(/\r?\n/).filter((l) => l.startsWith(prefix)).map((l) => l.slice(prefix.length));
let pass = 0;
let fail = 0;
const bad = (name, why) => {
  fail++;
  process.stdout.write(`FAIL ${name}: ${why}\n`);
};

for (const suite of suites) {
  const dir = path.join(root, 'tests', 'spec', suite);
  for (const file of fs.readdirSync(dir).filter((f) => f.endsWith('.envol')).sort()) {
    const src = fs.readFileSync(path.join(dir, file), 'utf8');
    const expected = lines(src, '// expect: ').map((l) => l + '\n').join('');
    const panic = lines(src, '// expect-panic: ')[0];
    const exitLine = lines(src, '// expect-exit: ')[0];
    let want = exitLine ? parseInt(exitLine, 10) : 0;
    if (panic) want = 101;
    for (const opt of ['-O0', '-O2']) {
      const name = `wasm ${suite}/${file} ${opt}`;
      const prog = path.join(work, `${path.basename(file, '.envol')}${opt}.wasm`);
      const build = spawnSync(envoc, ['build', opt, '--target', 'wasm32-web', path.join(dir, file), '-o', prog], { encoding: 'utf8' });
      if (build.status !== 0) {
        bad(name, `build failed: ${(build.stderr || '').slice(0, 400)}`);
        continue;
      }
      const run = spawnSync(process.execPath, [host, prog], { cwd: work, encoding: 'utf8', input: '' });
      const out = (run.stdout || '').replace(/\r/g, '');
      if (out !== expected) bad(name, `stdout differs:\n--- expected\n${expected}--- actual\n${out}${(run.stderr || '').slice(0, 400)}`);
      else if (run.status !== want) bad(name, `exit code ${run.status}, expected ${want}: ${(run.stderr || '').slice(0, 400)}`);
      else if (panic && !(run.stderr || '').includes(`panic: ${panic}`)) bad(name, `stderr: ${(run.stderr || '').slice(0, 400)}`);
      else pass++;
    }
  }
}
// The library tests (lib/**/tests/*.envol) at -O2, with the os.wasm adapters (or the
// reference ones for `// os: none`), unless a test says `// wasm: skip (why)`. They run
// three folders below the root, as `envo test` runs them, so relative paths agree.
if (process.argv.length <= 3) {
  const libRun = path.join(work, 'lib');
  fs.mkdirSync(libRun, { recursive: true });
  const tests = [];
  const walk = (d) => {
    for (const e of fs.readdirSync(d, { withFileTypes: true })) {
      const p = path.join(d, e.name);
      if (e.isDirectory()) walk(p);
      else if (e.name.endsWith('.envol') && path.basename(d) === 'tests') tests.push(p);
    }
  };
  walk(path.join(root, 'lib'));
  tests.sort();
  tests.forEach((t, i) => {
    const src = fs.readFileSync(t, 'utf8');
    if (/^\/\/ wasm: skip/m.test(src)) return;
    const name = `wasm ${path.relative(root, t).split(path.sep).join('/')}`;
    const expected = lines(src, '// expect:').map((l) => (l.startsWith(' ') ? l.slice(1) : l) + '\n').join('');
    const prog = path.join(libRun, `${i}.wasm`);
    const args = ['build', '-O2', '--target', 'wasm32-web', '--lib', root];
    if (/^\/\/ os: none/m.test(src)) args.push('--os', 'none');
    args.push(t, '-o', prog);
    const b = spawnSync(envoc, args, { encoding: 'utf8' });
    if (b.status !== 0) {
      bad(name, `build failed: ${(b.stderr || '').slice(0, 400)}`);
      return;
    }
    const r = spawnSync(process.execPath, [host, prog], { cwd: libRun, encoding: 'utf8', input: '', timeout: 300000 });
    const out = (r.stdout || '').replace(/\r/g, '');
    if (out !== expected) bad(name, `stdout differs (exit ${r.status}): ${(r.stderr || '').slice(0, 400)}`);
    else if (r.status !== 0) bad(name, `exit code ${r.status}: ${(r.stderr || '').slice(0, 400)}`);
    else pass++;
  });
}

// The compiler itself as WebAssembly (PLAN D52, the sandbox): envoc builds envoc.wasm;
// envoc.wasm, under Node.js, rebuilds itself to the same bytes (the fixed point, D18, in
// WebAssembly); and it compiles and runs a program in memory, as the website's sandbox
// page does.
// The browser host (M14.8): a windowed program on a stand-in canvas, with the page's
// events queued as it opens. Node has no JSPI by default, so the program's polls do not
// wait: it reads what is queued and goes on.
async function pagePhase() {
  const EnvoWeb = require('./envo.js');
  const name = 'wasm the browser host (adapters/interop/js/window-page.envol)';
  const prog = path.join(work, 'window-page.wasm');
  const b = spawnSync(envoc, ['build', '-O2', '--target', 'wasm32-web', '--lib', root, path.join(__dirname, 'window-page.envol'), '-o', prog], { encoding: 'utf8' });
  if (b.status !== 0) {
    bad(name, `build failed: ${(b.stderr || '').slice(0, 400)}`);
    return;
  }
  const listeners = {};
  let pixels = null;
  const canvas = {
    width: 0, height: 0, tabIndex: -1, clientWidth: 0, clientHeight: 0,
    addEventListener(type, f) { (listeners[type] = listeners[type] || []).push(f); },
    removeEventListener(type, f) { listeners[type] = (listeners[type] || []).filter((g) => g !== f); },
    focus() {},
    getContext() {
      return {
        createImageData: (w, h) => ({ data: new Uint8ClampedArray(w * h * 4) }),
        putImageData: (img) => { pixels = img.data; },
      };
    },
  };
  const fire = (type, e) => (listeners[type] || []).forEach((f) => f({ preventDefault() {}, ...e }));
  let title = '';
  let out = '';
  const code = await EnvoWeb.run(fs.readFileSync(prog), {
    canvas,
    stdout: (x) => { out += new TextDecoder().decode(x); },
    onTitle: (t) => { title = t; },
    onOpen: () => {
      fire('keydown', { key: 'A', code: 'KeyA', shiftKey: true });
      fire('keydown', { key: 'ArrowLeft', code: 'ArrowLeft', ctrlKey: true });
      fire('mousemove', { offsetX: 2, offsetY: 1 });
      fire('mousedown', { button: 2, offsetX: 3, offsetY: 2 });
      fire('wheel', { deltaY: -40, offsetX: 1, offsetY: 1 });
      fire('keyup', { key: 'a', code: 'KeyA' });
    },
  });
  const want = 'open 4x3\nkeydown 0 0 65 1\nchar 0 0 65 1\nkeydown 0 0 37 2\nmove 2 1 0 0\ndown 3 2 2 0\nwheel 1 1 120 0\nkeyup 0 0 65 0\nclipboard ok\nclosed\n';
  if (code !== 0 || out !== want) bad(name, `exit ${code}, output:\n${out}`);
  else if (!pixels || pixels.length !== 48 || pixels[4 * 5] !== 5 || pixels[4 * 5 + 1] !== 10 || pixels[4 * 5 + 3] !== 255) bad(name, 'the frame did not reach the canvas');
  else if (title !== 'titled') bad(name, `title ${JSON.stringify(title)}`);
  else if (Object.values(listeners).some((l) => l.length > 0)) bad(name, 'listeners left on the canvas after Close');
  else pass++;

  // under JSPI the loop yields to the page (where this Node can turn JSPI on)
  const loopName = 'wasm the browser host yields under JSPI (window-loop.envol)';
  const loop = path.join(work, 'window-loop.wasm');
  const lb = spawnSync(envoc, ['build', '-O2', '--target', 'wasm32-web', '--lib', root, path.join(__dirname, 'window-loop.envol'), '-o', loop], { encoding: 'utf8' });
  if (lb.status !== 0) {
    bad(loopName, `build failed: ${(lb.stderr || '').slice(0, 400)}`);
    return;
  }
  const lr = spawnSync(process.execPath, ['--experimental-wasm-jspi', path.join(__dirname, 'window-loop.js'), loop], { encoding: 'utf8', timeout: 60000 });
  const lout = (lr.stdout || '').replace(/\r/g, '');
  if (lr.status !== 0 && /bad option|unknown|not allowed/i.test(lr.stderr || '')) return;    // no such flag here
  if (lout === 'no JSPI\n') return;
  if (lr.status !== 0 || lout !== 'yielded to the page, then closed on Escape\n') bad(loopName, `exit ${lr.status}: ${lout}${(lr.stderr || '').slice(0, 400)}`);
  else pass++;
}

async function compilerPhase() {
  const EnvoWeb = require('./envo.js');
  const compilerDir = path.join(root, 'compiler');
  const files = fs.readFileSync(path.join(compilerDir, 'files.txt'), 'utf8').split(/\r?\n/).filter((l) => l && !l.startsWith('#'));
  const wasm = path.join(work, 'envoc.wasm');
  const b = spawnSync(envoc, ['build', '-O2', '--target', 'wasm32-web', ...files, '-o', wasm], { cwd: compilerDir, encoding: 'utf8' });
  if (b.status !== 0) {
    bad('wasm envoc.wasm', `build failed: ${(b.stderr || '').slice(0, 400)}`);
    return;
  }
  pass++;
  const self = path.join(work, 'envoc-self.wasm');
  const r = spawnSync(process.execPath, [host, wasm, 'build', '-O2', '--target', 'wasm32-web', ...files, '-o', self], { cwd: compilerDir, encoding: 'utf8', input: '' });
  if (r.status !== 0) bad('wasm envoc.wasm builds itself', `exit ${r.status}: ${(r.stderr || '').slice(0, 400)}`);
  else if (!fs.readFileSync(wasm).equals(fs.readFileSync(self))) bad('wasm envoc.wasm builds itself', 'the rebuilt compiler differs');
  else pass++;
  const mem = new Map([['main.envol', new TextEncoder().encode('print("Hello from the sandbox");\n')]]);
  let log = '';
  const keep = (x) => { log += new TextDecoder().decode(x); };
  const code = await EnvoWeb.run(fs.readFileSync(wasm), { args: ['envoc', 'build', '--target', 'wasm32-web', 'main.envol', '-o', 'main.wasm'], fs: EnvoWeb.memoryFs(mem), stdout: keep, stderr: keep });
  if (code !== 0 || !mem.has('main.wasm')) {
    bad('wasm sandbox compile', `exit ${code}: ${log}`);
    return;
  }
  let out = '';
  await EnvoWeb.run(mem.get('main.wasm'), { args: ['main'], stdout: (x) => { out += new TextDecoder().decode(x); } });
  if (out !== 'Hello from the sandbox\n') bad('wasm sandbox run', JSON.stringify(out));
  else pass++;
}

(async () => {
  if (process.argv.length <= 3) {
    await pagePhase();
    await compilerPhase();
  }
  process.stdout.write(`wasm: ${pass} passed, ${fail} failed\n`);
  process.exitCode = fail === 0 ? 0 : 1;
})();
