#!/usr/bin/python

import sys, os, json
from xml.dom.minidom import parse

path = sys.argv[1]

data = []
for fn in sorted(os.listdir(path)):
	fn = os.path.join(path, fn)
	if not fn.endswith('.xml'):
		continue
	xml = parse(fn)
	[img] = xml.getElementsByTagName('Image')
	[size] = img.getElementsByTagName('Size')
	ts = int(img.getAttribute('TileSize'))
	w = int(size.getAttribute('Width'))
	h = int(size.getAttribute('Height'))
	data.append({
		'name': fn[:-4],
		'w': w,
		'h': h,
		'ts': ts,
		})

with open(os.path.join(path, 'images.js'), 'w') as f:
	f.write('window.IMAGES = ')
	json.dump(data, f)
	f.write(';\n')
