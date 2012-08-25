
# TODO:
# use more detailed scales when zooming out.
# non-rectangular frames/clipping regions.
# integrate editor with viewer. how to make persistent?

DRAG_FACTOR = 2
DRAG_THRESHOLD = 3
CLICK_ZOOM_FACTOR = 2
WHEEL_ZOOM_FACTOR = Math.pow(2, 1/5)
ANIMATE_MS = 500
FRAME_WIDTH = 2
FAKE_DELAY = 0 #800
CENTER_BORDER = 30
PREFETCH_BORDER = 200

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


rect_is_outside = (c, x, y, w, h, border=PREFETCH_BORDER) ->
  x + w < -border          or y + h < -border or
      x > c.width + border or     y > c.height + border


# adapted from https://gist.github.com/771192
class LruCache
  constructor: (@max_length) ->
    @map = {}
    @_has = @map.hasOwnProperty.bind @map
    @length = 0

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
    if @_has key
      node = @map[key]
      node[1] = value
      @_remove node
      @_insert node
    else
      @_insert [key, value]


class ImagePosition
  constructor: (@w, @h) ->
    @x = @y = 0


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
  constructor: (dz) ->
    @name = dz.name
    @w = dz.w
    @h = dz.h
    @tile_size = dz.ts
    @overlap = dz.o
    @min_level = @find_level @tile_size / 2
    @max_level = @find_level Math.max @w, @h
    @pos = new ImagePosition @w, @h

  get_at_level: (level, x, y) ->
    return @name + '/' + level + '/' + x + '_' + y + '.jpg'

  find_level: (dim) ->
    Math.ceil(Math.log(dim) / Math.LN2)

  clip_level: (level) ->
    Math.min(Math.max(level, @min_level), @max_level)

  render_onto_ctx: (ctx, tile_cache, x, y, w, h) ->
    frame = ctx.ocicle_frame
    tile_size = @tile_size

    level = @clip_level 1 + @find_level Math.max w, h
    source_scale = 1 << (@max_level - level)
    max_c = @w / source_scale / tile_size
    max_r = @h / source_scale / tile_size
    # this assumes the aspect ratio is preserved:
    draw_scale = w / @w * source_scale
    draw_ts = tile_size * draw_scale

    draw = (img, c, r, diff) ->
      return if ctx.ocicle_frame != frame
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
            draw img, c, r, diff
            break
          else if level2 == level
            if not img
              img = new ImageLoader src
              tile_cache.put src, img
            img.add_cb do (c, r, diff) -> (img) -> draw img, c, r, diff


