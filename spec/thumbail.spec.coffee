path       = require 'path'
expect     = require 'expect.js'
h          = require './helper'
models     = require '../lib/schema'

BASE_DIR = __dirname + "/../assets"

describe "Canvas to image from idea", ->
  before ->
    @mahId = undefined
    @server = h.startServer()
  after ->
    @server.app.close()

  it "creates an idea", (done) ->
    idea = new models.Idea
      dotstorm_id: "aaaaaaaaaaaaaaaaaaaaaaaa"
      background: "#ffffdd"
      tags: "ok"
      description: "whatevs"
      drawing: [["pencil", 0, 0, 400, 400]]

    idea.save (err) =>
      @mahId = idea._id
      expect(err).to.be null
      h.waitsFor =>
        if path.existsSync idea.getDrawingPath("small")
          done()
          return true

  it "removes the idea", (done) ->
    models.Idea.findOne {_id: @mahId}, (err, idea) ->
      expect(err).to.be null
      expect(idea).to.not.be null
      idea.remove (err) ->
        expect(path.existsSync idea.getDrawingPath("small")).to.be false
        done()
