
# TODO:
# use more detailed scales when zooming out.
# do more pre-fetching all around.
# resize top and bottom bars based on font size.

DRAG_FACTOR = 2
DRAG_THRESHOLD = 3
CLICK_ZOOM_FACTOR = 2
WHEEL_ZOOM_FACTOR = Math.pow(2, 1/5)
ANIMATE_MS = 500
FRAME_WIDTH = 1
TILE_CACHE_SIZE = 500
FAKE_DELAY = 0 #+500
CENTER_BORDER = 40
DEBUG_BORDERS = false
ZOOM_LIMIT_LIMIT = 3.3
ZOOM_LIMIT_TARGET = 3.0

# shapes:
RECT = 0
CIRCLE = 1
HEXAGON = 2


requestFrame = window.requestAnimationFrame       ||
               window.webkitRequestAnimationFrame ||
               window.mozRequestAnimationFrame    ||
               window.oRequestAnimationFrame      ||
               window.msRequestAnimationFrame     ||
               (cb) -> window.setTimeout cb, 20
cancelFrame = window.cancelAnimationFrame       ||
              window.webkitCancelAnimationFrame ||
              window.mozCancelAnimationFrame    ||
              window.oCancelAnimationFrame      ||
              window.msCancelAnimationFrame     ||
              (id) -> window.clearTimeout id


$ = (id) -> document.getElementById id
set_text = (id, t) -> $(id).innerText = t

rect_is_outside = (c, x, y, w, h) ->
  x + w < 0 or y + h < 0 or x > c.width or y > c.height

hexagon = (ctx, x, y, w, h) ->
  o = h / 2 / Math.sqrt(2)
  ctx.moveTo x + o, y
  ctx.lineTo x + w - o, y
  ctx.lineTo x + w, y + h / 2
  ctx.lineTo x + w - o, y + h
  ctx.lineTo x + o, y + h
  ctx.lineTo x, y + h / 2
  ctx.lineTo x + o, y

simpleXHR = (action, url, data, cb) ->
  req = new XMLHttpRequest
  req.onreadystatechange = () -> if req.readyState == 4 then cb req
  req.open action, url, true
  req.send data

clear_node = (node) ->
  if not (node instanceof Node) then node = $(node)
  while node.hasChildNodes()
    node.removeChild node.firstChild


# storage interface:
# get: key, (value) -> ...
# set: key, value, (success) -> ...
class Storage
  constructor: (@url) ->

  get: (key, cb) ->
    simpleXHR 'GET', @url + key, '', (req) ->
      if req.status == 200
        cb JSON.parse req.responseText
      else if req.status == 404
        cb null
      else
        #console.log req.responseText
        cb false

  set: (key, value, cb) ->
    value = JSON.stringify value
    simpleXHR 'PUT', @url + key, value, (req) ->
      if cb then cb req.status == 200


# metadata interface:
# images, marks
# images = [{
#   src: url
#   w, h: size of most detailed level in pixels
#   ts: tile size for deep zoom pyramid
#   px, py: location of placed image
#   pw: width of placed image (height calculated from h * pw / w)
#   desc: description
# }]
# marks = [{
#   name: name
#   x, y: pan_x, pan_y
#   scale: scale
# }]
class Metadata
  constructor: (@storage, @client_cb) ->
    @storage.get 'meta', (value) =>
      @data = value
      if @client_cb then @client_cb @
  save: (cb) ->
    @storage.set 'meta', @data, cb


# adapted from https://gist.github.com/771192
class LruCache
  constructor: (@max_length) ->
    @map = {}
    @_has = @map.hasOwnProperty.bind @map
    @length = 0
    @puts = 0

  _insert: (node) ->
    @map[node[0]] = node
    @length++
    if @length > @max_length
      for key of @map
        # Depends on unspecified behavior, that JavaScript enumerates
        # objects in the order that the keys were inserted.
        if @_has key
          @_remove @map[key]
          break

  _remove: (node) ->
    delete @map[node[0]]
    @length--

  get: (key) ->
    node = @map[key]
    if node
      @_remove node
      @_insert node
      node[1]
    else
      undefined

  put: (key, value) ->
    @puts++
    if @_has key
      node = @map[key]
      node[1] = value
      @_remove node
      @_insert node
    else
      @_insert [key, value]


class ImageLoader
  constructor: (src) ->
    @complete = false
    @cbs = []
    @dom = document.createElement 'img'
    @dom.src = src
    @dom.addEventListener 'load', if FAKE_DELAY then @_delay_onload else @_onload

  add_cb: (cb) ->
    @cbs.push cb

  _delay_onload: () =>
    window.setTimeout @_onload, FAKE_DELAY + 200 * Math.random()

  _onload: () =>
    @complete = true
    cb @ for cb in @cbs
    delete @cbs


