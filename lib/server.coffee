express     = require 'express'
socketio    = require 'socket.io'
RedisStore  = require('connect-redis')(express)
logger      = require './logging'
mongoose    = require 'mongoose'

# See Cakefile for options definitions and defaults
start = (options) ->
  sessionStore = new RedisStore

  db = mongoose.connect(
    "mongodb://#{options.dbhost}:#{options.dbport}/#{options.dbname}"
  )

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

  # /d/:slug without trainling slash
  app.get /^\/d\/([^/]+)$/, (req, res) ->
    res.redirect "/d/#{req.params[0]}/"

  # /d/:slug/:action (action optional)
  app.get /\/d\/([^/]+)(\/.*)?/, (req, res) ->
    #XXX load initial data when a slug is given....
    res.render 'dotstorm', title: "DotStorm", slug: req.params[0], initial: {}

  require('./auth').route(app, options.host)

  app.listen options.port

  # Socket sessions
  io = socketio.listen(app, "log level": 0)

  # binds to '/io'
  channel = '/io'
  require('./iorooms.server').attach(channel, io, sessionStore)
  require('./socket-connector').attach(channel, io)
  roomserver = io.of(channel)

  #
  # Events from backbone->mongo:
  #

  return { app, io, sessionStore, db }

module.exports = { start }
