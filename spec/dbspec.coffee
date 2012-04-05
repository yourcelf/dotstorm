models   = require '../assets/js/models'
h        = require './helper'
_        = require 'underscore'
Backbone = require 'backbone'

isDone = false
done = -> isDone = true
waitForDone = ->
  isDone = false
  waitsFor -> isDone

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
  beforeEach -> @server = h.startServer()
  afterEach  -> @server.app.close()

  cberr = (err) ->
    console.log err
    expect(true).toBe(false)
    done()

  it "persists and retrieves data", ->
    server = @server
    waitsFor (-> server.getDb()? ), "db connection", 1000
    for [Coll, Model] in [[models.DotstormList, models.Dotstorm], [models.IdeaList, models.Idea]]
      runs ->
        d = new Model
          name: "my happy storm"
        d.save {},
          success: -> done()
          error: cberr
        waitForDone()
      runs ->
        d = new Coll
        d.fetch
          success: (items) ->
            expect(items.length).toBe(1)
            done()
          error: cberr
        waitForDone()
      runs ->
        d = new Coll
        d.fetch
          success: (items) ->
            length = items.length
            _.each items.models, (model, i) ->
              model.destroy success: done, error: cberr
        waitForDone()
      runs ->
        d = new Coll
        d.fetch
          success: (items) ->
            expect(items.models.length).toBe(0)
            done()
          error: cberr
        waitForDone()
