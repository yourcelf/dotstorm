expect   = require 'expect.js'
mongoose = require 'mongoose'
models   = require '../lib/schema'
path     = require 'path'
_        = require 'underscore'

db = mongoose.connect("mongodb://localhost:27017/test")

BASE = __dirname + '/../assets'

describe "Mongoose connector", ->
  it "clears the test db", (done) ->
    count = 3
    clear = (model) ->
      model.remove {}, (err) ->
        expect(err).to.be null
        count -= 1
        if count == 0
          done()

    clear(models.Dotstorm)
    clear(models.Idea)
    clear(models.IdeaGroup)

  it "creates a dotstorm", (done) ->
    new models.Dotstorm({
      slug: "test"
    }).save (err) ->
      expect(err).to.be null
      models.Dotstorm.findOne {slug: "test"}, (err, doc) ->
        expect(err).to.be null
        expect(doc.slug).to.eql "test"
        done()

  it "creates an idea", (done) ->
    models.Dotstorm.findOne {slug: "test"}, (err, dotstorm) =>
      @dotstorm = dotstorm
      idea = new models.Idea({
        dotstorm_id: dotstorm._id
        description: "open to creative possibility"
      })
      idea.save (err) ->
        expect(err).to.be null
        dotstorm.groups.push new models.IdeaGroup(ideas: [idea._id])
        dotstorm.save (err) ->
          expect(err).to.be(null)
          models.Idea.findOne {}, (err, idea) ->
            expect(err).to.be null
            expect(idea.description).to.be "open to creative possibility"
            expect(idea.drawingURLs).to.eql {}
            done()

  it "creates a drawing", (done) ->
    models.Idea.findOne {dotstorm_id: @dotstorm._id}, (err, idea) =>
      expect(err).to.be null
      idea.drawing = [["pencil", 0, 0, 64, 64]]
      idea.background = "#ffffff"
      idea.save (err) ->
        expect(err).to.be null
        expect(idea.drawingURLs.small).to.be "/uploads/idea/#{idea._id}/drawing/small1.png"
        expect(path.existsSync(BASE + idea.drawingURLs.small)).to.be true
        done()

  it "returns light ideas", (done) ->
    models.Idea.findOneLight {dotstorm_id: @dotstorm._id}, (err, idea) =>
      expect(err).to.be null
      expect(idea.drawing).to.be undefined
      done()
 
  it "populates ideas in dotstorm", (done) ->
    models.Dotstorm.withLightIdeas {}, (err, dotstorm) ->
      expect(err).to.be null
      idea = dotstorm.groups[0].ideas[0]
      expect(idea.description).to.be "open to creative possibility"
      expect(idea.drawing).to.be undefined
      done()

  it "saves tags", (done) ->
    models.Idea.findOne {dotstorm_id: @dotstorm._id}, (err, idea) =>
      idea.set("taglist", "this, that, theother")
      expect(_.isEqual idea.tags, ["this", "that", "theother"]).to.be true
      done()

  it "removes thumbnails with idea", (done) ->
    models.Idea.findOne {dotstorm_id: @dotstorm._id}, (err, idea) =>
      imgPath = BASE + idea.drawingURLs.small
      expect(path.existsSync(imgPath)).to.be true
      idea.remove (err) =>
        expect(err).to.be null
        expect(path.existsSync(imgPath)).to.be false
        done()
