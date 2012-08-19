
IMAGES = [
  'p1030318_flat.jpg'
  'p1030340_flat.jpg'
  'p1030345_flat.jpg'
  'p1030350_flat.jpg'
  'p1030376_flat.jpg'
  'p1030410_flat.jpg'
  'p1030420_flat.jpg'
  'p1030435_flat.jpg'
  'p1030440_flat.jpg'
  'p1030455_flat.jpg'
  'p1030465_flat.jpg'
  'p1030485_flat.jpg'
  'p1030490_flat.jpg'
  'p1030510_flat.jpg'
  'p1030551b_flat.jpg'
  'p1030556_flat.jpg'
  'p1030561_flat.jpg'
]
IMAGEDIR = 'images'
PADDING = 150
DRAG_FACTOR = 2
DRAG_THRESHOLD = 3

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

is_child = (parent, child) ->
  while child and child != parent
    child = child.parentNode
  return child == parent

class Image
  LOADING = 0
  READY = 1
  ERROR = 2

  constructor: (@src, @on_ready) ->
    @dom = document.createElement 'img'
    @dom.src = src
    @dom.onload = () => @on_load true
    @dom.onerror = @dom.onabort = () => @on_load false
    @state = LOADING
    @base_x = @base_y = 0
    @nat_w = @nat_h = 100
    @req_w = @req_h = 100
    @w = @h = 100

  ready: () -> @state == READY

  on_load: (success) ->
    if success
      @nat_w = @dom.naturalWidth
      @nat_h = @dom.naturalHeight
      @state = READY
      @update()
      @on_ready()
    else
      @state = ERROR

  update: () ->
    if @ready()
      ratio = Math.min(@req_w / @nat_w, @req_h / @nat_h)
      @w = @nat_w * ratio
      @h = @nat_h * ratio
      @x = @base_x + (@req_w - @w) / 2
      @y = @base_y + (@req_h - @h) / 2

  move: (@base_x, @base_y) -> @update()
  resize: (@req_w, @req_h) -> @update()



class Ocicle
  constructor: (@c) ->
    @images = @load_images IMAGEDIR, IMAGES
    @reset()
    @layout_images 2000, 2000

    @drag_state = 0
    @drag_screen_x = 0
    @drag_screen_y = 0
    @drag_slide_x = 0
    @drag_slide_y = 0

    @c.addEventListener 'mousedown', @on_mousedown, true
    @c.addEventListener 'contextmenu', @on_mousedown, true
    @c.addEventListener 'mousemove', @on_mousemove, true
    @c.addEventListener 'mouseup', @on_mouseup, true
    @c.addEventListener 'mouseout', @on_mouseup, true

  set_slide_x: (@slide_x) =>
  set_slide_y: (@slide_y) =>
  set_slide_size: (@slide_size) =>

  reset: () ->
    @stop_animation()
    @set_slide_x 0
    @set_slide_y 0
    @set_slide_size 1.0
    @render()

  load_images: (prefix, images) ->
    new Image (prefix + '/' + image), @render for image in images

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
        @images[i].move (c-1+even/2) * boxw + padding, (r-1) * boxh + padding
        @images[i].resize imgw, imgh
        i += 1

    @render()

  on_mousedown: (e) =>
    if e.button == 0 or e.button == 2
      e.preventDefault()
      @stop_animation()
      @drag_state = 1
      @drag_screen_x = e.screenX
      @drag_screen_y = e.screenY
      @drag_slide_x = @slide_x
      @drag_slide_y = @slide_y

  on_mousemove: (e) =>
    if @drag_state >= 1
      move_x = e.screenX - @drag_screen_x
      move_y = e.screenY - @drag_screen_y
      if Math.abs(move_x) > DRAG_THRESHOLD or Math.abs(move_y) > DRAG_THRESHOLD
        @drag_state = 2
      if @drag_state >= 2
        x =
          start: @slide_x
          end: @drag_slide_x + DRAG_FACTOR * move_x
          set: @set_slide_x
        y =
          start: @slide_y
          end: @drag_slide_y + DRAG_FACTOR * move_y
          set: @set_slide_y
        @animate [x, y], 500

  on_mouseup: (e) =>
    if e.relatedTarget and is_child @c, e.relatedTarget
      return
    if @drag_state == 1
      e.preventDefault()
      @do_zoom (if e.button == 0 then 2 else 1/2), e.clientX, e.clientY
    @drag_state = 0

  do_zoom: (factor, clientx, clienty) =>
    bounds = @c.getBoundingClientRect()
    center_x = clientx - bounds.left - @c.clientLeft + @c.scrollLeft
    center_y = clienty - bounds.top - @c.clientTop + @c.scrollTop

    size =
      start: @slide_size
      end: factor * @slide_size
      set: @set_slide_size
    x =
      start: @slide_x
      end: center_x - factor * (center_x - @slide_x)
      set: @set_slide_x
    y =
      start: @slide_y
      end: center_y - factor * (center_y - @slide_y)
      set: @set_slide_y
    @animate [size, x, y], 500

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

  all_ready: () ->
    for image in @images
      if not image.ready()
        return false
    return true

  render: () =>
    if not @all_ready()
      return
    cw = @c.width = @c.parentElement.clientWidth + 100
    ch = @c.height = @c.parentElement.clientHeight + 100
    ctx = @c.getContext '2d'
    ctx.translate @slide_x, @slide_y
    ctx.scale @slide_size, @slide_size
    ctx.strokeStyle = '#222'
    for i in @images
      ctx.strokeRect i.x, i.y, i.w, i.h
      ctx.drawImage i.dom, i.x, i.y, i.w, i.h
    false




log = (l) ->
  c = document.getElementById 'console'
  c.innerText = l

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

