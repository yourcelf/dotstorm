# Be sure to import this first.

if typeof require != "undefined"
  root = module.exports
  Backbone = require 'backbone'
  _        = require 'underscore'
else
  root = this
  Backbone = root.Backbone
  _        = root._


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

  slugify: (name) ->
    return name.toLowerCase().replace(/[^a-z0-9_\.]/g, '-')

  validate: (attrs) ->
    if not attrs.name
      return "Missing a name."
    if attrs.name?.length < 4
      return "Name must be 4 or more characters."

class DotstormList extends Backbone.Collection
  model: Dotstorm
  collectionName: Dotstorm.prototype.collectionName

modelFromCollectionName = (collectionName, isCollection=false) ->
  if isCollection
    switch collectionName
      when "Idea" then IdeaList
      when "Dotstorm" then DotstormList
      else null
  else
    switch collectionName
      when "Idea" then Idea
      when "Dotstorm" then Dotstorm
      else null

exports = { Dotstorm, DotstormList, Idea, IdeaList, modelFromCollectionName }
_.extend(root, exports)
