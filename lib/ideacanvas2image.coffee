Canvas = require 'canvas'
fs     = require 'fs'
path   = require 'path'
logger = require './logging'

BASE_PATH = __dirname + "/.."

sizes =
  # Sizes allow for 1px border, and fit well on mobile screens (240px, 480px)
  small: [78, 78]
  medium: [138, 138]
  large: [238, 238]
  full: [400, 400]

mkdirs = (dir, mode, callback) ->
  # Make the directory, and any parent directories needed.
  fs.stat dir, (err, stats) ->
    if err?
      if err.code == "ENOENT"
        # Dir doesn't exist.  Walk up the tree.
        mkdirs dir.split("/").slice(0, -1).join("/"), (err) ->
          if err? then return callback?(err)
          fs.mkdir dir, mode, (err) ->
            if err? then return callback?(err)
            return callback(null)
      else
        return callback?(err)
    else
      if stats.isDirectory()
        return callback?(null)
      return callback?(err)

clearDir = (dir, callback) ->
  mkdirs dir, "0775", (err) ->
    if err then return callback?(err)
    fs.readdir dir, (err, files) ->
      if err then return callback?(err)
      numFiles = files.length
      for file in files
        fs.unlink file, (err) ->
          if err then return callback?(err)
          numFiles -= 1
          if numFiles == 0 then callback?(null)

getThumbnailDims = (origx, origy, maxx, maxy) ->
  aspect = origx / origy
  if aspect > 1
    return [maxx, maxy * aspect]
  return [maxx * aspect, maxy]

canvas2thumbnails = (canvas, thumbnails, callback) ->
  img = canvas.toBuffer (err, buf) ->
    if err then return callback?(err)
    count = thumbnails.length
    for dest, maxDims in thumbnails
      dims = getThumbnailDims(canvas.width, canvas.height, maxDims[0], maxDims[1])
      thumb = new Canvas(dims[0], dims[1])
      img = new Canvas.Image
      img.src = buf
      thumb.drawImage(img, 0, 0, dims[0], dims[1])
      out = fs.createWriteStream __dirname + dest
      stream = thumb.createPNGStream()
      stream.on 'data', (chunk) -> out.write chunk
      stream.on 'end', ->
        count -= 1
        if count == 0 then callback?(null)

draw = (idea, callback) ->
  dims = idea.get("dims")
  canvas = new Canvas dims.x, dims.y
  ctx = canvas.getContext('2d')
  ctx.fillStyle idea.get("background")
  ctx.beginPath()
  ctx.fillRect 0, 0, dims.x, dims.y
  ctx.fill()

  ctx.lineCap = 'round'

  lastTool = null
  for [tool, x1, y1, x2, y2] in idea.get("drawing")
    if tool != lastTool
      switch tool
        when "pencil"
          ctx.lineWidth = 8
          ctx.strokeStyle = '#000000'
        when "eraser"
          ctx.lineWidth = 32
          ctx.strokeStyle = idea.get("background")
      lastTool = tool

    ctx.beginPath()
    if x1?
      ctx.moveTo x1, y1
    else
      ctx.moveTo x2, y2
    ctx.lineTo x2, y2
    ctx.stroke()
  thumbs = []
  for name, size of sizes
    thumb = [BASE_PATH + idea.getThumbnailURL(name)]
    thumb.push(size[0])
    thumb.push(size[1])
    thumbs.push(thumb)
  canvas2thumbnails canvas, thumbs, (err) ->
    if (err) then return callback?(err)
    return callback?(null)

mkthumb = (idea, callback) ->
  clearDir BASE_PATH + path.dirname(idea.getThumbnailURL('small')), (err) ->
    if (err) then return callback?(err)
    draw idea, (err, canvas) ->
      if (err) then return callback?(err)


Backbone.sync.on "save:Idea", mkthumbs
Backbone.sync.on "update:Idea", mkthumbs
