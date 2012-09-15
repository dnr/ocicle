
# TODO:
# use more detailed scales when zooming out.
# do more pre-fetching all around.
# resize top and bottom bars based on font size.
# tab or something to jump to "next" image.
# change marks (and maybe more) to use different coords:
#   extent of central vertical line
# background: don't do loop, figure out appropriate coords.
# think about how to integrate super-wide or 360 panos.
# play:
#   auto-stop on hitting last image
#   pre-calculate tiles needed for path during pause, pre-fetch
#   fix issues around hitting next/prev while flying

DRAG_FACTOR = 2
DRAG_THRESHOLD = 3
CLICK_ZOOM_FACTOR = 2
WHEEL_ZOOM_FACTOR = Math.pow(2, 1/5)
SLIDE_MS = 500
FLY_MS = 1500
PLAY_HOLD_MS = 3000
FRAME_WIDTH = 1
TILE_CACHE_SIZE = 500
FAKE_DELAY = 0 #+500
CENTER_BORDER = 40
DEBUG_BORDERS = false
ZOOM_LIMIT_LIMIT = 3.3
ZOOM_LIMIT_TARGET = 3.0
UNZOOM_LIMIT = 1/10

BKGD_SCALEFACTOR = 8
BKGD_SCALES = (Math.pow(BKGD_SCALEFACTOR, scale) for scale in [-1..3])
BKGD_IMAGE = 'bkgd/bk.jpg'

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

array_sum = (a) ->
  t = 0
  t += x for x in a
  t

weights_to_alphas = (weights) ->
  total_weight = array_sum weights
  cumulative_weight = 0
  alphas = []
  for w in weights
    alphas.push if w then 1 - cumulative_weight / total_weight else 0
    cumulative_weight += w
  alphas

calc_scale_alphas = (scale) ->
  len = BKGD_SCALES.length
  if scale < BKGD_SCALES[0]
    weights = (0 for _ in BKGD_SCALES)
    weights[0] = 1
  else if scale > BKGD_SCALES[len-1]
    weights = (0 for _ in BKGD_SCALES)
    weights[len-1] = 1
  else
    weights = for s in BKGD_SCALES
      ratio = Math.log(s / scale) / Math.log(BKGD_SCALEFACTOR)
      Math.max 0, 1 - Math.pow(ratio, 2)
  weights_to_alphas weights

# Fits a parabola to (0, y1), (1, y2), (_, y3)
parabola = (y1, y2, y3) ->
  a = y1 + y2 - 2 * y3 - 2 * Math.sqrt (y3 - y1) * (y3 - y2)
  b = y2 - y1 - a
  [a, b, y1]

asinh = (x) ->
  Math.log(x + Math.sqrt(x * x + 1))

# Arc length of ax^2+bx+c from 0 to x
parabola_len = (a, b, x) ->
  f = (t) ->
    s = Math.sqrt 4 * a * a * t * t + 4 * a * b * t + b * b + 1
    s *= 2 * a * t + b
    s += asinh 2 * a * t + b
    s / (4 * a)
  f(x) - f(0)

# Finds a root of f using Ridders' method. x1 and x2 must bound root.
# http://en.wikipedia.org/wiki/Ridders%27_method
find_root = (f, x1, x2, thresh=0.000001) ->
  f1 = f(x1)
  f2 = f(x2)
  for iter in [1..10]
    x3 = (x1 + x2) / 2
    f3 = f(x3)
    s = if f1 - f2 > 0 then 1 else -1
    r = Math.sqrt f3 * f3 - f1 * f2
    return x3 if r == 0
    x4 = x3 + (x3 - x1) * s * f3 / r
    f4 = f(x4)
    return x4 if Math.abs(f4) < thresh
    if f3 * f4 < 0
      x1 = x3
      f1 = f3
    else if f2 * f4 < 0
      x1 = x2
      f1 = f2
    x2 = x4
    f2 = f4
  return x4

