
IMAGES = [
  {name: 'p1030308', w: 4546, h: 3428, ts: 512, o: 1}
  {name: 'p1030313', w: 4548, h: 3412, ts: 512, o: 1}
  {name: 'p1030318', w: 4553, h: 3424, ts: 512, o: 1}
  {name: 'p1030323', w: 4563, h: 3320, ts: 512, o: 1}
  {name: 'p1030328', w: 4544, h: 3363, ts: 512, o: 1}
  {name: 'p1030333', w: 4569, h: 3384, ts: 512, o: 1}
  {name: 'p1030340', w: 4569, h: 3429, ts: 512, o: 1}
  {name: 'p1030345', w: 4583, h: 3419, ts: 512, o: 1}
  {name: 'p1030350', w: 4542, h: 3370, ts: 512, o: 1}
  {name: 'p1030355', w: 4587, h: 3426, ts: 512, o: 1}
  {name: 'p1030366', w: 4535, h: 3412, ts: 512, o: 1}
  {name: 'p1030371', w: 4517, h: 3374, ts: 512, o: 1}
  {name: 'p1030376', w: 4552, h: 3430, ts: 512, o: 1}
  {name: 'p1030381', w: 4562, h: 3402, ts: 512, o: 1}
  {name: 'p1030395', w: 4571, h: 3389, ts: 512, o: 1}
  {name: 'p1030400', w: 4570, h: 3440, ts: 512, o: 1}
  {name: 'p1030405', w: 4565, h: 3425, ts: 512, o: 1}
  {name: 'p1030410', w: 4542, h: 3419, ts: 512, o: 1}
  {name: 'p1030420', w: 4519, h: 3403, ts: 512, o: 1}
  {name: 'p1030425', w: 4584, h: 3427, ts: 512, o: 1}
  {name: 'p1030430', w: 4527, h: 3403, ts: 512, o: 1}
  {name: 'p1030435', w: 4576, h: 3424, ts: 512, o: 1}
  {name: 'p1030440', w: 4581, h: 3422, ts: 512, o: 1}
  {name: 'p1030445', w: 4571, h: 3434, ts: 512, o: 1}
  {name: 'p1030455', w: 4581, h: 3431, ts: 512, o: 1}
  {name: 'p1030460', w: 4561, h: 3406, ts: 512, o: 1}
  {name: 'p1030465', w: 4579, h: 3399, ts: 512, o: 1}
  {name: 'p1030475', w: 4578, h: 3408, ts: 512, o: 1}
  {name: 'p1030480', w: 4521, h: 3412, ts: 512, o: 1}
  {name: 'p1030485', w: 4568, h: 3433, ts: 512, o: 1}
  {name: 'p1030490', w: 10113, h: 3144, ts: 512, o: 1}
  {name: 'p1030500', w: 4580, h: 3430, ts: 512, o: 1}
  {name: 'p1030505', w: 4581, h: 3436, ts: 512, o: 1}
  {name: 'p1030510', w: 4526, h: 3422, ts: 512, o: 1}
  {name: 'p1030516', w: 4530, h: 3417, ts: 512, o: 1}
  {name: 'p1030521', w: 4583, h: 3440, ts: 512, o: 1}
  {name: 'p1030526', w: 4566, h: 3398, ts: 512, o: 1}
  {name: 'p1030531', w: 4567, h: 3425, ts: 512, o: 1}
  {name: 'p1030541', w: 2048, h: 2510, ts: 512, o: 1}
  {name: 'p1030551', w: 4507, h: 3450, ts: 512, o: 1}
  {name: 'p1030556', w: 4549, h: 3412, ts: 512, o: 1}
  {name: 'p1030561', w: 4581, h: 3421, ts: 512, o: 1}
]
IMAGEDIR = 'images'
PADDING = 150
DRAG_FACTOR = 2
DRAG_THRESHOLD = 3
ZOOM_FACTOR = 2
ANIMATE_MS = 500

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
  _has = Object.prototype.hasOwnProperty

  constructor: (@max_length) ->
    @map = {}
    @length = 0

  _insert: (node) ->
    @map[node[0]] = node
    @length++
    if @length > @max_length
      for key of @map
        # Depends on unspecified behavior, that JavaScript enumerates
        # objects in the order that the keys were inserted.
        if _has.call @map, key
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
    if _has.call @map, key
      node = @map[key]
      node[1] = value
      @_remove node
      @_insert node
    else
      @_insert [key, value]


