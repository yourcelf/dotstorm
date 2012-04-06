Backbone = require 'backbone'
mongo    = require 'mongodb'
logger   = require './logging'

_connection = null

open = (opts, callbacks) ->
  if _connection?
    if callbacks.success? then callbacks.success(_connection)
    return _connection

  connector = new mongo.Db(
    opts.dbname,
    new mongo.Server(opts.dbhost, opts.dbport, opts.dbopts)
  )

  connector.open (err, database) ->
    if (err)
      if callbacks.error? then callbacks.error(err)
      logger.error(err)
    else
      _connection = database
      callbacks.success(_connection) if callbacks.success?

Backbone.sync = (method, model, options) ->
  cb = options.success or (->)
  cberr = (err) ->
    logger.error(err)
    options.error() if options.error
  unless _connection?
    cberr "Not connected to the database."
    return

  collectionName = model.collectionName
  unless collectionName?
    cberr "No collectionName found for model or collection."
    return

  _connection.collection collectionName, (err, coll) ->
    if err
      return cberr(err)
    done = (err, result) ->
      if err
        cberr(err)
      else
        cb(result[0])

    switch method
      when "create"
        coll.insert model.toJSON(), {safe: true}, done
      when "update"
        coll.update {_id: model.get('_id')}, model.toJSON(), {safe: true}, done
      when "delete"
        coll.remove {_id: model.get('_id')}, {safe: true}, done
      when "read"
        coll.find(model.toJSON()).toArray (err, items) ->
          if err
            cberr(err)
          else
            if model instanceof Backbone.Model
              cb(items[0])
            else
              cb (items)

module.exports = { open }
