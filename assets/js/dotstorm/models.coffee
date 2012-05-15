_.extend Backbone.Model.prototype, {
  # Use mongodb id attribute
  idAttribute: '_id'
}

class ds.Idea extends Backbone.Model
  collectionName: 'Idea'

class ds.IdeaList extends Backbone.Collection
  model: ds.Idea
  collectionName: ds.Idea.prototype.collectionName

class ds.Dotstorm extends Backbone.Model
  collectionName: 'Dotstorm'
  defaults:
    ideas: []

  slugify: (name) -> return name.toLowerCase().replace(/[^a-z0-9_\.]/g, '-')

  validate: (attrs) ->
    if attrs.slug?.length < 4
      return "Name must be 4 or more characters."

  getGroup: (idea_id) =>
    for entity in @get("ideas")
      if entity.ideas? and _.contains entity.ideas, idea_id
        return entity
    return null

  getGroupPos: (idea_id, _list, _parent, _group_pos) =>
    # Return the list containing the ID, and the position within the list.
    unless _list? then _list = @get("ideas")
    for i in [0..._list.length]
      entity = _list[i]
      if entity == idea_id
        return { list: _list, pos: i, parent: _parent, groupPos: _group_pos }
      else if entity.ideas?
        pos = @getGroupPos(idea_id, entity.ideas, _list, i)
        if pos
          return pos
    return null


  setLabelFor: (idea_id, label, options) =>
    @getGroup(idea_id).label = label

  #
  # Moving notes around
  #
  putLeftOf: (source, target, options) =>
    @move(source, false, target, false, false, options)
  putRightOf: (source, target, options) =>
    @move(source, false, target, false, true, options)
  putLeftOfGroup: (source, target, options) =>
    @move(source, false, target, true, false, options)
  putRightOfGroup: (source, target, options) =>
    @move(source, false, target, true, true, options)
  #
  # Moving groups around
  #
  putGroupLeftOf: (source, target, options) =>
    @move(source, true, target, false, false, options)
  putGroupRightOf: (source, target, options) =>
    @move(source, true, target, false, true, options)
  putGroupLeftOfGroup: (source, target, options) =>
    @move(source, true, target, true, false, options)
  putGroupRightOfGroup: (source, target, options) =>
    @move(source, true, target, true, true, options)

  #
  # All-in-one moving
  #
  move: (source, sourceGroup, target, targetGroup, rightSide, options) =>
    if sourceGroup
      if targetGroup
        @_popGroupAfterGroup(source, target, rightSide, options)
      else
        @_popGroupTo(source, target, rightSide, options)
    else
      if targetGroup
        @_popAfterGroup(source, target, rightSide, options)
      else
        @_popTo(source, target, rightSide, options)

  #
  # Grouping notes
  #
  groupify: (id1, id2, right_side, options) =>
    # Remove id1 from its original position.
    id1Pos = @getGroupPos(id1)
    id1Pos.list.splice(id1Pos.pos, 1)
    if id1Pos.parent? and id1Pos.list.length == 0
      id1Pos.parent.splice(id1Pos.groupPos, 1)

    # Find id2, and add id2 to it.
    groupPos = @getGroupPos(id2)
    if groupPos.parent?
      if right_side
        groupPos.list.splice(groupPos.pos + 1, 0, id1)
      else
        groupPos.list.splice(groupPos.pos + 0, 0, id1)
    else
      # Add a new group in the position of id2.
      if right_side
        newGroup = { ideas: [id2, id1] }
      else
        newGroup = { ideas: [id1, id2] }
      groupPos.list.splice(groupPos.pos, 1, newGroup)
      # Remove id1 from its original position.
    @orderChanged(options)

  ungroup: (idea_id, right_side, options) =>
    groupPos = @getGroupPos(idea_id)
    if groupPos.parent?
      # Remove idea_id from the group.
      groupPos.list.splice(groupPos.pos, 1)
      for i in [0...groupPos.parent.length]
        # Add idea_id back in.
        if groupPos.parent[i].ideas == groupPos.list
          # Is the group empty?  Replace it.
          if groupPos.list.length == 0
            groupPos.parent.splice(i, 1, idea_id)
          else if right_side
            # Not empty?  Insert on the right...
            groupPos.parent.splice(i + 1, 0, idea_id)
          else
            # ... or the left.
            groupPos.parent.splice(i, 0, idea_id)
          @orderChanged(options)
          return

  #
  # Grouping groups
  #
  combineGroups: (source_id, target_id, right_side, options) =>
    source_pos = @getGroupPos(source_id)
    target_pos = @getGroupPos(target_id)
    if target_pos.parent?
      if right_side
        @putGroupRightOf(source_id, target_id, options)
      else
        @putGroupLeftOf(source_id, target_id, options)
    else
      if right_side
        # 1. Move the group right of the target.
        @putGroupRightOf(source_id, target_id, options)
        # 2. Move the target into the group.
        @putLeftOf(target_id, source_id, options)
      else
        # 1. Move the group left of the target.
        @putGroupLeftOf(source_id, target_id, options)
        # 2. Move the target into the group.
        @putRightOf(target_id, source_pos.list[source_pos.list.length - 1], options)

  #
  # All-in-one grouping
  #
  combine: (source, sourceGroup, target, targetGroup, rightSide, options) =>
    if sourceGroup
      @combineGroups(source, target, rightSide, options)
    else
      @groupify(source, target, rightSide, options)
  
  #
  # Adding and removing ideas
  #

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

  #
  # Helpers
  #
  _popTo: (source_id, target_id, right_side, options) =>
    # Remove source.
    sourcePos = @getGroupPos(source_id)
    sourcePos.list.splice(sourcePos.pos, 1)
    # Purge empty groups.
    if sourcePos.parent? and sourcePos.list.length == 0
      sourcePos.parent.splice(sourcePos.groupPos, 1)
    targetPos = @getGroupPos(target_id)
    offset = if right_side then 1 else 0
    targetPos.list.splice(targetPos.pos + offset, 0, source_id)
    @orderChanged(options)

  _popGroupTo: (source_id, target_id, right_side, options) =>
    sourcePos = @getGroupPos(source_id)
    group = sourcePos.parent.splice(sourcePos.groupPos, 1)[0]
    targetPos = @getGroupPos(target_id)
    offset = if right_side then 1 else 0
    if targetPos.parent?
      targetLabel = targetPos.parent[targetPos.groupPos].label
      if group.label and not targetLabel
        targetPos.parent[targetPos.groupPos].label = group.label
      spliceArgs = [targetPos.pos + offset, 0].concat(group.ideas)
      targetPos.list.splice.apply(targetPos.list, spliceArgs)
    else
      targetPos.list.splice(targetPos.pos + offset, 0, group)
    @orderChanged(options)

  _popAfterGroup: (source_id, target_id, right_side, options) =>
    sourcePos = @getGroupPos(source_id)
    sourcePos.list.splice(sourcePos.pos, 1)
    targetPos = @getGroupPos(target_id)
    offset = if right_side then 1 else 0
    targetPos.parent.splice(targetPos.groupPos + offset, 0, source_id)
    @orderChanged(options)

  _popGroupAfterGroup: (source_id, target_id, right_side, options) =>
    sourcePos = @getGroupPos(source_id)
    group = sourcePos.parent.splice(sourcePos.groupPos, 1)[0]
    targetPos = @getGroupPos(target_id)
    offset = if right_side then 1 else 0
    targetPos.parent.splice(targetPos.groupPos + offset, 0, group)
    @orderChanged(options)

  orderChanged: (options) => @trigger "change:ideas" unless options?.silent


class ds.DotstormList extends Backbone.Collection
  model: ds.Dotstorm
  collectionName: ds.Dotstorm.prototype.collectionName


modelFromCollectionName = (collectionName, isCollection=false) ->
  if isCollection
    switch collectionName
      when "Idea" then ds.IdeaList
      when "Dotstorm" then ds.DotstormList
      else null
  else
    switch collectionName
      when "Idea" then ds.Idea
      when "Dotstorm" then ds.Dotstorm
      else null

