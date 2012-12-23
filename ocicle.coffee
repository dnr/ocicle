
# TODO:
# use more detailed scales when zooming out.
# keyboard shortcuts.
# play:
#   fix issues around hitting next/prev while flying
# fix sluggishness when flying across big waterfall.
#   maybe use one level lower while animating?
# make nicer frames?
# queue for downloading images
#
# 3d:
# load tiles through tilecache
# drop some tiles when no longer on screen
# compressed textures
# update ratio
# fix projectScene bug: subdivide to check
# make panning more natural
# zoom around cursor
#
# mobile:
# hide fullscreen button on mobile
#
# pre-launch:
# finish content
# analytics

DRAG_FACTOR = 2
DRAG_FACTOR_3D = 180
DRAG_THRESHOLD = 3
CLICK_ZOOM_FACTOR = 2
WHEEL_ZOOM_FACTOR = Math.pow(2, 1/5)
SLIDE_MS = 500
FLY_MS = 1500
PLAY_HOLD_MS = 3000
FRAME_WIDTH = 1/150
TILE_CACHE_SIZE = 600
FAKE_DELAY = 0 #+1500
CENTER_BORDER = 40
DEBUG_BORDERS = false
ZOOM_LIMIT_LIMIT = 3.3
ZOOM_LIMIT_TARGET = 3.0
UNZOOM_LIMIT = 1/10
FOV_MIN = 4
FOV_INIT = 75
FOV_OUT = 110
FOV_MAX = 120

# Set false for more speed.
PANO_DRAW_LOWER_LEVELS = false

BKGD_SCALEFACTOR = 8
BKGD_IMAGE = 'bkgd/bk4as.jpg'

PLAY_ICON = 'icons/play.png'
PAUSE_ICON = 'icons/pause.png'
SAVE_ICON = 'icons/save.png'

TILE_PREFIX = 'http://dmyxhfpirp60t.cloudfront.net/'
#[[[
TILE_PREFIX = 'tiles/'
#]]]

# This is a little lame, but ok for now.
MOBILE = /Android|webOS|iPhone|iPad|iPod|BlackBerry/i.test navigator.userAgent

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

clamp = (x, min, max) ->
  Math.min max, Math.max min, x

rect_is_outside = (cw, ch, x, y, w, h) ->
  x + w < 0 or y + h < 0 or x > cw or y > ch

rect_intersect = (a, b) ->
  if a.pw > 0
    ax1 = a.px; ax2 = a.px + a.pw
  else
    ax2 = a.px; ax1 = a.px + a.pw
  if a.ph > 0
    ay1 = a.py; ay2 = a.py + a.ph
  else
    ay2 = a.py; ay1 = a.py + a.ph
  if b.pw > 0
    bx1 = b.px; bx2 = b.px + b.pw
  else
    bx2 = b.px; bx1 = b.px + b.pw
  if b.ph > 0
    by1 = b.py; by2 = b.py + b.ph
  else
    by2 = b.py; by1 = b.py + b.ph
  ax2 >= bx1 and bx2 >= ax1 and ay2 >= by1 and by2 >= ay1

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

is_empty_obj = (o) ->
  for own k of o
    return false
  return true

log = (x, b) ->
  Math.log(x) / Math.log(b)
log2 = (x) ->
  Math.log(x) / Math.LN2

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

compute_flying_path = (cw, ch, start, end) ->
  cw2 = cw / 2
  ch2 = ch / 2

  start_gx = (cw2 - start.pan_x) / start.scale
  start_gy = (ch2 - start.pan_y) / start.scale
  start_gz = 1 / start.scale
  end_gx = (cw2 - end.pan_x) / end.scale
  end_gy = (ch2 - end.pan_y) / end.scale
  end_gz = 1 / end.scale

  dy = end_gy - start_gy
  dx = end_gx - start_gx
  theta = Math.atan2 dy, dx
  dist = Math.sqrt dx * dx + dy * dy
  diag = Math.sqrt cw * cw + ch * ch

  mid_gz = Math.max(start_gz, end_gz) + dist / diag / 2

  [a, b, c] = parabola start_gz, end_gz, mid_gz
  return if a == 0
  total_s = parabola_len a, b, 1

  (t, out) ->
    # Move along the parabola at constant velocity.
    t = inverse_parabola_len a, b, t * total_s

    gz = a * t * t + b * t + c
    gx = start_gx + t * dist * Math.cos theta
    gy = start_gy + t * dist * Math.sin theta

    out.scale = 1 / gz
    out.pan_x = cw2 - gx / gz
    out.pan_y = ch2 - gy / gz
    out


# e: THREE.RenderableFace4
is_off_screen = (e) ->
  {v1, v2, v3, v4} = e
  x1 = v1.positionScreen.x
  y1 = v1.positionScreen.y
  x2 = v2.positionScreen.x
  y2 = v2.positionScreen.y
  x3 = v3.positionScreen.x
  y3 = v3.positionScreen.y
  x4 = v4.positionScreen.x
  y4 = v4.positionScreen.y
  Math.min(x1, x2, x3, x4) > 1 or
  Math.max(x1, x2, x3, x4) < -1 or
  Math.min(y1, y2, y3, y4) > 1 or
  Math.max(y1, y2, y3, y4) < -1


