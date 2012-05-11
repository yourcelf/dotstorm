express     = require 'express'
socketio    = require 'socket.io'
RedisStore  = require('connect-redis')(express)
Backbone    = require 'backbone'
logger      = require './logging'
Database    = require './backbone-mongo'
thumbnails  = require './ideacanvas2image'

# See Cakefile for options definitions and defaults
start = (options) ->
  sessionStore = new RedisStore

  db = null
  Database.open options,success: (database) -> db = database

  app = express.createServer()
  
  #
  # Config
  #
  app.logger = logger # debug/dev logging
  app.configure ->
    app.use require('connect-assets')()
    #app.use express.logger()
    app.use express.bodyParser()
    app.use express.cookieParser()
    app.use express.session
      secret: options.secret
      key: 'express.sid'
      store: sessionStore

  app.configure 'development', ->
    app.use express.static __dirname + '/../assets'
    app.use express.errorHandler { dumpExceptions: true, showStack: true }
    app.get '/test', (req, res) ->
      res.render 'test', layout: false

  app.configure 'production', ->
    app.use express.static __dirname + '/../assets', { maxAge: 1000*60*60*24 }

  app.set 'view engine', 'jade'

  app.get '/', (req, res) ->
    res.render 'dotstorm', title: "DotStorm", slug: "", initial: {}

  # /d/:slug/:action
  app.get /\/d\/([^/]+)(\/.*)?/, (req, res) ->
    #XXX load initial data when a slug is given....
    res.render 'dotstorm', title: "DotStorm", slug: req.params[0], initial: {}

  require('./auth').route(app, options.host)

  app.listen options.port

  # Socket sessions
  io = socketio.listen(app)
  io.set 'log level', 0

  # binds to '/io'
  channel = '/io'
  require('./iorooms.server').attach(channel, io, sessionStore)
  require('./backbone-socket.server').attach(channel, io)
  require('./imageupload').attach(channel, io)
  roomserver = io.of(channel)

  #
  # Events from backbone->mongo:
  #
  Backbone.sync.on "backbone:error", (socket, signature, model, error) ->
    socket.emit signature.event, {error: error}

  Backbone.sync.on "backbone", (socket, signature, model) ->
    respond = ->
      json = model.toJSON()
      if signature.collectionName == "Idea" and signature.method != "read"
        delete json.drawing
      socket.emit signature.event, json
    rebroadcast = (room_name) ->
      # Only works for models, not collections.
      logger.debug "rebroadcast #{room_name}", model.toJSON()
      if room_name?
        socket.broadcast.to(room_name).emit "backbone", { signature, model: model.toJSON() }
    errorOut = (error) -> socket.emit signature.event, error: error
    switch signature.collectionName
      when "Idea"
        switch signature.method
          when "create"
            thumbnails.drawingThumbs model, (err) ->
              if err?
                errorOut(err)
              else
                respond()
                rebroadcast(model.get "dotstorm_id")
          when "update"
            thumbnails.drawingThumbs model, (err) ->
              if err?
                errorOut(err)
              else
                respond()
                rebroadcast(model.get "dotstorm_id")
          when "delete"
            thumbnails.remove model, (err) ->
              if err?
                errorOut(err)
              else
                respond()
                rebroadcast(model.get "dotstorm_id")
          when "read" then respond()
      when "Dotstorm"
        switch signature.method
          when "create"
            respond()
          when "update"
            respond()
            rebroadcast(model.id)
          when "delete"
            respond()
          when "read"
            respond()

  return { app, io, sessionStore, getDb: (-> db) }

module.exports = { start }
