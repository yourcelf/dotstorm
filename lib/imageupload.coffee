models = require '../assets/js/dotstorm/models'
thumbnails = require './ideacanvas2image'

attach = (channel, io) ->
  io.of(channel).on 'connection', (socket) ->
    socket.on 'uploadPhoto', (data) ->
      idea = new models.Idea(data.idea)
      thumbnails.photoThumbs idea, data.imageData, (err) ->
        if data.event?
          if (err)
            socket.emit data.event, error: err
          else
            socket.emit data.event, {}
          socket.broadcast.to(idea.get("dotstorm_id")).emit("trigger", {
            collectionName: "Idea"
            id: idea.id
            event: "change:photo"
          })

module.exports = { attach }
