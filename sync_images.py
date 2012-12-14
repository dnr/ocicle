#!/usr/bin/python

"""
1. make tiles
2. add to metadata

fields:
	src
	w, h
	px, py, pw
	desc
	shape
"""

import sys, os, subprocess, json, time, random, copy, pyexiv2
import xml.dom.minidom
join = os.path.join

SRCDIR = 'images'
TILEDIR = 'tiles'
META = 'data/meta.js'
M_PREFIX = 'window.META='
M_SUFFIX = ';\n'

CAPTION = 'Iptc.Application2.Caption'

# shapes
RECT = 0
CIRCLE = 1
HEXAGON = 2


def ReadDzXml(fn):
	dom = xml.dom.minidom.parse(fn)
	[img] = dom.getElementsByTagName('Image')
	[size] = img.getElementsByTagName('Size')
	ts = int(img.getAttribute('TileSize'))
	w = int(size.getAttribute('Width'))
	h = int(size.getAttribute('Height'))
	return {'w': w, 'h': h, 'ts': ts}


def ReadExif(fn):
	md = pyexiv2.ImageMetadata(fn)
	md.read()
	caption = md.get(CAPTION, None)
	if caption:
		yield 'desc', caption.value[0].decode('utf-8')


def Newer(a, b):
	try:
		def s(a): return os.stat(a).st_mtime
		def ls(a): return os.lstat(a).st_mtime
		def m(a): return max(s(a), ls(a))
		return m(a) > m(b)
	except:
		return False


def MakeTiles(base):
	jpgpath = join(SRCDIR, base) + '.jpg'
	xmlpath = join(TILEDIR, base + '.xml')
	if not Newer(xmlpath, jpgpath):
		args = ['DeepZoomTiler', '-quality', '0.9', '-s', '-o', TILEDIR, jpgpath]
		subprocess.check_call(args)
	attrs = ReadDzXml(xmlpath)
	attrs['src'] = unicode(base)
	attrs.update(ReadExif(jpgpath))
	return attrs


def AddToMeta(meta, attrs):
	for rec in meta:
		if rec['src'] == attrs['src']:
			rec.update(attrs)
			break
	else:
		attrs['px'] = random.uniform(0, 1000)
		attrs['py'] = random.uniform(-500, -100)
		attrs['pw'] = random.uniform(50, 80)
		attrs['shape'] = RECT
		attrs['desc'] = u''
		meta.append(attrs)
		print attrs['src']


def main():
	meta = open(META).read()
	assert meta.startswith(M_PREFIX) and meta.endswith(M_SUFFIX)
	meta = meta[len(M_PREFIX):-len(M_SUFFIX)]
	meta = json.loads(meta)
	orig_meta = copy.deepcopy(meta)

	for jpg in os.listdir(SRCDIR):
		assert jpg.endswith('.jpg')
		base = os.path.basename(jpg)[:-4]
		attrs = MakeTiles(base)
		AddToMeta(meta['images'], attrs)

	if meta != orig_meta and '-n' not in sys.argv:
		os.rename(META, META + '.backup-%d' % time.time())
		meta = json.dumps(meta, separators=(',', ':'))
		open(META, 'w').write(M_PREFIX + meta + M_SUFFIX)


if __name__ == '__main__':
	main()
