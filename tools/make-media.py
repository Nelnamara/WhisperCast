# Writes the UI lane's textures into Media/ (white, so the colour comes from SetVertexColor):
#   corner-fill.tga        a quarter disc (the top-left corner of a rounded box), for the rounded panels
#   corner-edge-NN.tga     a quarter ring NN percent of the radius thick (25, 29, 33, 40), the rounded edges
#   glow-h.tga, glow-v.tga a soft falloff across the width / height: the glow along a side (strong at 0)
#   glow-corner.tga        the same falloff by distance from the bottom-right corner: a glow's outer corner
#   glow-round.tga         the falloff outside a circle (58 percent of the radius): a round glow
# ring.tga and disc.tga are copied from CooldownTimeline3 (its tools/make-ring.py).
# The falloff copies a CSS box-shadow: blur 14 px, spread 3 px, drawn over 18 px.
# Standard library only.   python3 tools/make-media.py
import math
import os
import struct

HERE = os.path.dirname(os.path.abspath(__file__))
MEDIA = os.path.join(HERE, "..", "Media")


def write(name, w, h, alpha):
	"""alpha(x, y) -> 0..1, sampled four times a pixel"""
	out = bytearray()
	for y in range(h):
		for x in range(w):
			a = 0.0
			for sy in (0.25, 0.75):
				for sx in (0.25, 0.75):
					a += alpha(x + sx, y + sy)
			out += bytes((255, 255, 255, max(0, min(255, round(255 * a / 4)))))
	header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, w, h, 32, 0x28)
	path = os.path.normpath(os.path.join(MEDIA, name))
	with open(path, "wb") as f:
		f.write(header)
		f.write(bytes(out))
	print("wrote", path)


def phi(z):
	return 0.5 * (1 + math.erf(z / math.sqrt(2)))


SPREAD, SIGMA, REACH = 3.0, 7.0, 18.0


def falloff(t):
	"""t 0 (the edge) .. 1 (REACH px out); 1 at the edge"""
	if t <= 0:
		return 1.0
	if t >= 1:
		return 0.0
	return phi((SPREAD - t * REACH) / SIGMA) / phi(SPREAD / SIGMA)


S = 64
# the arc's centre is the bottom-right corner of the top-left quadrant
write("corner-fill.tga", S, S, lambda x, y: 1.0 if math.hypot(S - x, S - y) <= S else 0.0)
for pct in (25, 29, 33, 40):
	inner = S * (1 - pct / 100)
	write("corner-edge-%d.tga" % pct, S, S,
		lambda x, y, inner=inner: 1.0 if inner <= math.hypot(S - x, S - y) <= S else 0.0)
write("glow-h.tga", S, 4, lambda x, y: falloff(x / S))
write("glow-v.tga", 4, S, lambda x, y: falloff(y / S))
# corner piece of a glow, drawn at the frame's top-left outside corner: the frame is to the bottom right
write("glow-corner.tga", S, S, lambda x, y: falloff(math.hypot(S - x, S - y) / S))
K = 0.58
write("glow-round.tga", 128, 128,
	lambda x, y: (lambda d: 0.0 if d < K else falloff((d - K) / (1 - K)))(math.hypot(x - 64, y - 64) / 64))
