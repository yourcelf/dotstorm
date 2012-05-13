config = require '../lib/config'
server = require '../lib/server'

# Use a different port from the config port, so we don't clash with a
# running dev server.
config.port = 8127

module.exports =
  startServer: ->
    return server.start(config)
  waitsFor: (callback) ->
    interval = setInterval (-> if callback() then clearInterval interval), 100

