#!/usr/bin/env coffee

http = require 'http'
fs = require 'fs'
send = require 'send'

main = () ->
  server = http.createServer (req, res) ->
    console.log req.url
    if req.url[0..5] == '/data/' and req.method.toUpperCase() == 'PUT'
      key = req.url[6..].replace /[^a-zA-Z0-9_:.-]/g, ''
      out = fs.createWriteStream './data/' + key
      out.on 'error', (e) ->
        res.writeHead 500, {'Content-Type': 'text/plain'}
        res.end e + '\n'
      req.pipe out
      req.on 'end', () ->
        res.writeHead 200, {'Content-Type': 'text/plain'}
        res.end 'true\n'
    else
      ext = req.url.substr(-4)
      cacheable = ext == '.jpg' or ext == '.png' or ext == '.ico'
      age = if cacheable then 24*3600 else 0
      send(req, req.url).root(__dirname).maxage(age*1000).pipe(res)

  server.listen 1337, '0.0.0.0'
  console.log 'Server running at http://127.0.0.1:1337/'

main()
