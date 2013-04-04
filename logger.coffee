
# TODO: move into util.coffee
simpleXHR = (action, url, data, cb) ->
  req = new XMLHttpRequest
  req.onreadystatechange = () -> if req.readyState == 4 then cb req
  req.open action, url, true
  req.send data

class Logger
  constructor: (@endpoint = '/log_event', @interval = 5) ->
    # not perfect but good enough
    @session_id = Math.random().toString(36).substr(2)
    @_reset()
    @_set_timer()

  add: (name, data) ->
    stuff = @data[name] ||= []
    return if name == 'view' and stuff.length > 0 and stuff[stuff.length-1] == data
    stuff.push data

  count: (name, inc = 1) ->
    @data[name] = (@data[name] || 0) + inc

  _reset: () ->
    @data = id: @session_id

  _send: () =>
    data = JSON.stringify @data
    @_reset()
    simpleXHR 'POST', @endpoint, data, @_set_timer

  _set_timer: () =>
    window.setTimeout @_send, @interval*1000

window.logger = new Logger()
