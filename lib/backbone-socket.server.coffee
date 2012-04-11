models = require '../assets/js/models'
logger = require './logging'
events = require 'events'

attach = (route, io) ->
  io.of(route).on 'connection', (socket) ->
    socket.on 'backbone', (data) ->
      logger.debug "request: #{data.signature.method} #{data.signature.collectionName}", data.signature.query
      Model = models.modelFromCollectionName(
        data.signature.collectionName, data.signature.isCollection
      )
      model = new Model data.model

      if data.signature.event
        callbacks =
          success: (model, response) ->
            socket.emit data.signature.event, model.toJSON()
            logger.debug "success: #{data.signature.method} #{data.signature.collectionName} #{model.length or 1}"
          error: (nmodel, response) ->
            socket.emit data.signature.event, error: response.toJSON()
            logger.error nmodel
            logger.error response
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
