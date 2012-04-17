models   = require '../assets/js/models'
h        = require './helper'
fs       = require 'fs'
path     = require 'path'

BASE_DIR = __dirname + "/../static"

# This test can't work here -- it needs a functioning socket connection, for
# which cookies are required.  Fail!
#
#describe "Canvas to image from idea", ->
#  server = global.server
#  mahId = null
#
#  beforeEach ->
#    @addMatchers
#      fail: (expected) ->
#        @message = -> expected
#        return false
#
#  it "executes synchronously", -> h.executeSync("db")
#
#  it "initializes the database", ->
#    waitsFor (-> server.getDb()? ), "db connection", 1000
#
#  it "creates an idea", (done) ->
#    idea = new models.Idea
#      imageVersion: 0
#      dotstorm_id: "aaaaaaaaaaaaaaaaaaaaaaaa"
#      background: "#ffffdd"
#      dims: x: 400, y: 400
#      tags: "ok"
#      description: "whatevs"
#      drawing: [["pencil", 0, 0, 400, 400]]
#    idea.save null,
#      success: (model) ->
#        mahId = model.id
#        interval = setInterval ->
#          if path.existsSync BASE_DIR + model.getThumbnailURL("small")
#            done()
#            clearInterval(interval)
#        , 100
#      error: (model, err) ->
#        expect().fail(err)
#        done()
#
#  it "removes the idea", (done) ->
#    idea = new models.Idea _id: mahId
#    idea.fetch
#      success: (model) ->
#        thumb = BASE_DIR + model.getThumbnailURL("small")
#        model.destroy
#          success: ->
#            interval = setInterval ->
#              unless path.existsSync thumb or path.existsSync path.dirname(thumb)
#                done()
#                clearInterval(interval)
#            , 100
#          error: (model, err) ->
#            expect().fail(err)
#      error: (model, err) ->
#        expect().fail(err)
#
#  it "done executing synchronously", -> h.doneExecutingSync()
