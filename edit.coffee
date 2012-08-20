
PADDING = 150


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


class DZImage
  constructor: (dz) ->
    @name = dz.name
    @w = dz.w
    @h = dz.h
    @tile_size = dz.ts
    @pos = new ImagePosition @w, @h

  render_onto_ctx: (ctx, tile_cache, x, y, w, h) ->
    # FIXME: fix aspect ratio
    draw = () -> ctx.drawImage @, x, y, w, h
    src = @get_at_level 7, 0, 0
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

  get_at_level: (level, x, y) ->
    return @name + '/' + level + '/' + x + '_' + y + '.jpg'


class Ocicle
  constructor: (@c) ->
    @c.addEventListener 'mousedown', @on_mousedown, true
    @c.addEventListener 'contextmenu', @on_mousedown, true
    @c.addEventListener 'mousemove', @on_mousemove, true
    @c.addEventListener 'mouseup', @on_mouseup, true
    @c.addEventListener 'mouseout', @on_mouseup, true

    @tile_cache = new LruCache 100
    @images = (new DZImage dz for dz in IMAGES)
    @reset()

  reset: () ->
    @layout_images @c.parentElement.clientWidth, @c.parentElement.clientHeight

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

  find_containing_image: (x, y) ->
    @images.reverse()
    for i in @images
      if x >= i.pos.x and y >= i.pos.y and x <= i.pos.x + i.pos.w and y <= i.pos.y + i.pos.h
        @images.reverse()
        return i
    @images.reverse()
    undefined

  on_mousedown: (e) =>
    if e.button == 0 or e.button == 2
      e.preventDefault()
      rect = @c.getBoundingClientRect()
      x = e.clientX - rect.left
      y = e.clientY - rect.top
      @drag_img = @find_containing_image x, y
      if @drag_img
        @images.splice (@images.indexOf @drag_img), 1
        @images.push @drag_img
        @drag_state = e.button / 2 + 1
        @drag_screen_x = e.screenX
        @drag_screen_y = e.screenY
        @drag_base_x = @drag_img.pos.base_x
        @drag_base_y = @drag_img.pos.base_y
        @drag_req_w = @drag_img.pos.req_w
        @drag_req_h = @drag_img.pos.req_h

  on_mousemove: (e) =>
    if @drag_state == 1
      move_x = e.screenX - @drag_screen_x
      move_y = e.screenY - @drag_screen_y
      @drag_img.pos.move @drag_base_x + move_x, @drag_base_y + move_y
      @render()
    else if @drag_state == 2
      factor = Math.pow(1.01, e.screenY - @drag_screen_y)
      @drag_img.pos.resize @drag_req_w * factor, @drag_req_h * factor
      cx = @drag_base_x + (@drag_req_w - @drag_img.pos.req_w) / 2
      cy = @drag_base_y + (@drag_req_h - @drag_img.pos.req_h) / 2
      @drag_img.pos.move cx, cy
      @render()

  on_mouseup: (e) =>
    @drag_state = 0

  on_resize: () ->
    @render()

  render: () ->
    cw = @c.parentElement.clientWidth
    if @c.width < cw then @c.width = cw
    ch = @c.parentElement.clientHeight
    if @c.height < ch then @c.height = ch

    ctx = @c.getContext '2d'
    ctx.clearRect 0, 0, cw, ch
    ctx.strokeStyle = '#222'  # for image frames
    ctx.lineWidth = 1
    t = []
    for i in @images
      x = i.pos.x
      y = i.pos.y
      w = i.pos.w
      h = i.pos.h
      t.push({name:i.name,x:x,y:y,w:w,h:h})
      ctx.strokeRect x, y, w, h
      i.render_onto_ctx ctx, @tile_cache, x, y, w, h
    document.getElementById('console').value = JSON.stringify t


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

