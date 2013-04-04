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
zip() {
  gzip --best -c < $1 > $1.gz
  touch -r $1 $1.gz
}

copy favicon.ico
cp -a icons publish
copy three.min.js

copy_strip index.html
copy_strip style.css

copy_strip ocicle.coffee
copy_strip logger.coffee
coffee -c publish/{logger,ocicle}.coffee
uglifyjs data/meta.js bigscreen.js publish/{logger,ocicle}.js -c -m -o publish/app.js
rm publish/{logger,ocicle}.{coffee,js}

zip publish/app.js
zip publish/three.min.js
zip publish/index.html
zip publish/style.css

chmod -R a+rX publish/
rsync -azv --delete publish/ m1:zoom/publish/

rm -rf publish/
