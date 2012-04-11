Backbone = require 'backbone'
Canvas   = require 'canvas'
fs       = require 'fs'
path     = require 'path'
logger   = require './logging'

BASE_PATH = __dirname + "/../static"

sizes =
  # Sizes allow for 1px border, and fit well on mobile screens (240px, 480px)
  small: [78, 78]
  medium: [138, 138]
  large: [238, 238]
  full: [640, 640]

mkdirs = (dir, mode, callback) ->
  # Make the directory, and any parent directories needed.
  fs.stat dir, (err, stats) ->
    if err?
      if err.code == "ENOENT"
        # Dir doesn't exist.  Walk up the tree.
        mkdirs dir.split("/").slice(0, -1).join("/"), mode, (err) ->
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
  # Remove everything in the given directory.
  mkdirs dir, "0775", (err) ->
    if err then return callback?(err)
    fs.readdir dir, (err, files) ->
      if err then return callback?(err)
      numFiles = files.length
      if numFiles == 0
        callback?(null)
      else
        for file in files
          fs.unlink "#{dir}/#{file}", (err) ->
            if err then return callback?(err)
            numFiles -= 1
            if numFiles == 0 then callback?(null)

getThumbnailDims = (origx, origy, maxx, maxy) ->
  # Get the maximum dimensions that fit in maxx, maxy while preserving aspect
  # ratio.
  aspect = origx / origy
  if aspect > 1
    return [maxx, maxy / aspect]
  return [maxx * aspect, maxy]

canvas2thumbnails = (canvas, thumbnails, callback) ->
  # Given a canvas and an array of thumbnail definitions in the form:
  #   [[ <destination_path>, <maxx>, <maxy> ]]
  # create thumbnail files on disk.
  img = canvas.toBuffer (err, buf) ->
    if err then return callback?(err)
    count = thumbnails.length
    for data in thumbnails
      do (data) ->
        [dest, maxx, maxy] = data
        dims = getThumbnailDims(canvas.width, canvas.height, maxx, maxy)
        thumb = new Canvas(dims[0], dims[1])
        img = new Canvas.Image
        img.src = buf
        ctx = thumb.getContext('2d')
        ctx.drawImage(img, 0, 0, dims[0], dims[1])
        logger.debug "Writing file #{dest}"
        out = fs.createWriteStream dest
        stream = thumb.createPNGStream()
        stream.on 'data', (chunk) ->
          out.write chunk
        stream.on 'end', ->
          count -= 1
          if count == 0
            callback?(null)

draw = (idea, callback) ->
  # Render the drawing instructions contained in the idea to a canvas.
  dims = idea.get("dims")
  canvas = new Canvas dims.x, dims.y
  ctx = canvas.getContext('2d')
  ctx.fillStyle = idea.get("background")
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

mkthumbs = (idea, callback) ->
  # Create thumbnail images for the given idea.
  if idea.get("background")? and idea.get("drawing")?
    clearDir BASE_PATH + path.dirname(idea.getThumbnailURL('small')), (err) ->
      if (err) then return callback?(err)
      draw idea, (err) ->
        if (err) then return callback?(err)
        callback(null)
  else
    logger.debug("skipping thumbnail; empty model")

#checkMkThumbs = (model) ->
#  if model.get("background")? and model.get("drawing")?
#    mkthumbs model, (err) ->
#      if err then logger.error(err)
#      logger.debug("successfully made thumbs for #{model.id}")
#      Backbone.sync.emit "images:Idea",
#        dotstorm_id: model.get("dotstorm_id")
#        imageVersion: model.get("imageVersion")
#        _id: model.id
#  else

remove = (model) ->
  dir = BASE_PATH + path.dirname(model.getThumbnailURL('small'))
  logger.debug "removing #{dir} and all contents"
  clearDir dir, (err) ->
    if (err) then logger.error(err)
    fs.rmdir dir, (err) ->
      if (err) then logger.error(err)

module.exports = { mkthumbs, remove }