# Heavily adapted from three.js's CubeGeometry.
# https://github.com/mrdoob/three.js/blob/master/src/extras/geometries/CubeGeometry.js
class PanoCube extends THREE.Geometry
  make_material = (url, max_aniso, redraw) ->
    tex = new THREE.Texture
    tex.anisotropy = max_aniso
    tex.minFilter = THREE.LinearFilter
    tex.generateMipmaps = false
    mat = new THREE.MeshBasicMaterial {map: tex, overdraw: true, visible: false}
    cb = (loader) =>
      tex.image = loader.dom
      tex.needsUpdate = true
      mat.visible = true
      redraw()
    mat._ocicle_loader = new ImageLoader url, cb, false
    mat

  constructor: (size, split_level, tile_level, get_url, max_aniso, redraw) ->
    super()

    url_idx_map = {}
    split_level = Math.max split_level, tile_level
    grid = 1 << split_level
    tile_div = 1 << (split_level - tile_level)
    segment = size / grid
    size_half = size / 2

    for [u, v, w, udir, vdir, wdir, facecode] in [
      ['z', 'y', 'x', -1, -1,  1, 'r']
      ['z', 'y', 'x',  1, -1, -1, 'l']
      ['x', 'z', 'y',  1,  1,  1, 'u']
      ['x', 'z', 'y',  1, -1, -1, 'd']
      ['x', 'y', 'z',  1, -1,  1, 'f']
      ['x', 'y', 'z', -1, -1, -1, 'b']
    ]
      offset = @vertices.length
      for iy in [0..grid]
        for ix in [0..grid]
          vector = new THREE.Vector3
          vector[u] = (ix * segment - size_half) * udir
          vector[v] = (iy * segment - size_half) * vdir
          vector[w] = size_half * wdir
          @vertices.push vector

      for iy in [0...grid]
        for ix in [0...grid]
          a = ix + (grid + 1) * iy
          b = ix + (grid + 1) * (iy + 1)
          c = (ix + 1) + (grid + 1) * (iy + 1)
          d = (ix + 1) + (grid + 1) * iy
          face = new THREE.Face4 a + offset, b + offset, c + offset, d + offset
          @faces.push face

          tx = Math.floor ix / tile_div
          ty = Math.floor iy / tile_div
          itx = ix - tx * tile_div
          ity = iy - ty * tile_div

          url = get_url(tile_level, facecode, tx, ty)
          idx = url_idx_map[url]
          if idx is undefined
            url_idx_map[url] = idx = @materials.length
            @materials.push make_material url, max_aniso, redraw
          face.materialIndex = idx

          @faceVertexUvs[0].push [
            new THREE.UV itx / tile_div, 1 - ity / tile_div
            new THREE.UV itx / tile_div, 1 - (ity + 1) / tile_div
            new THREE.UV (itx + 1) / tile_div, 1 - (ity + 1) / tile_div
            new THREE.UV (itx + 1) / tile_div, 1 - ity / tile_div
          ]

    @computeCentroids()
    @mergeVertices()


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
#   pos: view-position (see View::to/from_position)
# }]
class Metadata
  constructor: (@data, @js_path) ->

  save: (cb) ->
    value = JSON.stringify @data
    value = 'window.META=' + value + ';\n'
    simpleXHR 'PUT', @js_path, value, (req) ->
      if cb then cb req.status == 200


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


class ImageLoader
  requested = 0
  done = 0

  delay = (func) ->
    () -> window.setTimeout func, FAKE_DELAY + 200 * Math.random()

  constructor: (@src, @cb, autoload=true) ->
    @load() if autoload

  load: () ->
    if @src
      @complete = false
      @dom = new Image()
      @dom.addEventListener 'load', if FAKE_DELAY then delay @_onload else @_onload
      @dom.addEventListener 'error', if FAKE_DELAY then delay @_onerror else @_onerror
      requested++
      @dom.src = @src
      @src = null

  _onload: () =>
    done++
    @complete = true
    @cb @ if @cb
    delete @cb

  _onerror: () =>
    done++

  @stats: () ->
    '' + (requested - done) + '/' + requested


class DZImage
  constructor: (meta) ->
    {@src, @w, @h, @ts, px, py, pw, @desc, @shape, @pano} = meta
    @min_level = @find_level @ts / 2
    @max_level = @find_level Math.max @w, @h
    @move px, py
    @scale pw

  get_meta: () ->
    return {@src, @w, @h, @ts, @px, @py, @pw, @desc, @shape, @pano}

  clone: () ->
    new DZImage @get_meta()

  move: (@px, @py) ->

  scale: (@pw) ->
    @ph = @h * @pw / @w

  get_at_level: (level, x, y) ->
    "#{TILE_PREFIX}#{@src}/#{level}/#{x}_#{y}.jpg"

  find_level: (dim) ->
    Math.ceil log2 dim

  render_onto_ctx: (ctx, tile_cache, x, y, w, h, redraw) ->
    tile_size = @ts

    level = 1 + @find_level Math.max w, h
    level = clamp level, @min_level, @max_level
    source_scale = 1 << (@max_level - level)
    max_c = @w / source_scale / tile_size
    max_r = @h / source_scale / tile_size
    # this assumes the aspect ratio is preserved:
    draw_scale = w / @w * source_scale
    draw_ts = tile_size * draw_scale

    for c in [0 .. max_c]
      for r in [0 .. max_r]
        # ignore tiles outside of viewable area
        continue if rect_is_outside(@cw, @ch,
          x + c * draw_ts, y + r * draw_ts, draw_ts, draw_ts)

        # draw from most detailed level
        try_levels = if ctx then [level..@min_level] else [level]
        for level2 in try_levels
          diff = level - level2
          src = @get_at_level level2, c >> diff, r >> diff
          img = tile_cache.get src
          if img?.complete
            if ctx
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
              img = new ImageLoader src, redraw
              tile_cache.put src, img
    return


