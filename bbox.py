from svgpathtools import parse_path, Path
import numpy as np

d_4g_orig = "m 0,0 h -0.082 c -5.983,-1.214 -36.12,-26.579 -31.991,-23.055 -6.149,-5.338 -26.655,-24.591 -47.282,-30.739 -48.859,-14.237 -86.877,-2.102 -108.476,12.862 -8.736,5.905 -33.003,40.69 -41.174,48.616 -10.839,10.678 -23.297,18.039 -30.092,25.157 -6.228,6.472 -13.833,17.472 -18.928,26.291 -5.744,9.544 -14.48,28.149 -17.958,38.827 -5.177,15.937 -10.598,37.372 -14.319,62.61 -0.726,4.531 -1.213,9.384 -1.375,14.561 v 14.076 c 1.294,32.76 11.325,71.75 31.709,101.923 24.189,35.593 73.936,61.964 99.904,73.369 37.937,16.987 61.557,29.444 103.864,32.356 46.756,3.237 72.398,-14.398 76.2,-17.471 M -0.483,245.021 0,379.383 c 0.242,-0.243 0.404,-0.405 0.486,-0.487 5.096,4.045 38.664,17.958 84.369,15.614 25.077,-1.294 64.471,-19.657 95.209,-29.121 34.381,-10.598 60.266,-23.54 78.225,-36.888 34.783,-25.643 45.459,-55.168 50.637,-77.414 2.994,-12.942 5.826,-26.29 6.472,-41.82 V 197.699 C 314.508,174.239 308.037,145.443 290.08,106.13 286.033,97.151 280.613,84.854 276.004,76.522 265.729,58.483 244.211,36.805 230.703,23.78 225.932,19.009 213.959,5.42 206.922,-5.662 203.525,-10.921 193.654,-19.495 190.42,-22.731 153.531,-59.698 81.773,-55.438 61.955,-41.683 45.453,-30.036 35.742,-22.332 29.029,-17.802 12.445,-6.963 3.801,1.132 0,0"

d_4a = "m 0,0 c 0.567,-5.581 -0.808,-16.259 -4.933,-15.773 -3.803,0.405 0.241,12.134 -5.096,32.114 -1.052,3.802 -2.428,8.009 -4.208,12.457 -4.286,10.112 -16.582,1.86 -25.803,-2.022 13.589,13.186 22.486,22.003 30.011,38.343 1.375,2.992 2.749,6.228 4.125,9.869 C -5.581,48.212 11.649,24.35 20.062,17.554 3.397,24.996 -1.294,11.649 0,0 M 261.039,64.715 C 208.782,97.799 155.556,116.161 98.528,120.207 11.649,126.193 7.604,108.64 5.905,107.183 -1.051,101.358 -4.206,95.938 -5.5,85.262 c -1.052,3.558 -2.588,6.875 -4.529,9.949 -7.363,11.892 -20.79,20.143 -33.572,24.51 -93.996,32.438 -234.667,-27.179 -298.087,-107.829 -24.105,-30.659 -43.195,-65.118 -52.255,-103.623 -4.935,-21.436 -7.362,-47.564 -5.178,-71.022 1.375,-14.885 3.722,-14.967 4.692,-20.385 0.648,-4.127 -2.426,-2.994 -0.243,-13.428 2.912,-13.833 4.855,-26.452 7.767,-39.314 4.286,-19.253 19.817,-40.445 34.378,-59.78 22.812,-29.85 41.174,-47.403 66.332,-52.012 10.92,-1.942 31.952,-20.791 50.881,-14.319 19.171,6.553 74.987,43.196 68.273,50.234 2.507,-3.074 9.303,-0.646 14.561,3.64 6.551,5.179 10.273,12.701 -0.729,24.835 22.488,-13.025 57.677,-43.602 86.23,-13.51 3.479,3.72 26.615,9.788 18.121,-1.133 -11.245,-14.478 -23.458,-24.994 2.183,-31.871 9.304,-2.346 22.571,-2.346 36.646,-2.346 4.286,0 8.735,0 13.184,-0.082 24.106,-0.402 48.94,-0.646 58.081,9.628 5.905,6.713 -16.906,7.847 -12.377,22.568 3.803,12.376 9.545,-2.75 32.115,-7.927 32.599,-7.36 31.465,8.009 72.964,32.357 -16.017,-22.085 15.208,-30.901 17.069,-28.798 -4.288,-4.367 8.574,-11.001 17.472,-18.282 12.133,-9.948 25.642,-20.06 33.571,-25.318 35.106,-23.055 50.72,1.132 80.728,5.824 42.792,6.794 75.797,92.539 87.284,141.641 4.206,18.283 0.808,25.077 1.293,33.489 0.244,4.772 3.722,2.994 4.207,20.224 v 0.565 8.332 C 393.541,-54.52 331.738,19.9 261.039,64.715"

