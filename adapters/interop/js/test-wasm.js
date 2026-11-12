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

const envoc = process.argv[2];
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
  for (const file of fs.readdirSync(dir).filter((f) => f.endsWith('.envo')).sort()) {
    const src = fs.readFileSync(path.join(dir, file), 'utf8');
    const expected = lines(src, '// expect: ').map((l) => l + '\n').join('');
    const panic = lines(src, '// expect-panic: ')[0];
    const exitLine = lines(src, '// expect-exit: ')[0];
    let want = exitLine ? parseInt(exitLine, 10) : 0;
    if (panic) want = 101;
    for (const opt of ['-O0', '-O2']) {
      const name = `wasm ${suite}/${file} ${opt}`;
      const prog = path.join(work, `${path.basename(file, '.envo')}${opt}.wasm`);
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
// The library tests (lib/**/tests/*.envo) at -O2, with the os.wasm adapters (or the
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
      else if (e.name.endsWith('.envo') && path.basename(d) === 'tests') tests.push(p);
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

process.stdout.write(`wasm: ${pass} passed, ${fail} failed\n`);
process.exit(fail === 0 ? 0 : 1);
