# Builds two tiny language models for envo.ai's tests, with random weights, and a
# reference forward pass in numpy (float64) whose results are stored in each file's
# metadata: test.prompt (token ids), test.logits (the scores after the prompt) and
# test.tokens (greedy generation, stopping at a control token).
#
#   tiny-llama.gguf  llama: rotary pairs, grouped-query attention (4 heads, 2 KV),
#                    SentencePiece tokenizer, F16 embedding, Q8_0 ffn_down, own output.
#   tiny-qwen3.gguf  qwen3: rotary halves, head size 16 (not width / heads), q/k norms,
#                    q/k/v biases, output tied to the embedding, byte-level BPE with
#                    ChatML control tokens.
#   tiny-nomic.gguf  nomic-bert (a text encoder): fused qkv, rotary halves, attention
#                    both ways, post-layer norms, mean pooling; WordPiece. Its reference
#                    is test.text, test.prompt (its tokens) and test.embedding.
#
# Run: python mkmodel.py (writes both files beside it). numpy is the only dependency.
import os, struct
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))

# ---------------------------------------------------------------- GGUF writing

def gstr(s):
    b = s.encode('utf-8') if isinstance(s, str) else s
    return struct.pack('<Q', len(b)) + b

class Gguf:
    def __init__(self):
        self.kv = []
        self.tensors = []   # (name, dims innermost first, type, bytes, dequantized array)

    def str(self, k, v): self.kv.append(gstr(k) + struct.pack('<I', 8) + gstr(v))
    def u32(self, k, v): self.kv.append(gstr(k) + struct.pack('<II', 4, v))
    def f32(self, k, v): self.kv.append(gstr(k) + struct.pack('<If', 6, v))
    def bool(self, k, v): self.kv.append(gstr(k) + struct.pack('<IB', 7, 1 if v else 0))
    def strs(self, k, vs): self.kv.append(gstr(k) + struct.pack('<IIQ', 9, 8, len(vs)) + b''.join(gstr(v) for v in vs))
    def f32s(self, k, vs): self.kv.append(gstr(k) + struct.pack('<IIQ', 9, 6, len(vs)) + b''.join(struct.pack('<f', v) for v in vs))
    def i32s(self, k, vs): self.kv.append(gstr(k) + struct.pack('<IIQ', 9, 5, len(vs)) + b''.join(struct.pack('<i', v) for v in vs))
    def u32s(self, k, vs): self.kv.append(gstr(k) + struct.pack('<IIQ', 9, 4, len(vs)) + b''.join(struct.pack('<I', v) for v in vs))

    # a: rows x cols (or a vector). Returns the values as stored (dequantized), float64.
    def tensor(self, name, a, kind='f32'):
        a = np.asarray(a, dtype=np.float32)
        dims = [a.shape[-1]] + ([a.shape[0]] if a.ndim == 2 else [])
        flat = a.reshape(-1)
        if kind == 'f32':
            data, back, t = flat.tobytes(), flat.astype(np.float64), 0
        elif kind == 'f16':
            h = flat.astype(np.float16)
            data, back, t = h.tobytes(), h.astype(np.float64), 1
        else:  # q8_0
            assert dims[0] % 32 == 0
            data = b''
            back = []
            for blk in flat.reshape(-1, 32):
                amax = float(np.max(np.abs(blk)))
                d = amax / 127.0
                q = np.zeros(32, dtype=np.int32) if d == 0 else np.array([int(np.floor(abs(x) / d + 0.5)) * (1 if x >= 0 else -1) for x in blk.astype(np.float32) / np.float32(d)], dtype=np.int32)
                q = np.clip(q, -127, 127)
                dh = np.float16(d)
                data += dh.tobytes() + q.astype(np.int8).tobytes()
                back.extend(float(dh) * q)
            back, t = np.array(back, dtype=np.float64), 8
        self.tensors.append((name, dims, t, data))
        return back.reshape(a.shape)

    def bytes(self):
        out = b'GGUF' + struct.pack('<IQQ', 3, len(self.tensors), len(self.kv)) + b''.join(self.kv)
        off = 0
        for name, dims, t, data in self.tensors:
            out += gstr(name) + struct.pack('<I', len(dims)) + b''.join(struct.pack('<Q', d) for d in dims) + struct.pack('<IQ', t, off)
            off += (len(data) + 31) // 32 * 32
        out += b'\0' * (-len(out) % 32)
        for _, _, _, data in self.tensors:
            out += data + b'\0' * (-len(data) % 32)
        return out