class DZImage
  constructor: (@meta) ->
    @w = @meta.w
    @h = @meta.h
    @min_level = @find_level @meta.ts / 2
    @max_level = @find_level Math.max @w, @h
    @px = @meta.px
    @py = @meta.py
    @pw = @meta.pw
    @ph = @h * @pw / @w

  move: (@px, @py) ->
    @meta.px = @px
    @meta.py = @py

  scale: (@pw) ->
    @meta.pw = @pw
    @ph = @h * @pw / @w

  get_at_level: (level, x, y) ->
    'tiles/' + @meta.src + '/' + level + '/' + x + '_' + y + '.jpg'

  find_level: (dim) ->
    Math.ceil(Math.log(dim) / Math.LN2)

  clip_level: (level) ->
    Math.min(Math.max(level, @min_level), @max_level)

  render_onto_ctx: (ctx, tile_cache, x, y, w, h, cb) ->
    tile_size = @meta.ts

    level = @clip_level 1 + @find_level Math.max w, h
    source_scale = 1 << (@max_level - level)
    max_c = @w / source_scale / tile_size
    max_r = @h / source_scale / tile_size
    # this assumes the aspect ratio is preserved:
    draw_scale = w / @w * source_scale
    draw_ts = tile_size * draw_scale

    for c in [0 .. max_c]
      for r in [0 .. max_r]
        # ignore tiles outside of viewable area
        continue if rect_is_outside(ctx.canvas,
          x + c * draw_ts, y + r * draw_ts, draw_ts, draw_ts)

        # draw from most detailed level
        for level2 in [level .. @min_level]
          diff = level - level2
          src = @get_at_level level2, c >> diff, r >> diff
          img = tile_cache.get src
          if img?.complete
            ts = tile_size >> diff
            sx = ts * (c % (1 << diff))
            sy = ts * (r % (1 << diff))
            sw = Math.min ts + 2, img.dom.naturalWidth - sx
            sh = Math.min ts + 2, img.dom.naturalHeight - sy
            dx = x + c * draw_ts
            dy = y + r * draw_ts
            dw = sw * draw_scale * (1 << diff)
            dh = sh * draw_scale * (1 << diff)
            ctx.drawImage img.dom, sx, sy, sw, sh, dx, dy, dw, dh
            if DEBUG_BORDERS
              ctx.lineWidth = 1
              ctx.strokeRect dx, dy, dw, dh
            break
          else if level2 == level
            if not img
              #console.log 'loading: ' + src
              img = new ImageLoader src
              tile_cache.put src, img
            img.add_cb cb
    return


