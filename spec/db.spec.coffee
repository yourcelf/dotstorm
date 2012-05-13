expect   = require 'expect.js'
models   = require '../assets/js/dotstorm/models'
h        = require './helper'
mocha    = require 'mocha'

describe "Vanilla MongoDB test", ->
  it "persists and retrieves data", (done) ->
    mongodb = require 'mongodb'
    client = new mongodb.Db 'test', new mongodb.Server("127.0.0.1", 27017, {})
    test = (err, coll) ->
      coll.insert {a:2}, (err, docs) ->
        coll.count (err, count) ->
          expect(count).to.be(1)
        coll.find().toArray (err, results) ->
          expect(results.length).to.be(1)
          expect(results[0].a).to.be(2)
          for result in results
            coll.remove result
          client.close()
          done()
    client.open (err, p_client) ->
      client.collection 'test_insert', test

describe "MongoDB backbone connector", ->
  before ->
    @server = h.startServer()
    @mahId = undefined
  after ->
    @server.app.close()

  it "initializes the server", (done) ->
    h.waitsFor =>
      if @server.getDb()?
        done()
        return true

  for [Coll, Model] in [[models.DotstormList, models.Dotstorm]]
    it "saves a model", (done) ->
      d = new Model
        name: "my happy storm"
      d.save {},
        success: (m) =>
          @mahId = m.id
          done()
        error: (model, error) ->
          expect().fail(error)
          done()

    it "retrieves the model", (done) ->
      expect(@mahId).to.not.be(undefined)
      d = new Model _id: @mahId
      d.fetch
        success: (model) ->
          expect(model.get("name")).to.eql("my happy storm")
          done()
        error: (model, error) ->
          expect().fail(error)
          done()

    it "fetches from collection", (done) ->
      d = new Coll
      d.fetch
        success: (items) ->
          expect(items.length).to.be(1)
          done()
        error: (model, error) ->
          expect().fail(error)
          done()

    it "deletes everything in the collection", (done) ->
      d = new Coll
      d.fetch
        success: (items) ->
          count = items.length
          for model in (m for m in items.models)
            model.destroy
              success: ->
                count -= 1
                if count == 0
                  done()
              error: (model, error) ->
                expect().fail(error)

    it "Ensures there's nothing left", (done) ->
      d = new Coll
      d.fetch
        success: (items) ->
          expect(items.models.length).to.be(0)
          done()
        error: (model, error) ->
          expect().fail(error)