# DZPano requirements:
# The dimensions of the cube faces must be a power of two times the tile
# size. So if your tiles are 512x512, the faces must be either 1024,
# 2048, 4096, etc. The base level is the level where one tile exactly
# covers the face.
class DZPano
  constructor: (@meta) ->
    {@src, size, @ts} = @meta
    tiles = size / @ts
    if tiles != Math.floor tiles or tiles & (tiles - 1)
      console.warn "Cube face size #{size} is not POT times tile size #{@ts}"
    @base_level = Math.ceil log2 @ts
    @max_level = Math.ceil log2 size
    @levels = @max_level - @base_level + 1

  get_url: (level, face, ix, iy) =>
    level = @base_level + level
    "#{TILE_PREFIX}#{@src}_#{face}/#{level}/#{ix}_#{iy}.jpg"


class View
  constructor: (@scale, @pan_x, @pan_y) ->

  copy_to: (v) ->
    v.scale = @scale
    v.pan_x = @pan_x
    v.pan_y = @pan_y

  from_position: (cw2, ch2, pos) ->
    # put pos.px, py in the center of the screen, with at least pos.r distance
    # from the edges.
    @scale = Math.min(cw2, ch2) / pos.r
    @pan_x = cw2 - pos.px * @scale
    @pan_y = ch2 - pos.py * @scale

  to_position: (cw2, ch2) ->
    r: Math.min(cw2, ch2) / @scale
    px: (cw2 - @pan_x) / @scale
    py: (ch2 - @pan_y) / @scale

class View3
  constructor: (@fov, @lat, @lon) ->

  copy_to: (v) ->
    v.fov = @fov
    v.lat = @lat
    v.lon = @lon


