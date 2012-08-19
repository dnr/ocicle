
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

SLIDE_W = 2500
SLIDE_H = 2500

is_child = (parent, child) ->
  while child and child != parent
    child = child.parentNode
  return child == parent

class Img
  LOADING = 0
  READY = 1
  ERROR = 2

  constructor: (@src) ->
    @dom = document.createElement 'img'
    @dom.style.position = 'absolute'
    @dom.src = src
    @dom.onload = () => @on_load true
    @dom.onerror = @dom.onabort = () => @on_load false
    @state = LOADING
    @x = @y = 0
    @nat_w = @nat_h = 100
    @req_w = @req_h = 100
    @w = @h = 100

  on_load: (success) ->
    if success
      @nat_w = @dom.naturalWidth
      @nat_h = @dom.naturalHeight
      @state = READY
      @update_dom()
    else
      @state = ERROR

  update_dom: () ->
    if @state == READY
      ratio = Math.min(@req_w / @nat_w, @req_h / @nat_h)
      @w = @nat_w * ratio
      @h = @nat_h * ratio
      w_offset = (@req_w - @w) / 2
      h_offset = (@req_h - @h) / 2

      @dom.style.width = @w
      @dom.style.height = @h
      @dom.style.top = @y + h_offset
      @dom.style.left = @x + w_offset
      @dom.style.display = ''
    else
      @dom.style.display = 'none'

  move: (@x, @y) ->
    @update_dom()

  resize: (@req_w, @req_h) ->
    @update_dom()



class Ocicle
  constructor: (@c) ->
    @c.style.overflow = 'hidden'

    @slide_x = 0
    @slide_y = 0
    @slide = document.createElement 'div'
    @slide.className = 'slide'
    @slide.style.position = 'relative'
    @slide.style.left = @slide_x
    @slide.style.top = @slide_y
    @slide.style.width = SLIDE_W
    @slide.style.height = SLIDE_H
    @c.appendChild @slide

    @images = @load_images IMAGEDIR, IMAGES
    @layout_images SLIDE_W, SLIDE_H
    @slide.appendChild image.dom for image in @images

    @dragstate = 0
    @drag_screen_x = 0
    @drag_screen_y = 0
    @drag_slide_x = 0
    @drag_slide_y = 0
    @c.addEventListener 'mousedown', @on_mousedown, true
    @c.addEventListener 'mousemove', @on_mousemove, true
    @c.addEventListener 'mouseup', @on_mouseup, true
    @c.addEventListener 'mouseout', @on_mouseup, true

  load_images: (prefix, images) ->
    new Img (prefix + '/' + image) for image in images

  layout_images: (totalw, totalh) ->
    padding = 8

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

    false

  on_resize: () ->
    @layout_images()
    image.update_dom() for image in @images

  on_mousedown: (e) =>
    if e.button == 0
      e.preventDefault()
      @dragstate = 1
      @drag_screen_x = e.screenX
      @drag_screen_y = e.screenY
      @drag_slide_x = @slide_x
      @drag_slide_y = @slide_y

  on_mousemove: (e) =>
    if @dragstate
      @slide_target_x = @drag_slide_x + 2 * (e.screenX - @drag_screen_x)
      @slide_target_y = @drag_slide_y + 2 * (e.screenY - @drag_screen_y)
      @animate 500, 30

  on_mouseup: (e) =>
    if e.relatedTarget and is_child @c, e.relatedTarget
      return
    @dragstate = 0

  animate: (ms, steps) ->
    if @timeoutid
      window.clearTimeout @timeoutid

    fn = (orig_x, orig_y, start) =>
      t = Math.min 1, (Date.now() - start) / ms
      t = Math.pow t, 0.5
      @slide_x = orig_x * (1-t) + @slide_target_x * t
      @slide_y = orig_y * (1-t) + @slide_target_y * t
      @slide.style.left = @slide_x
      @slide.style.top = @slide_y
      if t < 1
        @timeoutid = window.setTimeout fn, ms/steps, orig_x, orig_y, start
      else
        @timeoutid = null
    @timeoutid = window.setTimeout fn, 0, @slide_x, @slide_y, Date.now()



log = (l) ->
  c = document.getElementById 'console'
  c.innerText = l

on_load = () ->
  window.ocicle = new Ocicle document.getElementById "c"
on_resize = () ->
  if window.ocicle then window.ocicle.on_resize()

window.addEventListener 'load', on_load, false
window.addEventListener 'resize', on_resize, false

