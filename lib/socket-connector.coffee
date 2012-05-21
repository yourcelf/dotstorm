logger     = require './logging'
models     = require './schema'
thumbnails = require './thumbnails'

#
# Connect the plumbing for backbone models coming over the socket to mongoose
# models.  Rebroadcast data to rooms as appropriate.
#
attach = (channel, io) ->
  io.of(channel).on 'connection', (socket) ->
    #TODO: Authentication!!! Here!!!
    # - ensure that parameters are OK: e.g., only author should be able to
    #   set author; only voter should be able to vote.
    # - ensure that the dotstorm being modified is modifiable by the person
    #   sending in. Authie Authie Authie!! Oi Oi Oi!!
    # - ensure that someone reading a dotstorm is allowed to.

    socket.on 'backbone', (data) ->
      errorOut = (error) ->
        logger.error(error)
        socket.emit(data.signature.event, error: error)
      respond = (model) ->
        socket.emit(data.signature.event, model)
      rebroadcast = (room, model) ->
        if room?
          socket.broadcast.to(room).emit "backbone", {
            signature: {
              collectionName: data.signature.collectionName
              method: data.signature.method
            }
            model: model
          }

      saveIdeaAndRespond = (doc) ->
        for key in ["dotstorm_id", "description", "background", "tags",
                    "drawing", "votes", "photoData"]
          if data.model[key]?
            doc[key] = data.model[key]
        if not data.model.tags? and data.model.taglist?
          doc.taglist = data.model.taglist
        doc.save (err) ->
          if (err) then return errorOut(err)
          json = doc.serialize()
          delete json.drawing
          respond(json)
          rebroadcast(doc.dotstorm_id, json)

      saveDotstormAndRespond = (doc) ->
        for key in ["slug", "name", "topic", "groups", "trash"]
          if data.model[key]?
            doc.set key, data.model[key]
        doc.save (err) ->
          if err? then return errorOut(err)
          respond(doc.serialize())
          rebroadcast(doc._id, doc)

      switch data.signature.collectionName
        when "Idea"
          switch data.signature.method
            when "create"
              doc = new models.Idea()
              saveIdeaAndRespond(doc)
            when "update"
              models.Idea.findOne {_id: data.model._id}, (err, doc) ->
                if err? then return errorOut(err)
                saveIdeaAndRespond(doc)
            when "delete"
              models.Idea.findOne {_id: data.model._id}, (err, doc) ->
                doc.remove (err) ->
                  if err? then return errorOut(err)
                  json = {_id: doc._id}
                  respond(json)
                  rebroadcast(doc.dotstorm_id, json)
            when "read"
              if data.signature.query?
                query = data.signature.query
              else if data.model?
                query = data.model
                # Remove virtuals before querying...
                delete query.drawingURLs
                delete query.photoURLs
                delete query.taglist
              else
                query = {}
              if data.signature.isCollection
                method = "findLight"
              else
                method = "findOne"
              models.Idea[method](query, (err, res) ->
                  if data.signature.isCollection
                    respond (m.serialize() for m in (res or []))
                  else
                    respond (res?.serialize() or {})
              )

        when "Dotstorm"
          switch data.signature.method
            when "create"
              dotstorm = new models.Dotstorm()
              saveDotstormAndRespond(dotstorm)
            when "update"
              models.Dotstorm.findOne {_id: data.model._id}, (err, doc) ->
                saveDotstormAndRespond(doc)
            when "delete"
              models.Dotstorm.findOne {_id: data.model._id}, (err, doc) ->
                doc.remove (err) ->
                  if err? then return errorOut(err)
                  respond(doc)
                  rebroadcast(doc._id, doc)
            when "read"
              query = data.signature.query or data.model
              models.Dotstorm.find query, (err, docs) ->
                if data.signature.isCollection
                  respond(docs or [])
                else
                  respond(docs?[0] or {})

module.exports = { attach }
