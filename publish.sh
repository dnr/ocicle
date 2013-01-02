#!/bin/bash

set -e

rm -rf publish/

copy() {
  mkdir -p $(dirname publish/$1)
  cp -aL $1 publish/$1
}
copy_strip() {
  mkdir -p $(dirname publish/$1)
  sed -e '/\[\[\[/,/\]\]\]/d' $1 > publish/$1
  touch -r $1 publish/$1
}

copy bigscreen.min.js
copy bkgd/bk4as.jpg
copy favicon.ico
cp -a icons publish
copy three.min.js
copy data/meta.js

copy_strip index.html
copy_strip style.css

copy_strip ocicle.coffee
coffee -c publish/ocicle.coffee
uglifyjs publish/ocicle.js -c -m -o publish/tmp
mv -f publish/tmp publish/ocicle.js
rm publish/ocicle.coffee

chmod -R a+rX publish/
rsync -azv --delete publish/ m1:zoom/publish/

rm -rf publish/
