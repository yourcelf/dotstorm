# Since this is used in the client only, we don't use `require`, and assume
# Backbone is already present.

# http://developer.teradata.com/blog/jasonstrimpel/2011/11/backbone-js-and-socket-io
  
Backbone.setSocket = (socket) ->
  Backbone._socket = socket

Backbone.clearSocket = ->
  Backbone._socket = null

Backbone.sync = (method, model, options) ->
  cberr = (err) ->
    options.error() if options.error
  unless Backbone._socket?
    cberr "No socket connection"
  
    Backbone._socket.emit "backbone",
      method: method
      collectionName: model.collectionName
      model: model.toJSON()

