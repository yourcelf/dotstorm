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
  incImageVersion: =>
    @set {imageVersion: (@get("imageVersion") or 0) + 1}, silent: true

  validate: (attrs) =>
    #XXX: Check if dotstorm ID references a non-read-only dotstorm...?
    if not attrs.dotstorm_id then return "Dotstorm ID missing."
    if attrs.tags? and @get("tags") != attrs.tags
      cleaned = @getTags(attrs.tags).join(", ")
      if cleaned != attrs.tags
        @set "tags", cleaned, silent: true
#    if not attrs.imageVersion?
#      @set "imageVersion", 0, silent: true
#    if not attrs.created?
#      @set "created", new Date().getTime(), silent: true
#    @set "modified", new Date().getTime(), silent: true
    return

  getThumbnailURL: (size) =>
    return "/uploads/idea/#{@.id}/#{size}#{@get "imageVersion"}.png"

  cleanTag: (tag) => return tag.replace(/[^-\w\s]/g, '').trim()
  cleanTags: (tags) => @getTags(tags).join(", ")
  getTags: (tags) =>
    cleaned = []
    for tag in (tags or @get("tags") or "").split(",")
      clean = @cleanTag(tag)
      if clean
        cleaned.push(clean)
    return cleaned

class IdeaList extends Backbone.Collection
  model: Idea
  collectionName: Idea.prototype.collectionName

class IdeaGroup extends Backbone.Model
  collectionName: 'IdeaGroup'

  addIdeas: (idlist, options) =>
    ideas = @get("ideas")?.slice() or []
    for id in idlist
      unless _.include(ideas, id)
        ideas.push(id)
    @set({ideas}, options)

  removeIdea: (id, options) =>
    ideas = @get("ideas")?.slice() or []
    index = _.indexOf(ideas, id)
    unless index == -1
      ideas.splice(index, 1)
      @set({ideas}, options)
      return true
    return false

  containsIdea: (id) =>
    return _.contains @get("ideas"), id

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
    if attrs.slug?.length < 4
      return "Name must be 4 or more characters."
    if not attrs.created?
      attrs.created = new Date().getTime()
    attrs.modified = new Date().getTime()
    return

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