class ImagePosition
  constructor: (@nat_w, @nat_h) ->
    @base_x = @base_y = 0
    @req_w = @req_h = 100
    @update()

  update: () ->
    ratio = Math.min(@req_w / @nat_w, @req_h / @nat_h)
    @w = @nat_w * ratio
    @h = @nat_h * ratio
    @x = @base_x + (@req_w - @w) / 2
    @y = @base_y + (@req_h - @h) / 2

  move: (@base_x, @base_y) -> @update()
  resize: (@req_w, @req_h) -> @update()


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
    return IMAGEDIR + '/' + @name + '/' + level + '/' + x + '_' + y + '.jpg'

  find_level: (dim) ->
    Math.ceil(Math.log(dim) / Math.LN2)

  render_onto_ctx: (ctx, tile_cache, x, y, w, h) ->
    frame = ctx.ocicle_frame

    level = 1 + @find_level Math.max w, h
    level = Math.max level, @min_level
    level = Math.min level, @max_level
    level_diff = @max_level - level

    max_tiles = (1 << level) / @tile_size
    factor = w / @w * Math.pow(2, level_diff)
    ts = @tile_size * factor

    for c in [0..max_tiles]
      break if c * @tile_size > (@w >> level_diff)

      for r in [0..max_tiles]
        break if r * @tile_size > (@h >> level_diff)

        # ignore tiles outside of viewable area
        draw_x = x + c * ts
        draw_y = y + r * ts
        continue if draw_x > ctx.canvas.width or draw_y > ctx.canvas.height
        continue if draw_x + ts < 0 or draw_y + ts < 0

        draw = do (c, r) -> () ->
          if ctx.ocicle_frame == frame
            ctx.drawImage @,
              x + c * ts,
              y + r * ts,
              @naturalWidth * factor,
              @naturalHeight * factor

        src = @get_at_level level, c, r
        img = tile_cache.get src
        if img?.complete
          draw.call img
        else if img
          img.addEventListener 'load', draw
        else
          img = document.createElement 'img'
          tile_cache.put src, img
          img.src = src
          img.addEventListener 'load', draw

    return


class Ocicle
  constructor: (@c) ->
    @c.addEventListener 'mousedown', @on_mousedown, true
    @c.addEventListener 'contextmenu', @on_mousedown, true
    @c.addEventListener 'mousemove', @on_mousemove, true
    @c.addEventListener 'mouseup', @on_mouseup, true
    @c.addEventListener 'mouseout', @on_mouseup, true

    @frame = 0
    @tile_cache = new LruCache 100
    @images = (new DZImage dz for dz in IMAGES)
    @reset()

  reset: () ->
    @stop_animation()
    @set_pan_x 0
    @set_pan_y 0
    @set_scale 1.0
    @layout_images @c.parentElement.clientWidth, @c.parentElement.clientHeight

  set_pan_x: (@pan_x) =>
  set_pan_y: (@pan_y) =>
  set_scale: (@scale) =>

  layout_images: (totalw, totalh) ->
    padding = totalw / PADDING
    len = @images.length

    cols = Math.ceil len / (Math.ceil Math.sqrt len)
    paircols = cols + cols - 1
    pairrows = Math.ceil (len / paircols)
    rows = pairrows * 2
    if len <= pairrows * paircols - cols + 1 then rows -= 1

    boxw = totalw / cols
    boxh = totalh / rows
    imgw = boxw - 2 * padding
    imgh = boxh - 2 * padding

    i = 0
    for r in [1..rows]
      even = 1 - (r % 2)
      for c in [1..cols - even]
        if i >= len then break
        @images[i].pos.move (c-1+even/2) * boxw + padding, (r-1) * boxh + padding
        @images[i].pos.resize imgw, imgh
        i += 1

    @render()

  on_mousedown: (e) =>
    if e.button == 0 or e.button == 2
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
        x =
          start: @pan_x
          end: @drag_pan_x + DRAG_FACTOR * move_x
          set: @set_pan_x
        y =
          start: @pan_y
          end: @drag_pan_y + DRAG_FACTOR * move_y
          set: @set_pan_y
        @animate [x, y], ANIMATE_MS

  on_mouseup: (e) =>
    if @drag_state == 1
      e.preventDefault()
      @do_zoom (if e.button == 0 then ZOOM_FACTOR else 1/ZOOM_FACTOR),
        e.clientX, e.clientY
    @drag_state = 0

  do_zoom: (factor, client_x, client_y) =>
    bounds = @c.getBoundingClientRect()
    center_x = client_x - bounds.left - @c.clientLeft + @c.scrollLeft
    center_y = client_y - bounds.top - @c.clientTop + @c.scrollTop

    size =
      start: @scale
      end: @scale * factor
      set: @set_scale
    x =
      start: @pan_x
      end: center_x - factor * (center_x - @pan_x)
      set: @set_pan_x
    y =
      start: @pan_y
      end: center_y - factor * (center_y - @pan_y)
      set: @set_pan_y
    @animate [size, x, y], ANIMATE_MS

  stop_animation: () ->
    cancelFrame @request_id if @request_id

  animate: (props, ms) ->
    @stop_animation()
    start = Date.now() - 5
    fn = () =>
      t = Math.sqrt (Math.min 1, (Date.now() - start) / ms)
      for prop in props
        prop.set prop.start * (1-t) + prop.end * t
      @render()
      @request_id = if t < 1 then requestFrame fn, @c
    fn()

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
    ctx.strokeStyle = '#222'  # for image frames
    ctx.lineWidth = Math.max 1, @scale
    for i in @images
      x = i.pos.x * @scale + @pan_x
      y = i.pos.y * @scale + @pan_y
      w = i.pos.w * @scale
      h = i.pos.h * @scale
      continue if x > cw or y > ch or x + w < 0 or y + h < 0
      ctx.strokeRect x, y, w, h
      i.render_onto_ctx ctx, @tile_cache, x, y, w, h
    return



log = (id, l) -> (document.getElementById id).innerText = l

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

