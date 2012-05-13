fs         = require 'fs'
path       = require 'path'
expect     = require 'expect.js'

h          = require './helper'
models     = require '../assets/js/dotstorm/models'
thumbnails = require '../lib/ideacanvas2image'

BASE_DIR = __dirname + "/../assets"

describe "Canvas to image from idea", ->
  before ->
    @mahId = undefined
    @server = h.startServer()
  after ->
    @server.app.close()

  it "initializes the database", (done) ->
    h.waitsFor =>
      if @server.getDb()?
        done()
        return true

  it "creates an idea", (done) ->
    idea = new models.Idea
      imageVersion: 0
      dotstorm_id: "aaaaaaaaaaaaaaaaaaaaaaaa"
      background: "#ffffdd"
      dims: x: 400, y: 400
      tags: "ok"
      description: "whatevs"
      drawing: [["pencil", 0, 0, 400, 400]]
    idea.save null,
      success: (model) =>
        thumbnails.drawingThumbs model, =>
          @mahId = model.id
          imgPath = BASE_DIR + model.getThumbnailURL("small")
          h.waitsFor =>
            if path.existsSync imgPath
              done()
              return true
      error: (model, err) ->
        expect().fail(err)
        done()

  it "removes the idea", (done) ->
    idea = new models.Idea _id: @mahId
    idea.fetch
      success: (model) =>
        thumb = BASE_DIR + model.getThumbnailURL("small")
        thumbDir = path.dirname(thumb)
        model.destroy
          success: (model) =>
            thumbnails.remove model, (err) =>
              expect(err).to.be(null)
              go = =>
                if path.existsSync(thumb) or path.existsSync(thumbDir)
                  setTimeout go, 10
                else
                  done()
              go()

          error: (model, err) ->
            expect().fail(err)
            done()
      error: (model, err) ->
        expect().fail(err)
        done()