# Find x such that parabola_len a, b, x == s
inverse_parabola_len = (a, b, s) ->
  f = (x) -> parabola_len(a, b, x) - s
  find_root f, 0, 1


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
    @play false
    @last_now = @fps = 0
    @images = (new DZImage dz for dz in @meta.data.images)
    @bkgd_image = new ImageLoader BKGD_IMAGE
    @setup_bookmarks()
    @tile_cache = new LruCache TILE_CACHE_SIZE
    @pan_x = @pan_y = 0
    @scale = @scale_target = 1
    @gridsize = parseInt $('gridsize').value
    @render()

  setup_bookmarks: () ->
    ul = $('gotolist')
    clear_node ul
    for mark in @meta.data.marks
      li = document.createElement 'li'
      a = document.createElement 'a'
      a.href = '#'
      a.innerText = mark.name
      a.onclick = do (mark) => () =>
        @play false
        @fly_to mark.scale, mark.x, mark.y
        false
      li.appendChild a
      ul.appendChild li

  find_mark: (name) ->
    for mark in @meta.data.marks
      if mark.name == name
        return mark

  edit: () ->
    editlink = $('editlink')
    if @editmode
      editlink.style.background = 'red'
      @meta.save (success) ->
        if success then editlink.style.background = 'inherit'
    else
      @editmode = true
      editlink.src = 'icons/save.png'
      $('editstuff').style.display = 'block'

      desc = $('desc')
      desc.contentEditable = true
      desc.addEventListener 'input', () =>
        if @highlight_image
          @highlight_image.meta.desc = desc.innerText

      shape = $('shapeselect')
      shape.addEventListener 'change', () =>
        if @highlight_image
          @highlight_image.meta.shape = parseInt shape.value
          @render()

      editmark = $('editmark')
      editmark.addEventListener 'change', () =>
        name = editmark.value
        editmark.value = ''
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

      gridsize = $('gridsize')
      gridsize.addEventListener 'change', () =>
        @gridsize = parseInt gridsize.value
        @render()

      delbutton = $('delete')
      delbutton.addEventListener 'click', () =>
        return unless @highlight_image
        idx = @images.indexOf @highlight_image
        midx = @meta.data.images.indexOf @highlight_image.meta
        if idx < 0 or midx < 0
          return console.log "couldn't find images: " + idx + ',' + midx
        @images.splice idx, 1
        @meta.data.images.splice midx, 1
        @render()

      reorder = (pos) =>
        return unless @highlight_image
        idx = @images.indexOf @highlight_image
        midx = @meta.data.images.indexOf @highlight_image.meta
        if idx != midx or idx < 0
          return console.log "couldn't find images: " + idx + ',' + midx
        [img] = @images.splice idx, 1
        [mimg] = @meta.data.images.splice idx, 1
        if pos == 'first'
          @images.unshift img
          @meta.data.images.unshift mimg
        else if pos == 'last'
          @images.push img
          @meta.data.images.push mimg
        else if pos == 'up'
          @images.splice idx-1, 0, img
          @meta.data.images.splice idx-1, 0, mimg
        else if pos == 'down'
          @images.splice idx+1, 0, img
          @meta.data.images.splice idx+1, 0, mimg
        @render()

      $('order_first').addEventListener 'click', () -> reorder 'first'
      $('order_last').addEventListener 'click', () -> reorder 'last'
      $('order_up').addEventListener 'click', () -> reorder 'up'
      $('order_down').addEventListener 'click', () -> reorder 'down'

      @render()

  find_containing_image_client: (x, y) ->
    bounds = @c.getBoundingClientRect()
    @find_containing_image_canvas x - bounds.left, y - bounds.top

  find_containing_image_canvas: (x, y) ->
    x = (x - @pan_x) / @scale
    y = (y - @pan_y) / @scale
    for i in @images
      if x >= i.px and y >= i.py and x <= i.px + i.pw and y <= i.py + i.ph
        xr = (x - i.px) / i.pw * 6
        yr = (y - i.py) / i.ph * 6
        xa = if xr < 1 then -1 else if xr > 5 then 1 else 0
        ya = if yr < 1 then -1 else if yr > 5 then 1 else 0
        return [i, xa, ya]
    return [null, 0, 0]

  interaction_normal =
    mousedown: (e) ->
      if e.button == 0 or e.button == 1 or e.button == 2
        e.preventDefault()
        @stop_animation()
        @play false
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
          @slide_to @scale, pan_x, pan_y

    mouseup: (e) ->
      if @drag_state == 1
        e.preventDefault()
        if e.button == 0 or e.button == 2
          factor = if e.button == 0 then CLICK_ZOOM_FACTOR else 1/CLICK_ZOOM_FACTOR
          @do_zoom factor, e.clientX, e.clientY
        else if e.button == 1
          [i] = @find_containing_image_client e.clientX, e.clientY
          @center_around i
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
    #  2: drag/resize image
    mousedown: (e) ->
      e.preventDefault()
      @stop_animation()
      @play false
      @drag_screen_x = e.screenX
      @drag_screen_y = e.screenY
      [@drag_img, xa, ya] = @find_containing_image_client e.clientX, e.clientY
      if @drag_img and e.button == 0
        @drag_state = 2
        @drag_area = [xa, ya]
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
      else if @drag_state == 2  # drag/resize image
        [xa, ya] = @drag_area
        aspect = @drag_img.w / @drag_img.h
        drag_ph = @drag_pw / aspect
        if xa == 1  # right
          x = @snap @drag_px + @drag_pw + move_x / @scale
          @drag_img.scale x - @drag_px
        else if xa == -1  # left
          x = @snap @drag_px + move_x / @scale
          @drag_img.move x, @drag_py
          @drag_img.scale @drag_pw + @drag_px - x
        else if ya == 1  # bottom
          y = @snap @drag_py + drag_ph + move_y / @scale
          @drag_img.scale aspect * (y - @drag_py)
        else if ya == -1  # top
          y = @snap @drag_py + move_y / @scale
          @drag_img.move @drag_px, y
          @drag_img.scale aspect * (drag_ph + @drag_py - y)
        else  # center
          x = @drag_px + move_x / @scale
          y = @drag_py + move_y / @scale
          snap_and_dist = (w, h) =>
            sx = @snap x + w
            sy = @snap y + h
            dx = x + w - sx
            dy = y + h - sy
            [sx - w, sy - h, dx*dx+dy*dy]
          pts = [
            snap_and_dist 0, 0
            snap_and_dist @drag_pw, 0
            snap_and_dist 0, drag_ph
            snap_and_dist @drag_pw, drag_ph
          ].sort (a, b) -> a[2] - b[2]
          @drag_img.move pts[0][0], pts[0][1]

      @render()

    mouseup: (e) ->
      @drag_state = 0

    mousewheel: interaction_normal.mousewheel

  nav: (dir) ->
    if @highlight_image
      idx = @images.indexOf @highlight_image
      idx += dir
      return if idx < 0 or idx >= @images.length
      @center_around @images[idx]
    else
      @center_around @images[0]

  next: () ->
    @play false
    @nav 1

  prev: () ->
    @play false
    @nav -1

  play: (action) ->
    if action is undefined
      action = not @playing
    if action
      @playing = window.setInterval (=> @nav 1), FLY_MS + PLAY_HOLD_MS
      @nav 1
      $('play').src = 'icons/pause.png'
    else
      window.clearInterval @playing if @playing
      @playing = null
      $('play').src = 'icons/play.png'

  center_around: (i) ->
    return unless i
    scale = Math.min (@c.width - CENTER_BORDER) / i.pw,
                     (@c.height - CENTER_BORDER) / i.ph
    pan_x = @c.width / 2 - (i.px + i.pw / 2) * scale
    pan_y = @c.height / 2 - (i.py + i.ph / 2) * scale
    @fly_to scale, pan_x, pan_y

  do_zoom: (factor, client_x, client_y) ->
    bounds = @c.getBoundingClientRect()
    center_x = client_x - bounds.left
    center_y = client_y - bounds.top

    @scale_target *= factor
    pan_x = center_x - @scale_target / @scale * (center_x - @pan_x)
    pan_y = center_y - @scale_target / @scale * (center_y - @pan_y)
    @slide_to @scale_target, pan_x, pan_y

  slide_to: (end_s, end_x, end_y) ->
    @scale_target = end_s
    start_x = @pan_x
    start_y = @pan_y
    start_s = @scale
    update = (t) =>
      t = Math.sqrt t  # start fast, end slow
      @pan_x = start_x * (1-t) + end_x * t
      @pan_y = start_y * (1-t) + end_y * t
      @scale = start_s * (1-t) + end_s * t
    @animate update, SLIDE_MS

  fly_to: (end_s, end_x, end_y) ->
    @scale_target = end_s
    start_x = @pan_x
    start_y = @pan_y
    start_s = @scale

    start_gx = (@cw2 - start_x) / start_s
    start_gy = (@ch2 - start_y) / start_s
    start_gz = 1 / start_s
    end_gx = (@cw2 - end_x) / end_s
    end_gy = (@ch2 - end_y) / end_s
    end_gz = 1 / end_s

    dy = end_gy - start_gy
    dx = end_gx - start_gx
    theta = Math.atan2 dy, dx
    dist = Math.sqrt dx * dx + dy * dy
    diag = Math.sqrt @cw * @cw + @ch * @ch

    mid_gz = Math.max(start_gz, end_gz) + dist / diag / 2

    [a, b, c] = parabola start_gz, end_gz, mid_gz
    return if a == 0
    total_s = parabola_len a, b, 1

    update = (t) =>
      # Move along the parabola at constant velocity.
      t = inverse_parabola_len a, b, t * total_s

      gz = a * t * t + b * t + c
      gx = start_gx + t * dist * Math.cos theta
      gy = start_gy + t * dist * Math.sin theta

      @scale = 1 / gz
      @pan_x = @cw2 - gx / gz
      @pan_y = @ch2 - gy / gz
    @animate update, FLY_MS, false

  stop_animation: () ->
    cancelFrame @request_id if @request_id

  animate: (update, ms, check_limit=true) ->
    @stop_animation()
    start = Date.now() - 5
    frame = () =>
      t = Math.min 1, (Date.now() - start) / ms
      update t
      @render()
      if check_limit and @hit_limit
        @scale_target = @scale
        @do_zoom @hit_limit, @c.width/2, @c.height/2
      else
        @request_id = if t < 1 then requestFrame frame, @c
    frame()

  on_resize: () ->
    @render()


  setup_context: () ->
    @cw = @c.parentElement.clientWidth
    if @c.width != @cw then @c.width = @cw
    @ch = @c.parentElement.clientHeight
    if @c.height != @ch then @c.height = @ch
    @cw2 = @cw / 2
    @ch2 = @ch / 2

    ctx = @c.getContext '2d'
    ctx.clearRect 0, 0, @cw, @ch
    ctx

  draw_background: (ctx) ->
    return unless @bkgd_image.complete

    img = @bkgd_image.dom
    alphas = calc_scale_alphas @scale
    for s in BKGD_SCALES
      alpha = alphas.shift()
      continue unless alpha
      ctx.globalAlpha = alpha
      sz = img.naturalWidth * @scale / s
      sx = ((@pan_x % sz) + sz) % sz
      sy = ((@pan_y % sz) + sz) % sz
      for c in [-1..@cw/sz]
        for r in [-1..@ch/sz]
          ctx.drawImage img, sx + c * sz, sy + r * sz, sz, sz

    ctx.globalAlpha = 1

  update_highlight_image: () ->
    # must be over center point of canvas
    [i] = @find_containing_image_canvas @cw2, @ch2
    # and must be at least half the width or height
    if i
      if i.pw * @scale / @cw < 0.5 and i.ph * @scale / @ch < 0.5
        i = null
    # update description
    desc = (i?.meta.desc or '').replace /\n$/, ''
    set_text 'desc', desc
    $('desc').style.lineHeight = if desc.search('\n') > 0 then 1.1 else 2.2
    if @editmode
      $('shapeselect').value = i?.meta.shape
    @highlight_image = i

  update_fps: () ->
    now = Date.now()
    ms = now - @last_now
    @fps = (1000 / ms + @fps * 9) / 10
    set_text 'fps', @fps.toFixed 0
    @last_now = now
    #set_text 'zoom', (Math.log(@scale) / Math.LN2).toFixed 1
    set_text 'tiles', @tile_cache.puts

  snap: (x) ->
    if @gridsize then @gridsize * Math.round x / @gridsize else x

  draw_grid: (ctx) ->
    return unless @gridsize and @editmode
    ctx.beginPath()
    x = @snap -@pan_x / @scale
    y = @snap -@pan_y / @scale
    end_x = (@cw - @pan_x) / @scale
    end_y = (@ch - @pan_y) / @scale
    while x < end_x
      dx = 0.5 + Math.floor x * @scale + @pan_x
      ctx.moveTo dx, 0
      ctx.lineTo dx, @ch
      x += @gridsize
    while y < end_y
      dy = 0.5 + Math.floor y * @scale + @pan_y
      ctx.moveTo 0, dy
      ctx.lineTo @cw, dy
      y += @gridsize
    ctx.lineWidth = 1
    ctx.strokeStyle = 'hsl(210,5%,25%)'
    ctx.stroke()

  render: () ->
    ctx = @setup_context()
    @draw_background ctx
    @update_highlight_image()
    @update_fps()
    @draw_grid ctx

    ctx.lineWidth = Math.max 1, FRAME_WIDTH * @scale
    ctx.strokeStyle = 'hsl(210,5%,5%)'
    ctx.shadowColor = 'hsl(210,5%,15%)'
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

      if i is @highlight_image
        ctx.shadowOffsetX = ctx.shadowOffsetY = shadow

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

    # draw links
    if @editmode
      ctx.lineWidth = 3
      ctx.strokeStyle = 'rgba(0,200,0,0.5)'
      ctx.beginPath()
      for i in @images
        x = (i.px + i.pw/2) * @scale + @pan_x
        y = (i.py + i.ph/2) * @scale + @pan_y
        if i is @images[0]
          ctx.moveTo x, y
        else
          ctx.lineTo x, y
      ctx.stroke()

    if max_ratio == 0
      set_text 'ratio', ''
    else if max_ratio < 1
      set_text 'ratio', '1\u2236' + (1 / max_ratio).toFixed 1
    else
      set_text 'ratio', max_ratio.toFixed 1

    @hit_limit = false
    if max_ratio > 0 and max_ratio < 1 / ZOOM_LIMIT_LIMIT
      @hit_limit = max_ratio * ZOOM_LIMIT_TARGET
    else if @scale < UNZOOM_LIMIT
      @hit_limit = 1.05

    return

  img_load_cb: () =>
    # TODO: check if any pending and render then, not this timeout stuff
    if @load_timeout_id then window.clearTimeout @load_timeout_id
    @load_timeout_id = window.setTimeout (=>@render()), 50


on_resize = () ->
  $('desc').style.width = \
    $('bottombar').clientWidth - $('bottomstuff').clientWidth - 16
  mb = $('mainbox')
  mb.style.height = \
    mb.parentElement.clientHeight - $('bottombar').clientHeight
  if window.ocicle then window.ocicle.on_resize()

on_load = () ->
  on_resize()
  storage = new Storage '/data/'
  meta = new Metadata storage, (meta) ->
    window.ocicle = new Ocicle $('canvas'), meta

window.addEventListener 'resize', on_resize, false
window.addEventListener 'load', on_load, false
