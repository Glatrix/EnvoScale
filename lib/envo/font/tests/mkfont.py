# Builds "Envol Test" — a tiny TrueType font drawn here, for envo.font's tests. Glyphs:
# 0 .notdef (empty), 1 space, 2 'l' (a bar), 3 'O' (a ring of quadratic curves),
# 4 'A' (a triangle with a triangular hole), 5 'i' (composite: two 'l' parts, the second
# scaled-free and offset). unitsPerEm 1000. Prints the font as hex.
import struct, sys

def be16(v): return struct.pack('>H', v & 0xFFFF)
def bes16(v): return struct.pack('>h', v)
def be32(v): return struct.pack('>I', v & 0xFFFFFFFF)

def simple(contours):
    # contours: lists of (x, y, on)
    pts = [p for c in contours for p in c]
    xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
    out = bes16(len(contours)) + bes16(min(xs)) + bes16(min(ys)) + bes16(max(xs)) + bes16(max(ys))
    end = -1
    for c in contours:
        end += len(c); out += be16(end)
    out += be16(0)  # no instructions
    # flags: on-curve bit 1; coordinates as 16-bit deltas (no short/same bits)
    out += bytes([1 if p[2] else 0 for p in pts])
    px = 0
    for p in pts:
        out += bes16(p[0] - px); px = p[0]
    py = 0
    for p in pts:
        out += bes16(p[1] - py); py = p[1]
    return out

def composite(parts, bbox):
    out = bes16(-1) + b''.join(bes16(v) for v in bbox)
    for i, (glyph, dx, dy) in enumerate(parts):
        flags = 0x0001 | 0x0002  # ARG_1_AND_2_ARE_WORDS, ARGS_ARE_XY_VALUES
        if i + 1 < len(parts): flags |= 0x0020  # MORE_COMPONENTS
        out += be16(flags) + be16(glyph) + bes16(dx) + bes16(dy)
    return out

bar = [[(100, 0, 1), (100, 700, 1), (250, 700, 1), (250, 0, 1)]]   # clockwise in y-up
# a ring: outer clockwise, inner counter-clockwise, corners off-curve (quadratic)
def ring(cx, cy, r, cw):
    pts = [(cx, cy + r, 1), (cx + r, cy + r, 0), (cx + r, cy, 1), (cx + r, cy - r, 0),
           (cx, cy - r, 1), (cx - r, cy - r, 0), (cx - r, cy, 1), (cx - r, cy + r, 0)]
    return pts if cw else [pts[0]] + pts[1:][::-1]
O = [ring(350, 350, 300, True), ring(350, 350, 150, False)]
A = [[(50, 0, 1), (350, 700, 1), (650, 0, 1)], [(250, 150, 1), (450, 150, 1), (350, 400, 1)]]
glyphs = [b'', b'', simple(bar), simple(O), simple(A), composite([(2, 0, 0), (2, 0, 800)], (100, 0, 250, 1500))]
advance = [500, 300, 350, 700, 700, 350]

glyf = b''; loca = []
for g in glyphs:
    loca.append(len(glyf)); glyf += g
    while len(glyf) % 4: glyf += b'\0'
loca.append(len(glyf))
loca_t = b''.join(be32(v) for v in loca)  # long offsets

head = (be32(0x00010000) + be32(0x00010000) + be32(0) + be32(0x5F0F3CF5) + be16(0x000B) + be16(1000)
        + b'\0' * 16 + bes16(0) + bes16(0) + bes16(700) + bes16(1500) + be16(0) + be16(8)
        + bes16(2) + bes16(1) + bes16(0))
hhea = (be32(0x00010000) + bes16(800) + bes16(-200) + bes16(100) + be16(700) + bes16(0) + bes16(0)
        + bes16(700) + bes16(1) + bes16(0) + bes16(0) + b'\0' * 8 + bes16(0) + be16(len(glyphs)))
maxp = be32(0x00005000) + be16(len(glyphs))
hmtx = b''.join(be16(a) + bes16(0) for a in advance)
# cmap: format 4, segments ' ', 'A', 'O', 'i', 'l', end
segs = [(32, 1), (65, 4), (79, 3), (105, 5), (108, 2)]
n = len(segs) + 1
ends = [c for c, g in segs] + [0xFFFF]
starts = [c for c, g in segs] + [0xFFFF]
deltas = [(g - c) & 0xFFFF for c, g in segs] + [1]
f4 = (be16(4) + be16(16 + 8 * n) + be16(0) + be16(2 * n) + be16(0) + be16(0) + be16(0)
      + b''.join(be16(v) for v in ends) + be16(0) + b''.join(be16(v) for v in starts)
      + b''.join(be16(v) for v in deltas) + b''.join(be16(0) for _ in range(n)))
f4 = f4[:2] + be16(len(f4)) + f4[4:]
cmap = be16(0) + be16(1) + be16(3) + be16(1) + be32(12) + f4

tables = sorted({b'cmap': cmap, b'glyf': glyf, b'head': head, b'hhea': hhea, b'hmtx': hmtx,
                 b'loca': loca_t, b'maxp': maxp}.items())
off = 12 + 16 * len(tables)
dirs = b''; body = b''
for tag, data in tables:
    dirs += tag + be32(0) + be32(off + len(body)) + be32(len(data))
    body += data
    while len(body) % 4: body += b'\0'
font = be32(0x00010000) + be16(len(tables)) + be16(64) + be16(2) + be16(len(tables) * 16 - 64) + dirs + body
if len(sys.argv) > 1:
    open(sys.argv[1], 'wb').write(font)
print(font.hex())
