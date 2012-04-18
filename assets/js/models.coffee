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

  incPhotoVersion: =>
    @set {photoVersion: (@get("photoVersion") or 0) + 1}, silent: true

  validate: (attrs) =>
    #XXX: Check if dotstorm ID references a non-read-only dotstorm...?
    if not attrs.dotstorm_id? then return "Dotstorm ID missing."
    if attrs.tags? and @get("tags") != attrs.tags
      cleaned = @getTags(attrs.tags).join(", ")
      if cleaned != attrs.tags
        @set "tags", cleaned, silent: true
    if not attrs.created?
      @set "created", new Date().getTime(), silent: true
    @set "modified", new Date().getTime(), silent: true
    return

  getThumbnailURL: (size) =>
    return "/uploads/idea/#{@.id}/drawing/#{size}#{@get "imageVersion"}.png"

  getPhotoURL: (size) =>
    return "/uploads/idea/#{@.id}/photo/#{size}#{@get "photoVersion"}.png"

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

class Dotstorm extends Backbone.Model
  collectionName: 'Dotstorm'
  defaults:
    ideas: []

  slugify: (name) -> return name.toLowerCase().replace(/[^a-z0-9_\.]/g, '-')

  validate: (attrs) ->
    if not attrs.name then return "Missing a name."
    if attrs.slug?.length < 4 then return "Name must be 4 or more characters."
    if not attrs.created? then @set "created", new Date().getTime(), silent: true
    @set "modified", new Date().getTime(), silent: true
    return

  setLabelFor: (idea_id, label, options) =>
    @getGroup(idea_id).label = label

  getGroup: (idea_id) =>
    for entity in @get("ideas")
      if entity.ideas? and _.contains entity.ideas, idea_id
        return entity
    return null

  getGroupPos: (idea_id, _list, _group) =>
    # Return the list containing the ID, and the position within the list.
    unless _list? then _list = @get("ideas")
    for i in [0..._list.length]
      entity = _list[i]
      if entity == idea_id
        return { list: _list, pos: i, group: _group }
      else if entity.ideas?
        pos = @getGroupPos(idea_id, entity.ideas, _list)
        if pos
          return pos
    return null

  groupify: (id1, id2, rightSide, options) =>
    # Remove id1 from its original position.
    id1Pos = @getGroupPos(id1)
    id1Pos.list.splice(id1Pos.pos, 1)
    if id1Pos.group? and id1Pos.list.length == 0
      @_purgeGroup(id1Pos.group, id1Pos.list)

    # Find id2, and add id2 to it.
    groupPos = @getGroupPos(id2)
    if groupPos.group?
      if rightSide
        groupPos.list.splice(groupPos.pos + 1, 0, id1)
      else
        groupPos.list.splice(groupPos.pos + 0, 0, id1)
    else
      # Add a new group in the position of id2.
      if rightSide
        newGroup = { ideas: [id2, id1] }
      else
        newGroup = { ideas: [id1, id2] }
      groupPos.list.splice(groupPos.pos, 1, newGroup)
      # Remove id1 from its original position.
    @orderChanged(options)

  ungroup: (idea_id, rightSide, options) =>
    groupPos = @getGroupPos(idea_id)
    if groupPos.group?
      # Remove idea_id from the group.
      groupPos.list.splice(groupPos.pos, 1)
      for i in [0...groupPos.group.length]
        # Add idea_id back in.
        if groupPos.group[i].ideas == groupPos.list
          # Is the group empty?  Replace it.
          if groupPos.list.length == 0
            groupPos.group.splice(i, 1, idea_id)
          else if rightSide
            # Not empty?  Insert on the right...
            groupPos.group.splice(i + 1, 0, idea_id)
          else
            # ... or the left.
            groupPos.group.splice(i, 0, idea_id)
          @orderChanged(options)
          return

  _purgeGroup: (parent, list) =>
    for i in [0...parent.length]
      if parent[i].ideas == list
        parent.splice(i, 1)
        return

  _popTo: (source_id, target_id, rightSide, options) =>
    # Remove source.
    sourcePos = @getGroupPos(source_id)
    sourcePos.list.splice(sourcePos.pos, 1)
    # Purge empty groups.
    if sourcePos.group? and sourcePos.list.length == 0
      @_purgeGroup(sourcePos.group, sourcePos.list)
    targetPos = @getGroupPos(target_id)
    offset = if rightSide then 1 else 0
    targetPos.list.splice(targetPos.pos + offset, 0, source_id)

  putLeftOf: (source_id, target_id, options) =>
    @_popTo(source_id, target_id, false, options)

  putRightOf: (source_id, target_id, options) =>
    @_popTo(source_id, target_id, true, options)

  addIdea: (idea_id, options) =>
    groupPos = @getGroupPos(idea_id)
    unless groupPos?
      ideas = @get("ideas")
      ideas.push(idea_id)
      @set("ideas", ideas, options)

  removeIdea: (idea_id, options) =>
    groupPos = @getGroupPos(idea_id)
    if groupPos?
      groupPos.list.splice(groupPos.pos, 1)
      @orderChanged(options)

  orderChanged: (options) => @trigger "change:ideas" unless options?.silent


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
