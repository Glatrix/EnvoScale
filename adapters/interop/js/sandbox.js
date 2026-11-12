// sandbox.js: the website's sandbox page (website/PLAN.md, phase 3b; PLAN D52). The
// compiler itself, built for WebAssembly (envoc.wasm), compiles the program in the page,
// and the program runs in the page: nothing is sent anywhere. Uses envo.js (EnvoWeb).
'use strict';

(async () => {
  const code = document.getElementById('code');
  const out = document.getElementById('out');
  const run = document.getElementById('run');
  const pick = document.getElementById('example');
  const examples = {
    hello: 'print("Hello, World!");\n',
    fizzbuzz: 'for (i32 i = 1; i <= 15; i++) {\n    if (i % 15 == 0) print("FizzBuzz");\n    else if (i % 3 == 0) print("Fizz");\n    else if (i % 5 == 0) print("Buzz");\n    else {\n        string s = string.New();\n        i32 n = i;\n        if (n >= 10) s.AppendByte((48 + n / 10) as u8);\n        s.AppendByte((48 + n % 10) as u8);\n        print(s.AsStr());\n    }\n}\n',
    structs: 'struct Point {\n    i64 X;\n    i64 Y;\n\n    i64 Dot(in this, in Point o) => this.X * o.X + this.Y * o.Y;\n}\n\nPoint a = new Point { X = 3, Y = 4 };\nPoint b = new Point { X = 2, Y = 1 };\nif (a.Dot(b) == 10) print("3*2 + 4*1 is 10");\n',
    generics: 'struct Box<T> {\n    T Value;\n}\n\nT Unbox<T>(Box<T> b) where T : Copy => b.Value;\n\nBox<i32> n = new Box<i32> { Value = 42 };\nBox<bool> yes = new Box<bool> { Value = true };\nif (Unbox(n) == 42 && Unbox(yes)) print("generic boxes hold 42 and true");\n',
    panic: 'List<i32> xs = List<i32>.New();\nxs.Push(1);\n// index 5 is out of bounds: the program stops with a panic, as it would natively\nprint("about to fail");\ni32 x = xs.AsSlice()[5];\n',
  };
  const decoder = new TextDecoder();
  const say = (text) => { out.textContent = text; };
  pick.addEventListener('change', () => { code.value = examples[pick.value] || ''; });
  code.value = examples.hello;
  let envoc = null;
  try {
    const r = await fetch('envoc.wasm');
    if (!r.ok) throw new Error(`HTTP ${r.status}`);
    envoc = new Uint8Array(await r.arrayBuffer());
  } catch (e) {
    say('The compiler (envoc.wasm) could not be loaded: ' + e.message);
    return;
  }
  run.disabled = false;
  say('Ready. Press Run.');
  run.addEventListener('click', async () => {
    run.disabled = true;
    say('Compiling…');
    const files = new Map([['main.envo', new TextEncoder().encode(code.value)]]);
    const fs = EnvoWeb.memoryFs(files);
    let log = '';
    const keep = (b) => { log += decoder.decode(b); };
    const t0 = performance.now();
    const status = await EnvoWeb.run(envoc, { args: ['envoc', 'build', '--target', 'wasm32-web', 'main.envo', '-o', 'main.wasm'], fs, stdout: keep, stderr: keep });
    const t1 = performance.now();
    if (status !== 0 || !files.has('main.wasm')) {
      say(log || `The compiler stopped with code ${status}.`);
      run.disabled = false;
      return;
    }
    let text = '';
    const show = (b) => { text += decoder.decode(b); };
    let exit = 0;
    try {
      exit = await EnvoWeb.run(files.get('main.wasm'), { args: ['main'], stdout: show, stderr: show });
    } catch (e) {
      text += '\n' + e;
      exit = 70;
    }
    const t2 = performance.now();
    text += `\n— compiled in ${Math.round(t1 - t0)} ms, ran in ${Math.round(t2 - t1)} ms` + (exit ? `, exit code ${exit}` : '');
    say(text);
    run.disabled = false;
  });
})();
