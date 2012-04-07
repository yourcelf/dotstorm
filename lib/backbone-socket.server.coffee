models = require '../assets/js/models'

attach = (route, io) ->
  io.of(route).on 'connection', (socket) ->
    socket.on 'backbone', (data) ->
      Model = models.modelFromCollectionName(
        data.signature.collectionName, data.signature.isCollection
      )
      model = new Model data.model

      if data.signature.event
        callbacks =
          success: (model, response) ->
            socket.emit data.signature.event, model.toJSON()
          error: (nmodel, response) ->
            socket.emit data.signature.event, error: response.toJSON()
        if data.signature.query?
          callbacks.query = data.signature.query
      else
        callbacks = {}

      switch data.signature.method
        when "create" then model.save {}, callbacks
        when "update" then model.save {}, callbacks
        when "delete" then model.destroy callbacks
        when "read"   then model.fetch callbacks

module.exports = { attach }
