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
      errorOut = (error) -> socket.emit(data.signature.event, error: error)
      respond = (model) -> socket.emit(data.signature.event, model)
      rebroadcast = (room, model) ->
        if room?
          socket.broadcast.to(room).emit "backbone", {
            signature: {
              collectionName: data.signature.collectionName
              method: data.signature.method
            }
            model: model
          }

      switch data.signature.collectionName
        when "Idea"
          switch data.signature.method
            when "create"
              idea = new models.Idea(data.model)
              idea.save (err) ->
                if err? then return errorOut(err)
                json = idea.toJSON()
                delete json.drawing
                respond(idea)
                rebroadcast(idea.dotstorm_id, idea)
            when "update"
              models.Idea.findOne {_id: data.model._id}, (err, doc) ->
                if err? then return errorOut(err)
                for key in ["description", "background", "tags"
                            "drawing", "votes"]
                  if data.model[key]?
                    doc.set key, data.model[key]
                doc.save (err) ->
                  if err? then return errorOut(err)
                  json = doc.toJSON()
                  delete json.drawing
                  respond(data.signature.event, json)
                  rebroadcast(doc.dotstorm_id, json)
            when "delete"
              models.Idea.findOne {_id: data.model._id}, (err, doc) ->
                doc.remove (err) ->
                  if err? then return errorOut(err)
                  json = {_id: doc._id}
                  respond(json)
                  rebroadcast(doc.dotstorm_id, json)
            when "read"
              query = data.signature.query or data.model
              if data.signature.isCollection
                method = models.Idea.findLight
              else
                method = models.Idea.findOne
              method.call(models.Idea, query, (err, res) ->
                  if data.signature.isCollection
                    respond(res or [])
                  else
                    respond(res or {})
              )

        when "Dotstorm"
          switch data.signature.method
            when "create"
              dotstorm = new models.Dotstorm(data.model)
              dotstorm.save (err) ->
                if err? then return errorOut(err)
                respond(dotstorm)
                rebroadcast(dotstorm.dotstorm_id, dotstorm)
            when "update"
              models.Dotstorm.findOne {_id: data.model._id}, (err, doc) ->
                for key in ["slug", "name", "description", "groups"]
                  if data.model[key]?
                    doc.set key, data.model[key]
                doc.save (err) ->
                  if err? then return errorOut(err)
                  respond(data.signature.event, doc)
                  rebroadcast(doc._id, doc)
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

    socket.on 'uploadPhoto', (data) ->
      models.Idea.findOneLight {_id: data.idea._id}, (err, idea) ->
        idea.photoVersion ||= 0
        idea.photoVersion += 1
        idea.save (err) ->
          if err?
            logger.error(err)
            socket.emit(data.event, error: err)
          else
            thumbnails.photoThumbs idea, data.imageData, (err) ->
              if err? then logger.error(err)
              if data.event?
                if err? then return socket.emit(data.event, error: err)

                socket.emit data.event, {}
                socket.broadcast.to(idea.dotstorm_id).emit("trigger", {
                  collectionName: "Idea"
                  id: idea.id
                  event: "change:photo"
                })

module.exports = { attach }