class Ocicle
  constructor: (@c) ->
    @c.addEventListener 'mousedown', @on_mousedown, true
    @c.addEventListener 'contextmenu', @on_mousedown, true
    @c.addEventListener 'mousemove', @on_mousemove, true
    @c.addEventListener 'mouseup', @on_mouseup, true
    @c.addEventListener 'mouseout', @on_mouseup, true
    @c.addEventListener 'mousewheel', @on_mousewheel, true
    @c.addEventListener 'DOMMouseScroll', @on_mousewheel, true

    @frame = 0
    @last_now = @fps = 0
    @images = (new DZImage dz for dz in IMAGES)
    @reset()

  reset: () ->
    @stop_animation()
    @tile_cache = new LruCache 100
    @pan_x = @pan_y = 0
    @scale = @scale_target = 1
    @reset_image_positions()
    @render()

  reset_image_positions: () ->
    for i in @images
      pos = POS[i.name]
      if pos then i.pos = pos

  find_containing_image: (x, y) ->
    bounds = @c.getBoundingClientRect()
    x = (x - bounds.left - @pan_x) / @scale
    y = (y - bounds.top - @pan_y) / @scale
    for i in @images
      if x >= i.pos.x and y >= i.pos.y and x <= i.pos.x + i.pos.w and y <= i.pos.y + i.pos.h
        return i
    return undefined

  on_mousedown: (e) =>
    if e.button == 0 or e.button == 1 or e.button == 2
      e.preventDefault()
      @stop_animation()
      @drag_state = 1
      @drag_screen_x = e.screenX
      @drag_screen_y = e.screenY
      @drag_pan_x = @pan_x
      @drag_pan_y = @pan_y

  on_mousemove: (e) =>
    if @drag_state >= 1
      move_x = e.screenX - @drag_screen_x
      move_y = e.screenY - @drag_screen_y
      if Math.abs(move_x) > DRAG_THRESHOLD or Math.abs(move_y) > DRAG_THRESHOLD
        @drag_state = 2
      if @drag_state >= 2
        pan_x = @drag_pan_x + DRAG_FACTOR * move_x
        pan_y = @drag_pan_y + DRAG_FACTOR * move_y
        @navigate_to @scale, pan_x, pan_y

  on_mouseup: (e) =>
    if @drag_state == 1
      e.preventDefault()
      if e.button == 0 or e.button == 2
        factor = if e.button == 0 then CLICK_ZOOM_FACTOR else 1/CLICK_ZOOM_FACTOR
        @do_zoom factor, e.clientX, e.clientY
      else if e.button == 1
        # center around image
        i = @find_containing_image e.clientX, e.clientY
        if i
          scale = Math.min (@c.width - CENTER_BORDER) / i.pos.w,
                           (@c.height - CENTER_BORDER) / i.pos.h
          pan_x = @c.width / 2 - (i.pos.x + i.pos.w / 2) * scale
          pan_y = @c.height / 2 - (i.pos.y + i.pos.h / 2) * scale
          @navigate_to scale, pan_x, pan_y
    @drag_state = 0

  on_mousewheel: (e) =>
    e.preventDefault()
    if e.wheelDelta
      factor = if e.wheelDelta > 0 then WHEEL_ZOOM_FACTOR else 1/WHEEL_ZOOM_FACTOR
    else
      factor = if e.detail < 0 then WHEEL_ZOOM_FACTOR else 1/WHEEL_ZOOM_FACTOR
    @do_zoom factor, e.clientX, e.clientY

  do_zoom: (factor, client_x, client_y) =>
    bounds = @c.getBoundingClientRect()
    center_x = client_x - bounds.left - @c.width / 2
    center_y = client_y - bounds.top - @c.height / 2

    @scale_target *= factor
    pan_x = @pan_x - center_x / @scale + center_x / @scale_target
    pan_y = @pan_y - center_y / @scale + center_y / @scale_target
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
      @request_id = if t < 1 then requestFrame frame, @c
    frame()

  on_resize: () ->
    @render()

  render: () ->
    cw = @c.parentElement.clientWidth
    if @c.width < cw then @c.width = cw
    ch = @c.parentElement.clientHeight
    if @c.height < ch then @c.height = ch

    ctx = @c.getContext '2d'
    ctx.ocicle_frame = @frame++
    ctx.clearRect 0, 0, cw, ch

    calls = []

    # image frames
    lw = Math.max 1, FRAME_WIDTH * @scale
    shadow = Math.max 1, FRAME_WIDTH * @scale / 2
    ctx.save()
    ctx.lineWidth = lw
    for i in @images
      x = (i.pos.x + @pan_x) * @scale + cw / 2
      y = (i.pos.y + @pan_y) * @scale + ch / 2
      w = i.pos.w * @scale
      h = i.pos.h * @scale
      continue if rect_is_outside @c, x, y, w, h
      ctx.strokeStyle = 'hsl(210,5%,15%)'
      ctx.strokeRect x + shadow, y + shadow, w, h
      ctx.strokeStyle = 'hsl(210,5%,5%)'
      ctx.strokeRect x, y, w, h
      calls.push([i, x, y, w, h])
    ctx.restore()

    # images
    for [i, x, y, w, h] in calls
      i.render_onto_ctx ctx, @tile_cache, x, y, w, h

    # update fps
    now = Date.now()
    ms = now - @last_now
    @fps = (1000 / ms + @fps * 9) / 10
    set_text 'fps', ~~(@fps + .5)
    @last_now = now
    scale = Math.log(@scale) / Math.LN2
    set_text 'zoom', ~~(10 * scale + .5) / 10


set_text = (id, t) ->
  document.getElementById(id).innerText = t

on_resize = () ->
  leftcol = document.getElementById 'leftcol'
  mainbox = document.getElementById 'mainbox'
  w = leftcol.getBoundingClientRect().width
  mainbox.style.width = Math.floor mainbox.parentElement.clientWidth - w - 1
  if window.ocicle then window.ocicle.on_resize()

on_load = () ->
  on_resize()
  window.ocicle = new Ocicle document.getElementById 'c'

window.addEventListener 'resize', on_resize, false
window.addEventListener 'load', on_load, false

