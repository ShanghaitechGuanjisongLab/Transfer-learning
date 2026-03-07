import numpy as np
from svgpathtools import parse_path, Path, Line, CubicBezier

with open('d_4g_orig.txt', 'r') as f:
    d_4g = f.read()
with open('d_4A.txt', 'r') as f:
    d_4a = f.read()

p_4g = parse_path(d_4g)
p_4a = parse_path(d_4a)

box_4g = p_4g.bbox()
box_4a = p_4a.bbox()

w_4g = box_4g[1] - box_4g[0]
w_4a = box_4a[1] - box_4a[0]

S = w_4g / w_4a

cx_4g = (box_4g[1] + box_4g[0]) / 2.0
cx_4a = (box_4a[1] + box_4a[0]) / 2.0
dx = cx_4g - (cx_4a * S)

ymax_4g = box_4g[3]
ymax_4a = box_4a[3]
dy = ymax_4g - (ymax_4a * S)

M_align = np.array([[S, 0, dx],
                    [0, S, dy],
                    [0, 0, 1]])

def apply_transform(path, M):
    segments = []
    for seg in path:
        pts = []
        for i in range(len(seg.bpoints())):
            z = seg.bpoints()[i]
            v = np.array([z.real, z.imag, 1])
            vt = np.dot(M, v)
            pts.append(complex(vt[0], vt[1]))
            
        if type(seg).__name__ == 'CubicBezier':
            segments.append(CubicBezier(*pts))
        elif type(seg).__name__ == 'Line':
            segments.append(Line(*pts))
    return Path(*segments)

p_4a_aligned = apply_transform(p_4a, M_align)

svg_content = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="-400 -100 1200 600">
    <path d="{p_4g.d()}" fill="none" stroke="black" stroke-width="8" />
    <path d="{p_4a_aligned.d()}" fill="none" stroke="cyan" stroke-width="4" />
</svg>'''

with open('shapes_aligned.svg', 'w') as f:
    f.write(svg_content)

with open('d_4A_final.txt', 'w') as f:
    f.write(p_4a_aligned.d())
