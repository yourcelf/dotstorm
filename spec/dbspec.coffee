Backbone = require 'backbone'
_        = require 'underscore'
models   = require '../assets/js/models'
h        = require './helper'

describe "Vanilla MongoDB test", ->
  it "persists and retrieves data", ->
    mongodb = require 'mongodb'
    client = new mongodb.Db 'test', new mongodb.Server("127.0.0.1", 27017, {})
    test = (err, coll) ->
      coll.insert {a:2}, (err, docs) ->
        coll.count (err, count) ->
          expect(count).toEqual(1)
        coll.find().toArray (err, results) ->
          expect(results.length).toEqual(1)
          expect(results[0].a).toEqual(2)
          for result in results
            coll.remove result
          client.close()
    client.open (err, p_client) ->
      client.collection 'test_insert', test

describe "MongoDB backbone connector", ->
  server = global.server
  cberr = (done) ->
    return (err) ->
      console.log err
      expect(true).toBe(false)
      done()
  mahId = undefined

  it "initializes the server", ->
    waitsFor (-> server.getDb()? ), "db connection", 1000

  for [Coll, Model] in [[models.DotstormList, models.Dotstorm], [models.IdeaList, models.Idea]]
    it "saves a model", (done) ->
      # Save a model
      d = new Model
        name: "my happy storm"
      d.save {},
        success: (m) ->
          mahId = m.id
          done()
        error: cberr(done)

    it "retrieves the model", (done) ->
      # Retrieve the just-saved model.
      expect(mahId).toBeDefined()
      d = new Model _id: mahId
      d.fetch
        success: (model) ->
          expect(model.get("name")).toEqual("my happy storm")
          done()
        error: cberr(done)

    it "fetches from collection", (done) ->
      # Fetch from collection.
      d = new Coll
      d.fetch
        success: (items) ->
          expect(items.length).toBe(1)
          done()
        error: cberr(done)

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
              error: cberr(done)

    it "Ensures there's nothing left", (done) ->
      # Ensure there's none left.
      d = new Coll
      d.fetch
        success: (items) ->
          expect(items.models.length).toBe(0)
          done()
        error: cberr(done)