class Ocicle
  constructor: (@c, @meta) ->
    @editmode = false

    add_event = (events, method) =>
      edit_switch = () =>
        interaction = if @editmode then interaction_edit else interaction_normal
        interaction[method].apply @, arguments
      for event in events
        @c.addEventListener event, edit_switch, true
    add_event ['mousedown', 'contextmenu'], 'mousedown'
    add_event ['mousemove'], 'mousemove'
    add_event ['mouseup', 'mouseout'], 'mouseup'
    add_event ['mousewheel', 'DOMMouseScroll'], 'mousewheel'

    @reset()

  reset: () ->
    @stop_animation()
    @last_now = @fps = 0
    @images = (new DZImage dz for dz in @meta.data.images)
    @setup_bookmarks()
    @tile_cache = new LruCache TILE_CACHE_SIZE
    @pan_x = @pan_y = 0
    @scale = @scale_target = 1
    @render()

  setup_bookmarks: () ->
    ul = $ 'gotolist'
    clear_node ul
    for mark in @meta.data.marks
      li = document.createElement 'li'
      a = document.createElement 'a'
      a.href = '#'
      a.innerText = mark.name
      a.onclick = do (mark) => () => @navigate_to mark.scale, mark.x, mark.y
      li.appendChild a
      ul.appendChild li

  find_mark: (name) ->
    for mark in @meta.data.marks
      if mark.name == name
        return mark

  set_bookmark: () ->
    name = $('editmark').value
    $('editmark').value = ''
    if name == 'home' then return
    mark = @find_mark name
    if mark
      mark.x = @pan_x
      mark.y = @pan_y
      mark.scale = @scale
    else
      mark =
        name: name
        x: @pan_x
        y: @pan_y
        scale: @scale
      @meta.data.marks.push mark
    @setup_bookmarks()

  edit: () ->
    editlink = $ 'editlink'
    if @editmode
      editlink.innerText = 'save...'
      @meta.save (success) ->
        editlink.innerText = if success then 'save' else 'save (error)'
    else
      @editmode = true
      editlink.innerText = 'save'
      body = document.getElementsByTagName('body')[0]
      body.className = 'edit'
      desc = $ 'desc'
      desc.contentEditable = true
      desc.addEventListener 'input', () =>
        if @highlight_image
          @highlight_image.meta.desc = desc.innerText

      shape = $ 'shapeselect'
      shape.addEventListener 'change', () =>
        if @highlight_image
          @highlight_image.meta.shape = parseInt shape.value
          @render()

  find_containing_image_screen: (x, y) ->
    bounds = @c.getBoundingClientRect()
    @find_containing_image_canvas x - bounds.left, y - bounds.top

  find_containing_image_canvas: (x, y) ->
    x = (x - @pan_x) / @scale
    y = (y - @pan_y) / @scale
    for i in @images
      if x >= i.px and y >= i.py and x <= i.px + i.pw and y <= i.py + i.ph
        return i
    null

  interaction_normal =
    mousedown: (e) ->
      if e.button == 0 or e.button == 1 or e.button == 2
        e.preventDefault()
        @stop_animation()
        @drag_state = 1
        @drag_screen_x = e.screenX
        @drag_screen_y = e.screenY
        @drag_pan_x = @pan_x
        @drag_pan_y = @pan_y

    mousemove: (e) ->
      if @drag_state >= 1
        move_x = e.screenX - @drag_screen_x
        move_y = e.screenY - @drag_screen_y
        if Math.abs(move_x) > DRAG_THRESHOLD or Math.abs(move_y) > DRAG_THRESHOLD
          @drag_state = 2
        if @drag_state >= 2
          pan_x = @drag_pan_x + DRAG_FACTOR * move_x
          pan_y = @drag_pan_y + DRAG_FACTOR * move_y
          @navigate_to @scale, pan_x, pan_y

    mouseup: (e) ->
      if @drag_state == 1
        e.preventDefault()
        if e.button == 0 or e.button == 2
          factor = if e.button == 0 then CLICK_ZOOM_FACTOR else 1/CLICK_ZOOM_FACTOR
          @do_zoom factor, e.clientX, e.clientY
        else if e.button == 1
          # center around image
          i = @find_containing_image_screen e.clientX, e.clientY
          if i
            scale = Math.min (@c.width - CENTER_BORDER) / i.pw,
                             (@c.height - CENTER_BORDER) / i.ph
            pan_x = @c.width / 2 - (i.px + i.pw / 2) * scale
            pan_y = @c.height / 2 - (i.py + i.ph / 2) * scale
            @navigate_to scale, pan_x, pan_y
      @drag_state = 0

    mousewheel: (e) ->
      e.preventDefault()
      if e.wheelDelta
        factor = if e.wheelDelta > 0 then WHEEL_ZOOM_FACTOR else 1/WHEEL_ZOOM_FACTOR
      else
        factor = if e.detail < 0 then WHEEL_ZOOM_FACTOR else 1/WHEEL_ZOOM_FACTOR
      @do_zoom factor, e.clientX, e.clientY

  interaction_edit =
    # drag states:
    #  1: pan
    #  2/3/4: left/right/middle button on image
    mousedown: (e) ->
      e.preventDefault()
      @stop_animation()
      @drag_screen_x = e.screenX
      @drag_screen_y = e.screenY
      @drag_img = @find_containing_image_screen e.clientX, e.clientY
      if @drag_img
        @drag_state = 2 + e.button
        @drag_px = @drag_img.px
        @drag_py = @drag_img.py
        @drag_pw = @drag_img.pw
      else
        @drag_state = 1
        @drag_pan_x = @pan_x
        @drag_pan_y = @pan_y

    mousemove: (e) ->
      if @drag_state == 0 then return
      move_x = e.screenX - @drag_screen_x
      move_y = e.screenY - @drag_screen_y
      if @drag_state == 1  # pan
        @pan_x = @drag_pan_x + DRAG_FACTOR * move_x
        @pan_y = @drag_pan_y + DRAG_FACTOR * move_y
      else if @drag_state == 2  # left button on image
        @drag_img.move @drag_px + move_x / @scale,
                       @drag_py + move_y / @scale
      else if @drag_state == 3  # middle button on image
        false
      else if @drag_state == 4  # right button on image
        @drag_img.scale @drag_pw * Math.pow(1.002, move_x+move_y)
      @render()

    mouseup: (e) ->
      @drag_state = 0

    mousewheel: interaction_normal.mousewheel

  do_zoom: (factor, client_x, client_y) ->
    bounds = @c.getBoundingClientRect()
    center_x = client_x - bounds.left
    center_y = client_y - bounds.top

    @scale_target *= factor
    pan_x = center_x - @scale_target / @scale * (center_x - @pan_x)
    pan_y = center_y - @scale_target / @scale * (center_y - @pan_y)
    @navigate_to @scale_target, pan_x, pan_y

  navigate_to: (scale, pan_x, pan_y) ->
    props = [
      {start: @pan_x, end: pan_x, set: (@pan_x) =>}
      {start: @pan_y, end: pan_y, set: (@pan_y) =>}
      {start: @scale, end: @scale_target = scale, set: (@scale) =>}
    ]
    @animate props, ANIMATE_MS

  stop_animation: () ->
    cancelFrame @request_id if @request_id

  animate: (props, ms) ->
    @stop_animation()
    start = Date.now() - 5
    frame = () =>
      t = Math.sqrt (Math.min 1, (Date.now() - start) / ms)
      for prop in props
        prop.set prop.start * (1-t) + prop.end * t
      @render()
      if @hit_limit
        @scale_target = @scale
        @do_zoom @hit_limit, @c.width/2, @c.height/2
      else
        @request_id = if t < 1 then requestFrame frame, @c
    frame()

  on_resize: () ->
    @render()


  setup_context: () ->
    cw = @c.parentElement.clientWidth
    if @c.width != cw then @c.width = cw
    ch = @c.parentElement.clientHeight
    if @c.height != ch then @c.height = ch

    ctx = @c.getContext '2d'
    ctx.clearRect 0, 0, cw, ch
    [ctx, cw, ch]

  update_highlight_image: (cw, ch) ->
    # must be over center point of canvas
    i = @find_containing_image_canvas cw/2, ch/2
    # and must be at least half the width or height
    if i
      if i.pw * @scale / cw < 0.5 and i.ph * @scale / ch < 0.5
        i = null
    # update description
    set_text 'desc', i?.meta.desc or ''
    if @editmode
      $('shapeselect').value = i?.meta.shape
    @highlight_image = i

  update_fps: () ->
    now = Date.now()
    ms = now - @last_now
    @fps = (1000 / ms + @fps * 9) / 10
    set_text 'fps', @fps.toFixed 0
    @last_now = now
    scale = Math.log(@scale) / Math.LN2
    set_text 'zoom', scale.toFixed 1
    set_text 'tiles', @tile_cache.puts

  render: () ->
    [ctx, cw, ch] = @setup_context()
    @update_highlight_image cw, ch
    @update_fps()

    ctx.lineWidth = Math.max 1, FRAME_WIDTH * @scale
    shadow = Math.max 1, FRAME_WIDTH * @scale / 2
    fw = ctx.lineWidth / 2

    max_ratio = 0
    for i in @images
      x = i.px * @scale + @pan_x
      y = i.py * @scale + @pan_y
      w = i.pw * @scale
      h = i.ph * @scale
      continue if rect_is_outside @c, x-fw, y-fw, w+3*fw, h+3*fw

      ctx.save()

      ctx.strokeStyle = 'hsl(210,5%,5%)'
      ctx.shadowColor = 'hsl(210,5%,15%)'
      ctx.shadowOffsetX = shadow
      ctx.shadowOffsetY = shadow

      ctx.beginPath()
      switch i.meta.shape or RECT
        when RECT
          ctx.rect x, y, w, h
        when CIRCLE
          ctx.arc x+w/2, y+h/2, Math.min(w,h)/2, 0, 2*Math.PI
        when HEXAGON
          hexagon ctx, x, y, w, h
      ctx.closePath()

      ctx.stroke()
      ctx.clip()

      ctx.shadowOffsetX = ctx.shadowOffsetY = 0

      max_ratio = Math.max max_ratio, i.w / w
      i.render_onto_ctx ctx, @tile_cache, x, y, w, h, @img_load_cb

      ctx.restore()

    if max_ratio == 0
      set_text 'ratio', ''
    else if max_ratio < 1
      set_text 'ratio', '1\u2236' + (1 / max_ratio).toFixed 1
    else
      set_text 'ratio', max_ratio.toFixed 1

    @hit_limit = false
    if max_ratio > 0 and max_ratio < 1 / ZOOM_LIMIT_LIMIT
      @hit_limit = max_ratio * ZOOM_LIMIT_TARGET

    return

  img_load_cb: () =>
    # TODO: check if any pending and render then, not this timeout stuff
    if @load_timeout_id then window.clearTimeout @load_timeout_id
    @load_timeout_id = window.setTimeout (=>@render()), 50


on_resize = () ->
  if window.ocicle then window.ocicle.on_resize()

on_load = () ->
  on_resize()
  storage = new Storage '/data/'
  meta = new Metadata storage, (meta) ->
    window.ocicle = new Ocicle $('c'), meta

window.addEventListener 'resize', on_resize, false
window.addEventListener 'load', on_load, false