p_4g = parse_path(d_4g_orig)
p_4a = parse_path(d_4a)

def get_transform(scale_x, scale_y, translate_x, translate_y):
    return np.array([
        [scale_x, 0, translate_x],
        [0, scale_y, translate_y],
        [0, 0, 1]
    ])

M_4g_1 = get_transform(0.07559055, -0.07559055, -1055.3024, 218.11869)
M_4g_2 = get_transform(0.26458319, 0.26458319, 287.64801, -48.292162)
M_4g = M_4g_2 @ M_4g_1

M_4a_1 = get_transform(1.3333333, -1.3333333, 677.22915, 242.01013)
M_4a_2 = get_transform(0.01795887, 0.01795887, -2.5755996, -1.2553289)
M_4a = M_4a_2 @ M_4a_1

def apply_transform(path, M):
    segments = []
    from svgpathtools import Line, CubicBezier, QuadraticBezier, Arc
    def tr(c):
        v = M @ np.array([c.real, c.imag, 1])
        return complex(v[0], v[1])
    for seq in path:
        if type(seq) == CubicBezier:
            segments.append(CubicBezier(tr(seq.start), tr(seq.control1), tr(seq.control2), tr(seq.end)))
        elif type(seq) == Line:
            segments.append(Line(tr(seq.start), tr(seq.end)))
        elif type(seq) == Arc:
            segments.append(Arc(tr(seq.start), seq.radius, seq.rotation, seq.large_arc, seq.sweep, tr(seq.end)))
        else:
            print("Unhandled type!", type(seq))
    return Path(*segments)

abs_4g = apply_transform(p_4g, M_4g)
abs_4a = apply_transform(p_4a, M_4a)

g_min, g_max, g_ymin, g_ymax = abs_4g.bbox()
a_min, a_max, a_ymin, a_ymax = abs_4a.bbox()

print(f"4G Original BBox: x=({g_min:.2f}, {g_max:.2f}), y=({g_ymin:.2f}, {g_ymax:.2f})")
print(f"4A Original BBox: x=({a_min:.2f}, {a_max:.2f}), y=({a_ymin:.2f}, {a_ymax:.2f})")

# We want 4A scaled and translated so its bbox matches 4G exactly.
# Compute the required transform
scale_x = (g_max - g_min) / (a_max - a_min)
scale_y = (g_ymax - g_ymin) / (a_ymax - a_ymin)
# use uniform scale to prevent distortion
scale = min(scale_x, scale_y)  # or average or keep separate if different, brain should probably use uniform
print(f"Required uniform scale: {scale:.4f} (sx: {scale_x:.4f}, sy: {scale_y:.4f})")

# Then translation to match centers:
g_cx = (g_min + g_max) / 2
g_cy = (g_ymin + g_ymax) / 2
a_cx = (a_min + a_max) / 2
a_cy = (a_ymin + a_ymax) / 2

dx = g_cx - a_cx * scale_x
dy = g_cy - a_cy * scale_y
print(f"Required Translation dx: {dx:.4f} dy: {dy:.4f}")

# Now compute the path data directly!
# We want to replace the `d` in 4G. Wait, 4G has a local transform M_4g.
# If we just replace the `d`, the local vertices `v_local` are mapped to `M_4g * v_local`.
# We want them to end up at `Target * M_4a * v_original_4a_local`.
# We can just construct a NEW matrix `M_new` on a new <g> group.
# It is simpler to compute the *new d values* perfectly matching M_4g local space!
# We want: M_4g * v_new = Target_Transform * abs_4a_points
# So v_new = inv(M_4g) * Target_Transform * abs_4a_points
# Actually, the user's intent might just be `T_scale_and_translate * abs_4a`
# Let's generate the final `d` string that can be placed in 4G!

Target_M = get_transform(scale_x, scale_y, dx, dy)
final_abs_4a = apply_transform(abs_4a, Target_M)
inv_M_4g = np.linalg.inv(M_4g)
new_local_4g = apply_transform(final_abs_4a, inv_M_4g)

print("Generated new path length:", len(new_local_4g.d()))
with open('bbox2.py', 'w') as f:
    f.write(new_local_4g.d())
print("Saved to bbox2.py")