# ---------------------------------------------------------------- the reference model

def rms(x, w, eps): return x / np.sqrt(np.mean(x * x) + eps) * w

def rope(x, hd, pos, base, halves):
    x = x.copy()
    for h in range(0, len(x), hd):
        for i in range(hd // 2):
            ang = pos * base ** (-(2 * i) / hd)
            c, s = np.cos(ang), np.sin(ang)
            a, b = (h + i, h + i + hd // 2) if halves else (h + 2 * i, h + 2 * i + 1)
            x0, x1 = x[a], x[b]
            x[a], x[b] = x0 * c - x1 * s, x0 * s + x1 * c
    return x

def forward(m, tokens):
    # the logits after each token
    K = [[] for _ in m['blocks']]
    V = [[] for _ in m['blocks']]
    hd, H, KV = m['hd'], m['heads'], m['kv']
    out = []
    for pos, t in enumerate(tokens):
        x = m['embed'][t].copy()
        for l, b in enumerate(m['blocks']):
            xb = rms(x, b['attn_norm'], m['eps'])
            q = b['wq'] @ xb + b.get('bq', 0)
            k = b['wk'] @ xb + b.get('bk', 0)
            v = b['wv'] @ xb + b.get('bv', 0)
            if 'qn' in b:
                q = np.concatenate([rms(q[i:i + hd], b['qn'], m['eps']) for i in range(0, len(q), hd)])
                k = np.concatenate([rms(k[i:i + hd], b['kn'], m['eps']) for i in range(0, len(k), hd)])
            q = rope(q, hd, pos, m['base'], m['halves'])
            k = rope(k, hd, pos, m['base'], m['halves'])
            K[l].append(k); V[l].append(v)
            att = np.zeros(H * hd)
            for h in range(H):
                kh = h // (H // KV)
                qh = q[h * hd:(h + 1) * hd]
                sc = np.array([qh @ K[l][s][kh * hd:(kh + 1) * hd] for s in range(pos + 1)]) / np.sqrt(hd)
                p = np.exp(sc - sc.max()); p /= p.sum()
                att[h * hd:(h + 1) * hd] = sum(p[s] * V[l][s][kh * hd:(kh + 1) * hd] for s in range(pos + 1))
            x = x + b['wo'] @ att
            xf = rms(x, b['ffn_norm'], m['eps'])
            g = b['gate'] @ xf
            u = b['up'] @ xf
            x = x + b['down'] @ (g / (1 + np.exp(-g)) * u)
        xn = rms(x, m['out_norm'], m['eps'])
        out.append(m['out'] @ xn)
    return out

def greedy(m, prompt, n, control):
    toks = list(prompt)
    got = []
    for _ in range(n):
        logits = forward(m, toks)[-1]
        t = int(np.argmax(logits))
        if t in control: break
        got.append(t); toks.append(t)
    return got

def build(path, arch, rng, vocab_tokens, types, tok_meta, dim, hidden, layers, heads, kv, hd, halves, extras, prompt, embed_kind, down_kind, tied):
    g = Gguf()
    g.str('general.architecture', arch)
    g.str('general.name', os.path.basename(path))
    g.u32(arch + '.block_count', layers)
    g.u32(arch + '.context_length', 64)
    g.u32(arch + '.embedding_length', dim)
    g.u32(arch + '.feed_forward_length', hidden)
    g.u32(arch + '.attention.head_count', heads)
    g.u32(arch + '.attention.head_count_kv', kv)
    if hd != dim // heads: g.u32(arch + '.attention.key_length', hd)
    eps = 1e-5
    base = 10000.0
    g.f32(arch + '.attention.layer_norm_rms_epsilon', eps)
    g.f32(arch + '.rope.freq_base', base)
    tok_meta(g)
    g.strs('tokenizer.ggml.tokens', vocab_tokens)
    g.i32s('tokenizer.ggml.token_type', types)
    nv = len(vocab_tokens)
    w = lambda *s: rng.normal(0, 0.35, size=s)
    m = {'hd': hd, 'heads': heads, 'kv': kv, 'eps': float(np.float32(eps)), 'base': base, 'halves': halves, 'blocks': []}
    m['embed'] = g.tensor('token_embd.weight', w(nv, dim) * 2, embed_kind)
    for l in range(layers):
        p = 'blk.%d.' % l
        b = {}
        b['attn_norm'] = g.tensor(p + 'attn_norm.weight', 1 + 0.1 * rng.normal(size=dim))
        b['wq'] = g.tensor(p + 'attn_q.weight', w(heads * hd, dim))
        b['wk'] = g.tensor(p + 'attn_k.weight', w(kv * hd, dim))
        b['wv'] = g.tensor(p + 'attn_v.weight', w(kv * hd, dim))
        b['wo'] = g.tensor(p + 'attn_output.weight', w(dim, heads * hd))
        if 'bias' in extras:
            b['bq'] = g.tensor(p + 'attn_q.bias', 0.1 * rng.normal(size=heads * hd))
            b['bk'] = g.tensor(p + 'attn_k.bias', 0.1 * rng.normal(size=kv * hd))
            b['bv'] = g.tensor(p + 'attn_v.bias', 0.1 * rng.normal(size=kv * hd))
        if 'qknorm' in extras:
            b['qn'] = g.tensor(p + 'attn_q_norm.weight', 1 + 0.1 * rng.normal(size=hd))
            b['kn'] = g.tensor(p + 'attn_k_norm.weight', 1 + 0.1 * rng.normal(size=hd))
        b['ffn_norm'] = g.tensor(p + 'ffn_norm.weight', 1 + 0.1 * rng.normal(size=dim))
        b['gate'] = g.tensor(p + 'ffn_gate.weight', w(hidden, dim))
        b['up'] = g.tensor(p + 'ffn_up.weight', w(hidden, dim))
        b['down'] = g.tensor(p + 'ffn_down.weight', w(dim, hidden), down_kind)
        m['blocks'].append(b)
    m['out_norm'] = g.tensor('output_norm.weight', 1 + 0.1 * rng.normal(size=dim))
    m['out'] = m['embed'] if tied else g.tensor('output.weight', w(nv, dim))
    control = {i for i, t in enumerate(types) if t == 3}
    logits = forward(m, prompt)[-1]
    gen = greedy(m, prompt, 8, control)
    g.u32s('test.prompt', prompt)
    g.f32s('test.logits', [float(v) for v in logits])
    g.u32s('test.tokens', gen)
    open(path, 'wb').write(g.bytes())
    print(path, os.path.getsize(path), 'bytes; generation', gen)

# ---------------------------------------------------------------- the two models

def llama():
    rng = np.random.RandomState(7)
    toks = ['<unk>', '<s>', '</s>'] + ['<0x%02X>' % b for b in range(256)]
    types = [2, 3, 3] + [6] * 256
    pieces = ['▁', '▁the', '▁cat', '▁sat', 't', 'h', 'e', 'c', 'a', 's', '▁t', 'he', 'at', '▁c', '▁s', 'o', 'n', '▁on', '▁mat', 'm']
    scores = [0.0] * len(toks) + [-float(i) for i in range(len(pieces))]
    toks += pieces
    types += [1] * len(pieces)
    def meta(g):
        g.str('tokenizer.ggml.model', 'llama')
        g.f32s('tokenizer.ggml.scores', scores)
        g.u32('tokenizer.ggml.bos_token_id', 1)
        g.u32('tokenizer.ggml.eos_token_id', 2)
        g.bool('tokenizer.ggml.add_bos_token', True)
    build(os.path.join(HERE, 'tiny-llama.gguf'), 'llama', rng, toks, types, meta,
          dim=32, hidden=64, layers=2, heads=4, kv=2, hd=8, halves=False, extras=(),
          prompt=[1, 260, 263, 265, 5], embed_kind='f16', down_kind='q8_0', tied=False)

def gpt2_bytes():
    bs = list(range(33, 127)) + list(range(161, 173)) + list(range(174, 256))
    cs = bs[:]
    n = 0
    for b in range(256):
        if b not in bs:
            bs.append(b); cs.append(256 + n); n += 1
    return dict(zip(bs, (chr(c) for c in cs)))

def qwen3():
    rng = np.random.RandomState(11)
    letter = gpt2_bytes()
    toks = [letter[b] for b in range(256)]
    merges = ['Ġ t', 'h e', 'Ġt he', 'a t', 'c at', 'Ġ cat']
    for mg in merges:
        a, b = mg.split(' ')
        if a + b not in toks: toks.append(a + b)
    types = [1] * len(toks)
    specials = ['<|endoftext|>', '<|im_start|>', '<|im_end|>']
    eos = len(toks) + 2
    toks += specials
    types += [3, 3, 3]
    def meta(g):
        g.str('tokenizer.ggml.model', 'gpt2')
        g.strs('tokenizer.ggml.merges', merges)
        g.u32('tokenizer.ggml.eos_token_id', eos)
        g.str('tokenizer.chat_template', "{% for m in messages %}<|im_start|>{{ m.role }}\n{{ m.content }}<|im_end|>\n{% endfor %}<|im_start|>assistant\n<think>\n\n</think>\n\n")
    build(os.path.join(HERE, 'tiny-qwen3.gguf'), 'qwen3', rng, toks, types, meta,
          dim=32, hidden=64, layers=2, heads=4, kv=2, hd=16, halves=True, extras=('bias', 'qknorm'),
          prompt=[len(toks) - 2, 116, 104, 101, 10], embed_kind='f32', down_kind='f32', tied=True)

def layernorm(x, w, b, eps):
    m = x.mean()
    v = ((x - m) ** 2).mean()
    return (x - m) / np.sqrt(v + eps) * w + b

def wordpiece(vocab, text):
    ids = [vocab.index('[CLS]')]
    words, cur = [], ''
    for ch in text.lower():
        if ch.isspace():
            if cur: words.append(cur); cur = ''
        elif not ch.isalnum():
            if cur: words.append(cur); cur = ''
            words.append(ch)
        else:
            cur += ch
    if cur: words.append(cur)
    for w in words:
        w = '▁' + w
        at, got = 0, []
        while at < len(w):
            end = len(w)
            while end > at and w[at:end] not in vocab: end -= 1
            if end == at: got = None; break
            got.append(vocab.index(w[at:end])); at = end
        ids += got if got is not None else [vocab.index('[UNK]')]
    return ids + [vocab.index('[SEP]')]

def nomic():
    rng = np.random.RandomState(13)
    toks = ['[PAD]', '[UNK]', '[CLS]', '[SEP]', '[MASK]', '▁the', '▁cat', '▁sat', '▁on', 's', '▁kit',
            'ten', '▁mat', '▁.', '▁a', '▁c', 'at', '▁dog', '▁?', '▁what']
    types = [3, 3, 3, 3, 3] + [1] * (len(toks) - 5)
    dim, hidden, layers, heads = 32, 48, 2, 4
    hd = dim // heads
    eps = 1e-12
    g = Gguf()
    a = 'nomic-bert'
    g.str('general.architecture', a)
    g.u32(a + '.block_count', layers)
    g.u32(a + '.context_length', 64)
    g.u32(a + '.embedding_length', dim)
    g.u32(a + '.feed_forward_length', hidden)
    g.u32(a + '.attention.head_count', heads)
    g.f32(a + '.attention.layer_norm_epsilon', eps)
    g.f32(a + '.rope.freq_base', 1000.0)
    g.str('tokenizer.ggml.model', 'bert')
    g.strs('tokenizer.ggml.tokens', toks)
    g.i32s('tokenizer.ggml.token_type', types)
    g.u32('tokenizer.ggml.unknown_token_id', 1)
    g.u32('tokenizer.ggml.bos_token_id', 2)
    g.u32('tokenizer.ggml.seperator_token_id', 3)
    w = lambda *s: rng.normal(0, 0.35, size=s)
    emb = g.tensor('token_embd.weight', w(len(toks), dim))
    typ = g.tensor('token_types.weight', w(2, dim))
    nw = g.tensor('token_embd_norm.weight', 1 + 0.1 * rng.normal(size=dim))
    nb = g.tensor('token_embd_norm.bias', 0.1 * rng.normal(size=dim))
    blocks = []
    for l in range(layers):
        p = 'blk.%d.' % l
        b = {}
        b['qkv'] = g.tensor(p + 'attn_qkv.weight', w(3 * dim, dim))
        b['wo'] = g.tensor(p + 'attn_output.weight', w(dim, dim))
        b['n1w'] = g.tensor(p + 'attn_output_norm.weight', 1 + 0.1 * rng.normal(size=dim))
        b['n1b'] = g.tensor(p + 'attn_output_norm.bias', 0.1 * rng.normal(size=dim))
        b['up'] = g.tensor(p + 'ffn_up.weight', w(hidden, dim))
        b['gate'] = g.tensor(p + 'ffn_gate.weight', w(hidden, dim))
        b['down'] = g.tensor(p + 'ffn_down.weight', w(dim, hidden), 'f16')
        b['n2w'] = g.tensor(p + 'layer_output_norm.weight', 1 + 0.1 * rng.normal(size=dim))
        b['n2b'] = g.tensor(p + 'layer_output_norm.bias', 0.1 * rng.normal(size=dim))
        blocks.append(b)
    text = 'The cat sat on a mat. What kittens? Dogs!'
    ids = wordpiece(toks, text)
    eps32 = float(np.float32(eps))
    x = [layernorm(emb[t] + typ[0], nw, nb, eps32) for t in ids]
    n = len(ids)
    for b in blocks:
        q, k, v = [], [], []
        for i in range(n):
            a3 = b['qkv'] @ x[i]
            q.append(rope(a3[:dim], hd, i, 1000.0, True))
            k.append(rope(a3[dim:2 * dim], hd, i, 1000.0, True))
            v.append(a3[2 * dim:])
        nx = []
        for i in range(n):
            att = np.zeros(dim)
            for h in range(heads):
                sl = slice(h * hd, (h + 1) * hd)
                sc = np.array([q[i][sl] @ k[j][sl] for j in range(n)]) / np.sqrt(hd)
                p_ = np.exp(sc - sc.max()); p_ /= p_.sum()
                att[sl] = sum(p_[j] * v[j][sl] for j in range(n))
            h1 = layernorm(b['wo'] @ att + x[i], b['n1w'], b['n1b'], eps32)
            gt = b['gate'] @ h1
            f = b['down'] @ (gt / (1 + np.exp(-gt)) * (b['up'] @ h1))
            nx.append(layernorm(f + h1, b['n2w'], b['n2b'], eps32))
        x = nx
    e = np.mean(x, axis=0)
    e = e / np.linalg.norm(e)
    g.str('test.text', text)
    g.u32s('test.prompt', ids)
    g.f32s('test.embedding', [float(t) for t in e])
    path = os.path.join(HERE, 'tiny-nomic.gguf')
    open(path, 'wb').write(g.bytes())
    print(path, os.path.getsize(path), 'bytes; tokens', ids)

llama()
qwen3()
nomic()