class Ocicle
  constructor: (@c2, @c3, @meta, @bkgd_image) ->
    #[[[
    @edit_mode = false
    #]]]

    add_event = (events, method) =>
      edit_switch = () => interaction_normal[method].apply @, arguments
      #[[[
      edit_switch = () =>
        interaction = if @edit_mode then interaction_edit else interaction_normal
        interaction[method].apply @, arguments
      #]]]
      for event in events
        @c2.addEventListener event, edit_switch, true
        @c3.addEventListener event, edit_switch, true
      return

    add_event ['mousedown', 'contextmenu'], 'mousedown'
    add_event ['mousemove'], 'mousemove'
    add_event ['mouseup', 'mouseout'], 'mouseup'
    add_event ['mousewheel', 'DOMMouseScroll'], 'mousewheel'
    add_event ['touchstart'], 'touchstart'
    add_event ['touchmove'], 'touchmove'
    add_event ['touchend', 'touchleave', 'touchcancel'], 'touchend'

    @last_now = @fps = 0
    #[[[
    @gridsize = parseInt $('gridsize').value
    #]]]
    @images = (new DZImage dz for dz in @meta.data.images)
    @setup_bookmarks()
    @tile_cache = new LruCache TILE_CACHE_SIZE

    @touch_state = {}
    @drag_view = new View
    @drag_view3 = new View3

    @fov_target = FOV_OUT
    @view3 = new View3 90, 0, 0
    @view3_t = new View3  # reusable object
    @three_d = false

    @setup_contexts()

    @view = new View
    @view_t = new View  # reusable object
    @view.from_position @cw2, @ch2, @find_mark('home').pos
    @redraw()


  setup_contexts: () ->
    @cw = @c2.parentElement.clientWidth
    if @c2.width != @cw then @c2.width = @cw
    if @c3.width != @cw then @c3.width = @cw
    @ch = @c2.parentElement.clientHeight
    if @c2.height != @ch then @c2.height = @ch
    if @c3.height != @ch then @c3.height = @ch

    @cw2 = @cw / 2
    @ch2 = @ch / 2

    @ctx2 = @c2.getContext '2d'

    unless @t_renderer  # one-time stuff
      @t_renderer = new THREE.CanvasRenderer {canvas: @c3}
      @t_target = new THREE.Vector3 0, 0, 0  # reusable object
      @t_camera = new THREE.PerspectiveCamera
      @t_projector = new THREE.Projector

    @t_renderer.setSize @cw, @ch
    @point_camera @view3

  setup_pano: (pano_meta) ->
    if @t_pano?.src != pano_meta.src
      @t_pano = new DZPano pano_meta
      max_aniso = @t_renderer.getMaxAnisotropy()
      @t_scene = new THREE.Scene()
      @t_meshes = for level in [0...@t_pano.levels]
        size = 100 - level
        # Always split into at least 16ths for the canvas renderer,
        # to cover up affine mapping artifacts. 3 isn't enough, 5 is
        # too slow, 4 works well.
        # TODO: fix magic 4
        geometry = new PanoCube size, 4, level, @t_pano.get_url, max_aniso, @redraw
        mesh = new THREE.Mesh geometry, new THREE.MeshFaceMaterial
        mesh.scale.x = -1
        mesh.visible = false
        @t_scene.add mesh
        mesh
    return

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
        @view_t.from_position @cw2, @ch2, mark.pos
        @fly_to @view_t
        false
      li.appendChild a
      ul.appendChild li

  find_mark: (name) ->
    for mark in @meta.data.marks
      if mark.name == name
        return mark

  #[[[
  edit: () ->
    editlink = $('editlink')
    if @edit_mode
      editlink.style.background = 'red'
      @meta.data.images = (i.get_meta() for i in @images)
      @meta.save (success) ->
        if success then editlink.style.background = 'inherit'
    else
      @edit_mode = true
      @edit_images = []
      editlink.src = SAVE_ICON
      $('editstuff').style.display = 'block'

      desc = $('desc')
      desc.contentEditable = true
      desc.addEventListener 'input', () =>
        if @highlight_image
          @highlight_image.desc = desc.innerText

      shape = $('shapeselect')
      shape.addEventListener 'change', () =>
        for i in @edit_images
          i.shape = parseInt shape.value
        @redraw()

      editmark = $('editmark')
      editmark.addEventListener 'change', () =>
        name = editmark.value
        editmark.value = ''
        mark = @find_mark name
        if not mark
          mark = {name: name}
          @meta.data.marks.push mark
        mark.pos = @view.to_position(@cw2, @ch2)
        @setup_bookmarks()

      gridsize = $('gridsize')
      gridsize.addEventListener 'change', () =>
        @gridsize = parseInt gridsize.value
        @redraw()

      delbutton = $('delete')
      delbutton.addEventListener 'click', () =>
        for i in @edit_images
          idx = @images.indexOf i
          if idx < 0
            return console.log "couldn't find images: " + idx + ',' + midx
          @images.splice idx, 1
        @edit_images = []
        @redraw()

      reorder = (pos) =>
        return unless @edit_images.length == 1
        # TODO: allow reordering multiple images at once
        idx = @images.indexOf @edit_images[0]
        if idx < 0
          return console.log "couldn't find image: " + idx
        [img] = @images.splice idx, 1
        if pos == 'first'
          @images.unshift img
        else if pos == 'last'
          @images.push img
        else if pos == 'up'
          @images.splice idx-1, 0, img
        else if pos == 'down'
          @images.splice idx+1, 0, img
        @redraw()

      $('order_first').addEventListener 'click', () -> reorder 'first'
      $('order_last').addEventListener 'click', () -> reorder 'last'
      $('order_up').addEventListener 'click', () -> reorder 'up'
      $('order_down').addEventListener 'click', () -> reorder 'down'

      @redraw()
  #]]]

  find_containing_image_client: (x, y) ->
    # We don't need to subtract getBoundingClientRect().left/top because
    # we know the canvas is positioned against the top left corner of
    # the window.
    @find_containing_image_canvas x, y

  find_containing_image_canvas: (x, y) ->
    x = (x - @view.pan_x) / @view.scale
    y = (y - @view.pan_y) / @view.scale
    idx = @images.length
    while --idx >= 0
      i = @images[idx]
      if x >= i.px and y >= i.py and x <= i.px + i.pw and y <= i.py + i.ph
        xr = (x - i.px) / i.pw * 8
        yr = (y - i.py) / i.ph * 8
        xa = if xr < 1 then -1 else if xr > 7 then 1 else 0
        ya = if yr < 1 then -1 else if yr > 7 then 1 else 0
        return [i, xa, ya]
    return [null, 0, 0]

  touch_snap: (e) ->
    @view.copy_to @drag_view
    @view3.copy_to @drag_view3
    for t in e.touches
      ts = @touch_state[t.identifier] = {} unless ts = @touch_state[t.identifier]
      ts.sx = t.clientX
      ts.sy = t.clientY
    return

  interaction_normal =
    mousedown: (e) ->
      e.preventDefault()
      @stop_animation()
      @play false
      @drag_state = 1
      @drag_screen_x = e.clientX
      @drag_screen_y = e.clientY
      @view.copy_to @drag_view
      @view3.copy_to @drag_view3

    mousemove: (e) ->
      e.preventDefault()
      if @drag_state >= 1
        move_x = e.clientX - @drag_screen_x
        move_y = e.clientY - @drag_screen_y
        if Math.abs(move_x) > DRAG_THRESHOLD or Math.abs(move_y) > DRAG_THRESHOLD
          @drag_state = 2
        if @drag_state >= 2
          if @three_d
            factor = DRAG_FACTOR_3D * \
                Math.tan(@view3.fov / 2 * Math.PI / 180) / @cw2
            lat = @drag_view3.lat + factor * move_y
            @view3_t.lat = clamp lat, -89, 89
            @view3_t.lon = @drag_view3.lon - factor * move_x
            @view3_t.fov = @view3.fov
            @slide_to_3d @view3_t
          else
            @view_t.pan_x = @drag_view.pan_x + DRAG_FACTOR * move_x
            @view_t.pan_y = @drag_view.pan_y + DRAG_FACTOR * move_y
            @view_t.scale = @view.scale
            @slide_to @view_t

    mouseup: (e) ->
      e.preventDefault()
      if @drag_state == 1
        if e.button == 0 or e.button == 2
          factor = if e.button == 0 then CLICK_ZOOM_FACTOR else 1/CLICK_ZOOM_FACTOR
          if @three_d
            @do_zoom_3d factor, e.clientX, e.clientY
          else
            @do_zoom factor, e.clientX, e.clientY
        else if e.button == 1
          [i] = @find_containing_image_client e.clientX, e.clientY
          coords = @center_around_image i
          @fly_to coords if coords
      @drag_state = 0

    mousewheel: (e) ->
      e.preventDefault()
      @play false
      if e.wheelDelta
        factor = if e.wheelDelta > 0 then WHEEL_ZOOM_FACTOR else 1/WHEEL_ZOOM_FACTOR
      else
        factor = if e.detail < 0 then WHEEL_ZOOM_FACTOR else 1/WHEEL_ZOOM_FACTOR
      if @three_d
        @do_zoom_3d factor, e.clientX, e.clientY
      else
        @do_zoom factor, e.clientX, e.clientY

    touchstart: (e) ->
      e.preventDefault()
      @stop_animation()
      @play false
      @touch_snap e

    touchmove: (e) ->
      e.preventDefault()
      if e.touches.length == 1
        # Pan (using DRAG_FACTOR).
        t = e.touches[0]
        ts = @touch_state[t.identifier]
        return unless ts  # we should have gotten a touchstart for this
        move_x = t.clientX - ts.sx
        move_y = t.clientY - ts.sy
        if @three_d
          factor = DRAG_FACTOR_3D * Math.tan(@view3.fov / 2 * Math.PI / 180) / @cw2
          lat = @drag_view3.lat + factor * move_y
          @view3_t.lat = clamp lat, -89, 89
          @view3_t.lon = @drag_view3.lon - factor * move_x
          @view3_t.fov = @view3.fov
          @slide_to_3d @view3_t
        else
          @view_t.pan_x = @drag_view.pan_x + DRAG_FACTOR * move_x
          @view_t.pan_y = @drag_view.pan_y + DRAG_FACTOR * move_y
          @view_t.scale = @view.scale
          @slide_to @view_t
      else if e.touches.length == 2
        # Zoom+pan: Use the distance between the touches to calculate zoom, then
        # pan following the midpoint of the touches.
        ts0 = @touch_state[e.touches[0].identifier]
        ts1 = @touch_state[e.touches[1].identifier]
        return unless ts0 and ts1
        t0x = e.touches[0].clientX
        t0y = e.touches[0].clientY
        t1x = e.touches[1].clientX
        t1y = e.touches[1].clientY

        old_dist = (ts1.sx - ts0.sx) * (ts1.sx - ts0.sx) + \
                   (ts1.sy - ts0.sy) * (ts1.sy - ts0.sy)
        new_dist = (t1x - t0x) * (t1x - t0x) + (t1y - t0y) * (t1y - t0y)
        factor = Math.sqrt(new_dist / old_dist)

        if @three_d
          factor = factor * @drag_view3.fov / @fov_target
          @do_zoom_3d factor
        else
          factor = factor * @drag_view.scale / @scale_target
          # Do this manually instead of using @do_zoom so that we can pan
          # following the midpoint of the two touches.
          @scale_target *= factor
          @view_t.scale = @scale_target
          @view_t.pan_x = (t0x + t1x) / 2 - (
            @scale_target / @drag_view.scale * (
              (ts0.sx + ts1.sx) / 2 - @drag_view.pan_x))
          @view_t.pan_y = (t0y + t1y) / 2 - (
            @scale_target / @drag_view.scale * (
              (ts0.sy + ts1.sy) / 2 - @drag_view.pan_y))
          @slide_to @view_t
      return

    touchend: (e) ->
      e.preventDefault()
      @touch_snap e
      for t in e.changedTouches
        delete @touch_state[t.identifier]
      return

  #[[[
  interaction_edit =
    # drag states:
    #  11: left click on already selected image  (either remove or drag)
    #  12: left click on image, drag
    #  13: left click on background (unselect, then select box)
    #  2: middle click (pan)
    #  3: right click (resize)
    mousedown: (e) ->
      e.preventDefault()
      @stop_animation()
      @play false
      @drag_screen_x = e.clientX
      @drag_screen_y = e.clientY
      if e.button == 0
        @drag_base_images = (i.clone() for i in @images)
        [@drag_img, xa, ya] = @find_containing_image_client e.clientX, e.clientY
        if @drag_img
          @drag_area = [xa, ya]
          idx = @edit_images.indexOf @drag_img
          if idx < 0
            @edit_images.push @drag_img
            # Jump right into dragging state so that we don't remove this image
            # on mouseup.
            @drag_state = 12
          else
            @drag_state = 11
          # At this point, @drag_img must be in @edit_images.
        else
          @edit_images = []
          @drag_state = 13
          @drag_box =
            px: (e.clientX - @view.pan_x) / @view.scale
            py: (e.clientY - @view.pan_y) / @view.scale
            pw: 0
            ph: 0
      else if e.button == 1
        @drag_pan_x = @view.pan_x
        @drag_pan_y = @view.pan_y
        @drag_state = 2
      else if e.button == 2
        @drag_base_images = (i.clone() for i in @images)
        @drag_client_x = e.clientX
        @drag_client_y = e.clientY
        @drag_state = 3
      @redraw()

    mousemove: (e) ->
      return if @drag_state == 0
      move_x = e.clientX - @drag_screen_x
      move_y = e.clientY - @drag_screen_y

      if @drag_state == 11
        if Math.abs(move_x) > DRAG_THRESHOLD or Math.abs(move_y) > DRAG_THRESHOLD
          @drag_state = 12

      if @drag_state == 12
        unless @edit_images
          return console.log "how'd we get here with no @edit_images?"
        unless @drag_img in @edit_images
          return console.log "shouldn't @drag_img be in @edit_images?"
        orig_drag = @drag_base_images[@images.indexOf @drag_img]
        [xa, ya] = @drag_area
        aspect = @drag_img.w / @drag_img.h
        # Note: Dragging the edges only moves the edge of the clicked image.
        # Dragging the center moves all selected images. This is pretty
        # unintuitive :(
        if xa == 1  # right
          x = @snap orig_drag.px + orig_drag.pw + move_x / @view.scale
          @drag_img.scale x - orig_drag.px
        else if xa == -1  # left
          x = @snap orig_drag.px + move_x / @view.scale
          @drag_img.move x, orig_drag.py
          @drag_img.scale orig_drag.pw + orig_drag.px - x
        else if ya == 1  # bottom
          y = @snap orig_drag.py + orig_drag.ph + move_y / @view.scale
          @drag_img.scale aspect * (y - orig_drag.py)
        else if ya == -1  # top
          y = @snap orig_drag.py + move_y / @view.scale
          @drag_img.move orig_drag.px, y
          @drag_img.scale aspect * (orig_drag.ph + orig_drag.py - y)
        else  # center (this moves all selected images)
          x = orig_drag.px + move_x / @view.scale
          y = orig_drag.py + move_y / @view.scale
          snap_and_dist = (w, h) =>
            sx = @snap x + w
            sy = @snap y + h
            dx = x + w - sx
            dy = y + h - sy
            [sx - w, sy - h, dx*dx+dy*dy]
          pts = [
            snap_and_dist 0, 0
            snap_and_dist orig_drag.pw, 0
            snap_and_dist 0, orig_drag.ph
            snap_and_dist orig_drag.pw, orig_drag.ph
          ].sort (a, b) -> a[2] - b[2]
          dx = pts[0][0] - orig_drag.px
          dy = pts[0][1] - orig_drag.py

          for i in @edit_images
            oi = @drag_base_images[@images.indexOf i]
            i.move oi.px + dx, oi.py + dy

      else if @drag_state == 13  # select box
        @drag_box.pw = move_x / @view.scale
        @drag_box.ph = move_y / @view.scale
        @edit_images = (i for i in @images when rect_intersect @drag_box, i)

      else if @drag_state == 2  # pan
        @view.pan_x = @drag_pan_x + move_x
        @view.pan_y = @drag_pan_y + move_y

      else if @drag_state == 3  # resize images
        factor = Math.pow(1.005, move_x + move_y)
        cx = (@drag_client_x - @view.pan_x) / @view.scale
        cy = (@drag_client_y - @view.pan_y) / @view.scale
        for i in @edit_images
          {px, py, pw} = @drag_base_images[@images.indexOf i]
          i.move factor * (px - cx) + cx, factor * (py - cy) + cy
          i.scale pw * factor

      @redraw()

    mouseup: (e) ->
      if @drag_state == 11
        # Remove from selected set. This should always be in the set, but check
        # anyway to be defensive.
        idx = @edit_images.indexOf @drag_img
        if idx >= 0
          @edit_images.splice idx, 1
          @redraw()
      if @drag_box
        @drag_box = null
        @redraw()
      @drag_state = 0

    mousewheel: interaction_normal.mousewheel
  #]]]

  # Fly to next/previous image.
  # 1 for next, -1 for prev.
  # Returns true if this is not the last image in this direction.
  nav: (dir) ->
    if @highlight_image
      idx = @images.indexOf @highlight_image
    else
      idx = -dir

    idx += dir
    if idx >= 0 and idx < @images.length
      view1 = @center_around_image @images[idx]
      @between_views = true
      @toggle_three_d false
      @fly_to view1 if view1

    # If we can go farther in this direction, calculate that path too
    # and prefetch tiles required for it.
    idx += dir
    if idx >= 0 and idx < @images.length
      view2 = @center_around_image @images[idx]
      nextpath = compute_flying_path @cw, @ch, view1, view2
      @prefetch_path nextpath if nextpath
      return true
    return false

  next: () ->
    @play false
    @nav 1

  prev: () ->
    @play false
    @nav -1

  # Starts or stops auto-play.
  # True to start, false to stop, missing to toggle.
  play: (action) ->
    if action is undefined
      action = not @playing
    if action
      step = () => if not @nav 1 then @play false
      @playing = window.setInterval step, FLY_MS + PLAY_HOLD_MS
      $('play').src = PAUSE_ICON
      step()
    else
      window.clearInterval @playing if @playing
      @playing = null
      $('play').src = PLAY_ICON

  center_around_image: (i) ->
    return unless i
    scale = Math.min (@cw - CENTER_BORDER) / i.pw,
                     (@ch - CENTER_BORDER) / i.ph
    @view_t.scale = scale
    @view_t.pan_x = @cw2 - (i.px + i.pw / 2) * scale
    @view_t.pan_y = @ch2 - (i.py + i.ph / 2) * scale
    @view_t

  do_zoom: (factor, client_x, client_y) ->
    # We don't need to subtract getBoundingClientRect().left/top because
    # we know the canvas is positioned against the top left corner of
    # the window.
    @scale_target *= factor
    @view_t.pan_x = client_x - (
      @scale_target / @view.scale * (client_x - @view.pan_x))
    @view_t.pan_y = client_y - (
      @scale_target / @view.scale * (client_y - @view.pan_y))
    @view_t.scale = @scale_target
    @slide_to @view_t

  do_zoom_3d: (factor, client_x, client_y) ->
    # TODO: use clientxy
    fov = @fov_target / factor
    @fov_target = clamp fov, FOV_MIN, FOV_MAX
    @view3_t.fov = @fov_target
    @view3_t.lat = @view3.lat
    @view3_t.lon = @view3.lon
    @slide_to_3d @view3_t

  slide_to: (e, ms=SLIDE_MS) ->
    @scale_target = e.scale
    v = @view
    sp =
      ss: v.scale, sx: v.pan_x, sy: v.pan_y
      es: e.scale, ex: e.pan_x, ey: e.pan_y
    update = (t) ->
      t = Math.sqrt t  # start fast, end slow
      v.scale = sp.ss * (1-t) + sp.es * t
      v.pan_x = sp.sx * (1-t) + sp.ex * t
      v.pan_y = sp.sy * (1-t) + sp.ey * t
    @animate update, ms

  slide_to_3d: (e, ms=SLIDE_MS) ->
    @fov_target = e.fov
    v = @view3
    sp =
      sf: v.fov, st: v.lat, sn: v.lon
      ef: e.fov, et: e.lat, en: e.lon
    update = (t) ->
      t = Math.sqrt t  # start fast, end slow
      v.fov = sp.sf * (1-t) + sp.ef * t
      v.lat = sp.st * (1-t) + sp.et * t
      v.lon = sp.sn * (1-t) + sp.en * t
    @animate update, ms

  fly_to: (end, ms=FLY_MS) ->
    path = compute_flying_path(@cw, @ch, @view, end)
    if path
      @prefetch_path path
      update = (t) =>
        path t, @view
        @scale_target = @view.scale
      @animate update, ms
      # Set this after @animate (which resets it) so that the limit-enforcing in
      # @render doesn't mess up our nice path (which may occasionally exceed the
      # limits).
      @skip_limits = true

  stop_animation: () ->
    @animation = null
    @skip_limits = false  # reset this whenever we reset @animation

  animate: (update, ms) ->
    # Call @redraw here to ensure the draw loop is running. Then replace
    # @animation with the new one.
    @redraw()
    start = Date.now() - 5
    @animation = () ->
      t = Math.min 1, (Date.now() - start) / ms
      update t
      return t < 1
    @skip_limits = false

  toggle_three_d: (val) ->
    if val is undefined then val = not @three_d
    @three_d = val
    @c2.style.display = if @three_d then 'none' else 'block'
    @c3.style.display = if @three_d then 'block' else 'none'

  draw_background: () ->
    if not @bkgd_image?.complete
      # If we're not going to draw over everything, clear it.
      @ctx2.fillStyle = 'black'
      @ctx2.fillRect 0, 0, @cw, @ch
      return

    ctx = @ctx2
    img = @bkgd_image.dom
    r = Math.floor log @view.scale, BKGD_SCALEFACTOR

    scales = for p in [0, 1]
      Math.pow(BKGD_SCALEFACTOR, r + p)

    weights = for s in scales
      ratio = log s / @view.scale, BKGD_SCALEFACTOR
      Math.max 0, 1 - Math.pow(ratio, 2)

    alphas = [1, weights[1] / (weights[0] + weights[1])]

    for s in scales
      ctx.globalAlpha = alphas.shift()
      sz = img.naturalWidth * @view.scale / s
      sx = ((@view.pan_x % sz) + sz) % sz
      sy = ((@view.pan_y % sz) + sz) % sz
      for c in [-1..@cw/sz]
        for r in [-1..@ch/sz]
          ctx.drawImage img, sx + c * sz, sy + r * sz, sz, sz

    ctx.globalAlpha = 1

  update_highlight_image: () ->
    # must be over center point of canvas
    [i] = @find_containing_image_canvas @cw2, @ch2
    # and must be at least half the width or height
    if i
      if i.pw * @view.scale / @cw < 0.5 and i.ph * @view.scale / @ch < 0.5
        i = null
    # update description
    desc = (i?.desc or '').replace /\n$/, ''
    set_text 'desc', desc
    $('desc').style.lineHeight = if desc.search('\n') > 0 then 1.1 else 2.2
    @highlight_image = i
    # also check if we're inside it to set the pano image
    if (i and i.pano and
        i.px * @view.scale + @view.pan_x < 0 and
        (i.px + i.pw) * @view.scale + @view.pan_x > @cw and
        i.py * @view.scale + @view.pan_y < 0 and
        (i.py + i.ph) * @view.scale + @view.pan_y > @ch)
      @pano_image = i
    else
      @pano_image = null

  #[[[
  update_fps: () ->
    now = Date.now()
    ms = now - @last_now
    return if ms <= 0
    @fps = (1000 / ms + @fps * 9) / 10
    set_text 'fps', @fps.toFixed 0
    @last_now = now
    set_text 'tiles', ImageLoader.stats()
    pos = @view.to_position @cw2, @ch2
    set_text 'px', pos.px.toPrecision 5
    set_text 'py', pos.py.toPrecision 5
    set_text 'pr', pos.r.toPrecision 5
    v3 = @view3.lat.toFixed 0
    v3 += '/' + @view3.lon.toFixed 0
    v3 += '/' + @view3.fov.toFixed 0
    set_text 'v3', v3

  snap: (x) ->
    if @gridsize then @gridsize * Math.round x / @gridsize else x

  draw_grid: () ->
    ctx = @ctx2
    ctx.beginPath()
    x = @snap -@view.pan_x / @view.scale
    y = @snap -@view.pan_y / @view.scale
    end_x = (@cw - @view.pan_x) / @view.scale
    end_y = (@ch - @view.pan_y) / @view.scale
    while x < end_x
      dx = 0.5 + Math.floor x * @view.scale + @view.pan_x
      ctx.moveTo dx, 0
      ctx.lineTo dx, @ch
      x += @gridsize
    while y < end_y
      dy = 0.5 + Math.floor y * @view.scale + @view.pan_y
      ctx.moveTo 0, dy
      ctx.lineTo @cw, dy
      y += @gridsize
    ctx.lineWidth = 1
    ctx.strokeStyle = 'hsl(210,5%,25%)'
    ctx.stroke()

  draw_drag_box: () ->
    ctx = @ctx2
    x = @drag_box.px * @view.scale + @view.pan_x
    y = @drag_box.py * @view.scale + @view.pan_y
    w = @drag_box.pw * @view.scale
    h = @drag_box.ph * @view.scale
    ctx.lineWidth = 3
    ctx.strokeStyle = 'rgba(0,0,200,0.5)'
    ctx.strokeRect x, y, w, h
  #]]]

  draw_images: (really, view, redraw) ->
    max_ratio = 0
    ctx = @ctx2

    if really
      ctx.strokeStyle = 'hsl(210,5%,5%)'
      ctx.shadowColor = 'hsl(210,5%,15%)'

    for i in @images
      x = i.px * view.scale + view.pan_x
      y = i.py * view.scale + view.pan_y
      w = i.pw * view.scale
      h = i.ph * view.scale

      fw = Math.sqrt(w * h) * FRAME_WIDTH

      continue if rect_is_outside @cw, @ch, x-fw, y-fw, w+3*fw, h+3*fw

      max_ratio = Math.max max_ratio, i.w / w

      if really
        ctx.save()

        ctx.lineWidth = 2 * fw
        if i is @highlight_image
          ctx.shadowOffsetX = ctx.shadowOffsetY = fw
        if @edit_mode and i in @edit_images
          ctx.strokeStyle = 'hsl(30,50%,50%)'
          ctx.lineWidth *= 2

        ctx.beginPath()
        switch i.shape or RECT
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

      draw_ctx = if really then ctx else null
      i.render_onto_ctx draw_ctx, @tile_cache, x, y, w, h, redraw

      if really
        ctx.restore()

    max_ratio

  #[[[
  draw_links: () ->
    ctx = @ctx2
    ctx.lineWidth = 3
    ctx.strokeStyle = 'rgba(0,200,0,0.5)'
    ctx.beginPath()
    for i in @images
      x = (i.px + i.pw/2) * @view.scale + @view.pan_x
      y = (i.py + i.ph/2) * @view.scale + @view.pan_y
      if i is @images[0]
        ctx.moveTo x, y
      else
        ctx.lineTo x, y
    ctx.stroke()

  set_ratio_text: (max_ratio) ->
    if max_ratio == 0
      set_text 'ratio', ''
    else if max_ratio < 1
      set_text 'ratio', '1\u2236' + (1 / max_ratio).toFixed 1
    else
      set_text 'ratio', max_ratio.toFixed 1
  #]]]

  prefetch_path: (path) ->
    for t in [0..5]
      @draw_images false, path(t/5, @view_t), null

  point_camera: (view) ->
    asp = @cw/@ch
    @t_camera.projectionMatrix.makePerspective view.fov/asp, asp, 1, 10000
    phi = (90 - view.lat) * Math.PI / 180
    theta = (view.lon + 90) * Math.PI / 180
    t = @t_target
    t.x = 50 * Math.sin(phi) * Math.cos(theta)
    t.y = 50 * Math.cos(phi)
    t.z = 50 * Math.sin(phi) * Math.sin(theta)
    @t_camera.lookAt t

  render: () ->
    @request_id = null
    #[[[
    @update_fps()
    #]]]

    if @three_d
      if @t_scene
        # Render what we have now.
        @point_camera @view3
        @t_renderer.render @t_scene, @t_camera

        # For the next frame, adjust tile level based on fov.
        bias = 0
        proj_h = @t_pano.ts / 2 * Math.tan(@view3.fov * Math.PI / 180 / 2)
        level = Math.floor log2(@ch / proj_h) + bias
        level = clamp level, 0, @t_pano.levels - 1
        #[[[
        set_text 'level', level
        #]]]
        for i in [0...@t_pano.levels]
          vis = if PANO_DRAW_LOWER_LEVELS then i <= level else i == level
          @t_meshes[i].visible = vis

        # Project to figure out what's visible, then fetch those tiles.
        data = @t_projector.projectScene @t_scene, @t_camera, false, false, true
        for e in data.elements
          continue unless e instanceof THREE.RenderableFace4
          unless is_off_screen e
            e.material._ocicle_loader.load()

      switch_views = @view3.fov > FOV_OUT

    else
      @draw_background()
      @update_highlight_image()
      #[[[
      if @edit_mode and @gridsize then @draw_grid()
      #]]]

      max_ratio = @draw_images true, @view, @redraw

      #[[[
      if @edit_mode
        @draw_links()
        if @drag_box then @draw_drag_box()

      @set_ratio_text max_ratio
      #]]]

      switch_views = @pano_image

    if switch_views
      if not @between_views
        @between_views = true
        @toggle_three_d()
        if @three_d
          pano = @pano_image.pano
          @setup_pano pano
          @view3.fov = @fov_target = FOV_OUT
          @view3.lat = pano.lat
          @view3.lon = pano.lon
          @do_zoom_3d @fov_target / pano.fov
        else
          coords = @center_around_image @pano_image
          @slide_to coords if coords
    else
      @between_views = false

      # handle 2d limit stuff
      unless @skip_limits
        if max_ratio > 0 and max_ratio < 1 / ZOOM_LIMIT_LIMIT
          @scale_target = @view.scale
          @do_zoom max_ratio * ZOOM_LIMIT_TARGET, @cw2, @ch2
        else if @view.scale < UNZOOM_LIMIT
          @scale_target = @view.scale
          @do_zoom 1.05, @cw2, @ch2

  draw_loop: () =>
    more = @animation?()
    if not more
      @animation = null
      @skip_limits = false
    @render()
    if @animation
      requestFrame @draw_loop

  redraw: () =>
    # If @animation is true, there's already a pending frame request, so do
    # nothing. Otherwise, start one with a dummy animation.
    if not @animation
      @animation = () -> false
      @skip_limits = false
      requestFrame @draw_loop

  resize: () ->
    @setup_contexts()
    @redraw()


on_resize = () ->
  bb = $('bottombar')
  descbar = $('descbar')
  desc = $('desc')
  bs = $('bottomstuff')
  mb = $('mainbox')
  if bb.clientWidth > 700
    descbar.style.display = 'none'
    bb.appendChild desc if desc.parentElement != bb
    desc.style.width = bb.clientWidth - bs.clientWidth - 16
    mb.style.height = mb.parentElement.clientHeight - bb.clientHeight
  else
    descbar.style.display = 'block'
    descbar.appendChild desc if desc.parentElement != descbar
    desc.style.width = '100%'
    mb.style.height = \
      mb.parentElement.clientHeight - bb.clientHeight - descbar.clientHeight
  if window.ocicle then window.ocicle.resize()

on_load = () ->
  new ImageLoader PAUSE_ICON   # prefetch this so it's cached
  if MOBILE
    $('fstoggle').style.display = 'none'
  else
    bkgd_image = new ImageLoader BKGD_IMAGE
  on_resize()
  meta = new Metadata window.META, '/data/meta.js'
  delete window.META
  window.ocicle = new Ocicle $('c2'), $('c3'), meta, bkgd_image

window.addEventListener 'resize', on_resize, false
window.addEventListener 'load', on_load, false
