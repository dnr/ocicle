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
      send(req, req.url).root(__dirname).pipe(res)

  server.listen 1337, '127.0.0.1'
  console.log 'Server running at http://127.0.0.1:1337/'

main()
