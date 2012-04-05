Backbone = require 'backbone'
_        = require 'underscore'

_.extend Backbone.Model.prototype, {
  # Use mongodb id attribute
  idAttribute: '_id'
}

class Idea extends Backbone.Model
  collectionName: 'Idea'
class IdeaList extends Backbone.Collection
  model: Idea
  collectionName: Idea.prototype.collectionName

class Dotstorm extends Backbone.Model
  collectionName: 'Dotstorm'
class DotstormList extends Backbone.Collection
  model: Dotstorm
  collectionName: Dotstorm.prototype.collectionName

module.exports = { Dotstorm, DotstormList, Idea, IdeaList }
