
# TODO:
# generalize scale stuff.
# integrate editor with viewer. how to make persistent?

DRAG_FACTOR = 2
DRAG_THRESHOLD = 3
CLICK_ZOOM_FACTOR = 2
WHEEL_ZOOM_FACTOR = Math.pow(2, 1/5)
ANIMATE_MS = 500
FRAME_WIDTH = 2
FAKE_DELAY = 0 #800
CENTER_BORDER = 30

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

  render_onto_ctx: (ctx, tile_cache, x, y, w, h) ->
    frame = ctx.ocicle_frame

    level = 1 + @find_level Math.max w, h
    level = Math.max level, @min_level
    level = Math.min level, @max_level

    source_scale = 1 << (@max_level - level)
    level_w = @w / source_scale
    level_h = @h / source_scale

    draw_scale = w / level_w
    draw_ts = @tile_size * draw_scale

    for c in [0 .. level_w / @tile_size]

      for r in [0 .. level_h / @tile_size]

        # ignore tiles outside of viewable area
        draw_x = x + c * draw_ts
        draw_y = y + r * draw_ts
        continue if draw_x > ctx.canvas.width or draw_y > ctx.canvas.height
        continue if draw_x + draw_ts < 0 or draw_y + draw_ts < 0

        draw = do (c, r) -> (img) ->
          if ctx.ocicle_frame == frame
            ctx.drawImage img.dom,
              x + c * draw_ts,
              y + r * draw_ts,
              img.dom.naturalWidth * draw_scale,
              img.dom.naturalHeight * draw_scale

        src = @get_at_level level, c, r
        img = tile_cache.get src
        if img?.complete
          draw img
        else
          if not img
            img = new ImageLoader src
            tile_cache.put src, img
          img.add_cb draw

          # TODO: try to find higher scale copies first

          # try a lower scale
          for level2 in [level - 1 .. @min_level]
            diff = level - level2
            c2 = c >> diff
            r2 = r >> diff
            ts2 = @tile_size >> diff
            src2 = @get_at_level level2, c2, r2
            img2 = tile_cache.get src2
            if img2?.complete
              sx = ts2 * (c % (1 << diff))
              sy = ts2 * (r % (1 << diff))
              sw = Math.min ts2 + 2, img2.dom.naturalWidth - sx
              sh = Math.min ts2 + 2, img2.dom.naturalHeight - sy
              dx = x + c * draw_ts
              dy = y + r * draw_ts
              dw = sw * draw_scale * (1 << diff)
              dh = sh * draw_scale * (1 << diff)
              ctx.drawImage img2.dom, sx, sy, sw, sh, dx, dy, dw, dh
              break

    return


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
    lw2 = 2 * lw
    ctx.save()
    ctx.lineWidth = lw
    for i in @images
      x = i.pos.x * @scale + @pan_x
      y = i.pos.y * @scale + @pan_y
      w = i.pos.w * @scale
      h = i.pos.h * @scale
      continue if x - lw2 > cw or y - lw2 > ch or x + w < -lw2 or y + h < -lw2
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
    @fps = (1000 / ms + @fps * 4) / 5
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

