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
  initialize: ->
    @on "change:background", @incImageVersion
    @on "change:drawing", @incImageVersion

  incImageVersion: =>
    if @hasChanged('background') or @hasChanged('drawing')
      @set {imageVersion: (@get("imageVersion") or 0) + 1}, silent: true

  validate: (attrs) =>
    #XXX: Check if dotstorm ID references a non-read-only dotstorm...?
    if not attrs.dotstorm_id
      return "Dotstorm ID missing."

  getThumbnailURL: (size) =>
    return "/static/uploads/idea/#{@get "id"}/#{size}#{@get "version"}.png"

class IdeaList extends Backbone.Collection
  model: Idea
  collectionName: Idea.prototype.collectionName

class IdeaGroup extends Backbone.Model
  collectionName: 'IdeaGroup'
  addIdea: (id) =>
    ideas = @get("ideas") or []
    unless _.include(ideas, id)
      ideas.push(id)
      @set ideas: ideas
      return true
    return false

  removeIdea: (id) =>
    ideas = @get("ideas") or []
    index = _.indexOf(ideas, id)
    unless index == -1
      ideas.splice(index, 1)
      @set ideas: ideas
      return true
    return false
  validate: (attrs) ->
    #XXX: Check if dotstorm ID references a non-read-only dotstorm...?
    if not attrs.dotstorm_id
      return "Dotstorm ID missing."

class IdeaGroupList extends Backbone.Collection
  model: IdeaGroup
  collectionName: IdeaGroup.prototype.collectionName

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
      when "IdeaGroup" then IdeaGroupList
      when "Dotstorm" then DotstormList
      else null
  else
    switch collectionName
      when "Idea" then Idea
      when "IdeaGroup" then IdeaGroup
      when "Dotstorm" then Dotstorm
      else null

exports = { Dotstorm, DotstormList, Idea, IdeaList, IdeaGroup, IdeaGroupList, modelFromCollectionName }
_.extend(root, exports)
