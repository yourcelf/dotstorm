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
    app.use express.static __dirname + '/../static'
    app.use express.errorHandler { dumpExceptions: true, showStack: true }
    app.get '/test', (req, res) ->
      res.render 'test', layout: false
    app.get '/argh', (req, res) ->
      res.render 'argh', layout: false

  app.configure 'production', ->
    app.use express.static __dirname + '/../static', { maxAge: 1000*60*60*24 }

  app.set 'view engine', 'jade'

  app.get '/', (req, res) ->
    res.render 'index', title: "DotStorm", initial: {}

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
  roomserver = io.of(channel)
  #
  # Events from backbone->mongo:
  #
  Backbone.sync.on "backbone:error", (socket, signature, model, error) ->
    socket.emit signature.event, {error: error}

  Backbone.sync.on "backbone", (socket, signature, model) ->
    respond = -> socket.emit signature.event, model.toJSON()
    rebroadcast = ->
      # Only works for models, not collections.
      socket.broadcast.to(model.dotstorm_id).emit "backbone", { signature, model: model.toJSON() }
    errorOut = (error) -> socket.emit signature.event, error: error
    switch signature.collectionName
      when "Idea"
        switch signature.method
          when "create"
            thumbnails.mkthumbs model, (err) ->
              if err?
                errorOut(err)
              else
                respond()
                rebroadcast()
          when "update"
            thumbnails.mkthumbs model, (err) ->
              if err?
                errorOut(err)
              else
                respond()
                rebroadcast()
          when "delete"
            thumbnails.remove model, (err) ->
              if err?
                errorOut(err)
              else
                respond()
                rebroadcast()
          when "read" then respond()
      when "IdeaGroup"
        switch signature.method
          when "create"
            respond()
            rebroadcast()
          when "update"
            respond()
            rebroadcast()
          when "delete"
            respond()
            rebroadcast()
          when "read"
            respond()
      when "Dotstorm"
        switch signature.method
          when "create"
            respond()
          when "update"
            respond()
            rebroadcast()
          when "delete"
            respond()
          when "read"
            respond()

#  socketListeners = {}
#  roomserver.on 'connection', (socket) ->
#    if socketListeners[socket.id]?
#      for [key, listener] in socketListeners[socket.id]
#        Backbone.sync.removeListener(key, listener)
#    socketListeners[socket.id] = []
#
#    rebroadcast = (key) ->
#      listener = (data) ->
#        # broadcast image updates to everyone.
#        logger.debug "#{socket.id} rebroadcast #{key}"
#        socket.broadcast.to(data.dotstorm_id).emit key, data
#      Backbone.sync.on key, listener
#      socketListeners[socket.id].push([key, listener])
#
#    rebroadcast "after:update:Idea"
#    rebroadcast "after:create:Idea"
#    rebroadcast "after:delete:Idea"
#    rebroadcast "after:update:IdeaGroup"
#    rebroadcast "after:create:IdeaGroup"
#    rebroadcast "after:delete:IdeaGroup"
#    rebroadcast "after:update:Dotstorm"
#
#    socket.on 'disconnect', ->
#      for [key, listener] in socketListeners[socket.id]
#        Backbone.sync.removeListener(key, listener)

  return { app, io, sessionStore, getDb: (-> db) }

module.exports = { start }
