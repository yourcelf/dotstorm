models = require '../assets/js/dotstorm/models'
logger = require './logging'
events = require 'events'
Backbone = require 'backbone'
_        = require 'underscore'

_.extend Backbone.sync, events.EventEmitter.prototype

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
            Backbone.sync.emit "backbone", socket, data.signature, model
            logger.debug "success: #{data.signature.method} #{data.signature.collectionName} #{model.length or 1}"
          error: (model, response) ->
            Backbone.sync.emit "backbone:error", socket, data.signature, model, response
            logger.error model
            logger.error response
      else
        callbacks = {}

      callbacks.query = data.signature.query
      callbacks.fields = data.signature.fields

      switch data.signature.method
        when "create" then model.save {}, callbacks
        when "update" then model.save {}, callbacks
        when "delete" then model.destroy callbacks
        when "read"   then model.fetch callbacks

module.exports = { attach }
