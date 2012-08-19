#!/usr/bin/python

import os
from xml.dom.minidom import parse

os.chdir('images')

for fn in sorted(os.listdir('.')):
	if not fn.endswith('.xml'):
		continue
	xml = parse(fn)
	[img] = xml.getElementsByTagName('Image')
	[size] = img.getElementsByTagName('Size')
	ts = int(img.getAttribute('TileSize'))
	o = int(img.getAttribute('Overlap'))
	w = int(size.getAttribute('Width'))
	h = int(size.getAttribute('Height'))
	print "  {name: '%s', w: %d, h: %d, ts: %d, o: %d}" % (fn[:-4], w, h, ts, o)
