config = require '../lib/config'
server = require '../lib/server'
client = require '../assets/js/iorooms.client'
io     = require 'socket.io-client'

# Use a different port from the config port, so we don't clash with a
# running dev server.
config.port = 8127

# Helper for waiting untill a callback returns.  Pass 'done' as the callback,
# and wrap your function with 'waitsForDone'.
isDone = false
done = (data) -> isDone = true
waitsForDone = (descr, fn, timeout=1000) ->
  isDone = false
  fn()
  waitsFor ->
    isDone == true
  , descr, timeout

startServer = ->
  return server.start(config)

newClient = ->
  return new client.Client(
    io.connect("http://#{config.host}:#{config.port}/iorooms", {
      'force new connection': true
    })
  )

module.exports = { done, waitsForDone, startServer, newClient }
