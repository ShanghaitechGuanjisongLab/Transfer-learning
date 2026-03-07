with open('d_4g_orig.txt', 'r') as f:
    d_4g = f.read()
with open('d_4A.txt', 'r') as f:
    d_4a = f.read()

svg_content = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="-400 -100 1200 600">
    <path d="{d_4g}" fill="none" stroke="black" stroke-width="5" />
    <path d="{d_4a}" fill="none" stroke="blue" stroke-width="5" />
</svg>'''

with open('shapes_local.svg', 'w') as f:
    f.write(svg_content)
