express     = require 'express'
socketio    = require 'socket.io'
RedisStore  = require('connect-redis')(express)
logger      = require './logging'
Database    = require './backbone-mongo'
Backbone    = require 'backbone'
require './ideacanvas2image'

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
  rebroadcast = (key) ->
    Backbone.sync.on key, (data) ->
      console.log "rebroadcast #{key}"
      roomserver.in(data.dotstorm_id).emit key, data
  rebroadcast("images:Idea")
  for collectionName in ["Idea", "IdeaGroup", "Dotstorm"]
    do (collectionName) ->
      rebroadcast("after:update:#{collectionName}")
      rebroadcast("after:create:#{collectionName}")
      rebroadcast("after:delete:#{collectionName}")


  return { app, io, sessionStore, getDb: (-> db) }

module.exports = { start }
