getPx = (el, v) -> return parseInt(el.css(v).replace("px", ""))

class ds.Organizer extends Backbone.View
  #
  # Display a list of ideas, and provide UI for grouping them via
  # drag and drop.
  #
  template: _.template $("#dotstormOrganizer").html() or ""
  events:
    'click         .add-link': 'softNav'
    'touchend      .add-link': 'softNav'
    'click              .tag': 'toggleTag'
    'touchend           .tag': 'toggleTag'
    'click            #trash': 'toggleTrash'
    'touchend         #trash': 'toggleTag'
                
    'touchstart   .labelMask': 'nothing'
    'mouseDown    .labelMask': 'nothing'
    'touchstart            a': 'nothing'
    'mousedown             a': 'nothing'
    'touchstart .clickToEdit': 'nothing'
    'mousedown  .clickToEdit': 'nothing'

    'touchstart   .smallIdea': 'startDrag'
    'mousedown    .smallIdea': 'startDrag'
    'touchmove    .smallIdea': 'continueDrag'
    'mousemove    .smallIdea': 'continueDrag'
    'touchend     .smallIdea': 'stopDrag'
    'touchcancel  .smallIdea': 'stopDrag'
    'mouseup      .smallIdea': 'stopDrag'
                 
    'touchstart       .group': 'startDragGroup'
    'mousedown        .group': 'startDragGroup'
    'touchmove        .group': 'continueDragGroup'
    'mousemove        .group': 'continueDragGroup'
    'touchend         .group': 'stopDragGroup'
    'touchcancel      .group': 'stopDragGroup'
    'mouseup          .group': 'stopDragGroup'


  initialize: (options) ->
    #console.debug 'Dotstorm: NEW DOTSTORM'
    @dotstorm = options.model
    # ID of a single note to show, popped out
    @showId = options.showId
    # name of a tag to show, popped out
    @showTag = options.showTag
    @ideas = options.ideas
    @smallIdeaViews = {}

    @dotstorm.on "change:topic", =>
      #console.debug "Dotstorm: topic changed"
      @renderTopic()
    @dotstorm.on "change:name", =>
      #console.debug "Dotstorm: topic changed"
      @renderTopic()
    @dotstorm.on "change:groups", =>
      #console.debug "Dotstorm: grouping changed"
      # This double-calls... but ok!
      @renderGroups()
      @renderTrash()
    @ideas.on "add", =>
      #console.debug "Dotstorm: idea added"
      @renderGroups()
    @ideas.on "change:tags", =>
      @renderTagCloud()

  softNav: (event) =>
    event.stopPropagation()
    event.preventDefault()
    ds.app.navigate $(event.currentTarget).attr("href"), trigger: true
    return false

  nothing: (event) =>
    event.stopPropagation()
    return false

  sortGroups: =>
    # Recursively run through the grouped ideas referenced in the dotstorm sort
    # order, resolving the ids to models, and adding next/prev links to ideas.
    groups = @dotstorm.get("groups")
    prev = null
    linkedGroups = []
    for group in groups
      desc = {
        _id: group._id
        label: group.label
        ideas: []
      }
      for id in group.ideas
        idea = @ideas.get(id)
        idea.prev = prev
        prev.next = idea if prev?
        prev = idea
        desc.ideas.push(idea)
      linkedGroups.push(desc)
    return linkedGroups

  showBig: (model) =>
    # For prev/next navigation, we assume that 'prev' and 'next' have been set
    # on the model for ordering, linked-list style.  This is done by @sortGroups.
    # Without this, prev and next nav buttons just won't show up.
    ds.app.navigate "/d/#{@dotstorm.get("slug")}/#{model.id}"
    if model.prev?
      model.showPrev = => @showBig(model.prev)
    if model.next?
      model.showNext = => @showBig(model.next)
    big = new ds.ShowIdeaBig model: model
    big.on "close", => @showId = null
    @$el.append big.el
    big.render()

  getTags: () =>
    # Return a hash of tags and counts of tags from all ideas in our
    # collection.
    tags = {}
    hasTags = false
    for idea in @ideas.models
      for tag in idea.get("tags") or []
        hasTags = true
        tags[tag] = (tags[tag] or 0) + 1
    if hasTags
      return tags
    return null

  filterByTag: (tag) =>
    if tag?
      ds.app.navigate "/d/#{@dotstorm.get("slug")}/tag/#{tag}"
      cleanedTag = $.trim(tag)
      for noteDom in @$(".smallIdea")
        idea = @ideas.get noteDom.getAttribute('data-id')
        if _.contains (idea.get("tags") or []), cleanedTag
          $(noteDom).removeClass("fade")
        else
          $(noteDom).addClass("fade")
      @$("a.tag").removeClass("active").addClass("inactive")
      @$("a.tag[data-tag=\"#{cleanedTag}\"]").addClass("active").removeClass("inactive")
    else
      ds.app.navigate "/d/#{@dotstorm.get("slug")}/"
      ds.app.updateNavLinks(true, "show-ideas")
      @$(".smallIdea").removeClass("fade")
      @$("a.tag").removeClass("inactive active")

  toggleTag: (event) =>
    tag = event.currentTarget.getAttribute("data-tag")
    if tag == @showTag
      @showTag = null
      @filterByTag()
    else
      @showTag = tag
    @filterByTag(@showTag)
    return false

  toggleTrash: (event) =>
    if @dotstorm.get("trash").length > 0
      $("#trash").toggleClass("open")[0].scrollIntoView()
  
  render: =>
    #console.debug "Dotstorm: RENDER DOTSTORM"
    @$el.html @template
      sorting: true
      slug: @model.get("slug")
    @$el.addClass "sorting"
    @renderTagCloud()
    @renderTopic()
    @renderGroups()
    @renderTrash()
    @renderOverlay()
    $(window).on "mouseup", @stopDrag
    $(".smallIdea").on "touchmove", (event) -> event.preventDefault()
    # iOS needs this.  Argh.
    setTimeout (=> @delegateEvents()), 100
    this

  renderTagCloud: =>
    tags = @getTags()
    max = 0
    min = 100000000000000
    for tag, count of tags
      if count > max
        max = count
      if count < min
        min = count
    minPercent = 70
    maxPercent = 150
    @$(".tag-links").html("")
    for tag, count of tags
      @$(".tag-links").append($("<a/>").attr({
          class: 'tag'
          "data-tag": tag
          href: "/d/#{@model.get("slug")}/tag/#{encodeURIComponent(tag)}"
          style: "font-size: #{minPercent + ((max-(max-(count-min)))*(maxPercent - minPercent) / (max-min))}%"
        }).html( _.escapeHTML tag ), " "
      )

  renderTopic: =>
    @$(".topic").html new ds.Topic(model: @dotstorm).render().el

  renderGroups: =>
    #console.debug "render groups"
    @$("#organizer").html("")
    if @ideas.length == 0
      @$("#organizer").html "To get started, edit the topic or name above, and then add an idea!"
    else
      group_order = @sortGroups()
      _.each group_order, (group, i) =>
        groupView = new ds.ShowIdeaGroup
          position: i
          group: group
          ideaViews: (@getIdeaView(idea) for idea in group.ideas)
        @$("#organizer").append groupView.el
        groupView.render()
        groupView.on "change:label", (group) =>
          @dotstorm.get("groups")[i].label = group.label
          @dotstorm.save null,
            error: (model, err) =>
              console.error("error", err)
              flash "error", "Error saving: #{err}"
          groupView.render()

    @$("#organizer").append("<div style='clear: both;'></div>")

  renderTrash: =>
    @$("#trash .contents").html()
    trash = @dotstorm.get("trash") or []
    _.each trash, (id, i) =>
      idea = @ideas.get(id)
      view = @getIdeaView(idea)
      @$("#trash .contents").append(view.el)
      view.render()
      view.$el.attr("data-idea-position", i)
    if trash.length == 0
      @$("#trash").addClass("empty").removeClass("open")
    else
      @$("#trash").removeClass("empty")

  getIdeaView: (idea) =>
    unless @smallIdeaViews[idea.id]
      view = new ds.ShowIdeaSmall(model: idea)
      @smallIdeaViews[idea.id] = view
    return @smallIdeaViews[idea.id]

  renderOverlay: =>
    if @showId?
      model = @ideas.get(@showId)
      if model? then @showBig model
    else if @showTag?
      @filterByTag(@showTag)
    return this

  getPosition: (event) =>
    pointerObj = event.originalEvent?.touches?[0] or event
    return {
      x: pointerObj.pageX
      y: pointerObj.pageY
    }

  moveNote: =>
    pos = @dragState.lastPos

    # Move the note.
    @dragState.active.css
      position: "absolute"
      left: pos.x + @dragState.mouseOffset.x + "px"
      top: pos.y + @dragState.mouseOffset.y + "px"

    # Clear previous drop target and UI.
    @dragState.dropline.hide()
    @$(".hovered").removeClass("hovered")
    @dragState.currentTarget = null

    # Update current drop target.
    matched = false
    for type in ["join", "adjacent", "create", "ungroup", "trash"]
      for target in @dragState.noteTargets[type]
        if target.onDrag(pos)
          @dragState.currentTarget = target
          break
      if @dragState.currentTarget?
        break
    @dragState.placeholder.toggleClass("active", not @dragState.currentTarget?)

    # Handle edge scrolling.
    scrollTop = $(window).scrollTop()
    if pos.y - scrollTop > @dragState.windowHeight - 10
      $(window).scrollTop(Math.min(
        Math.max(0, @dragState.documentHeight - @dragState.windowHeight),
        scrollTop + 10))
    else if pos.y - scrollTop < 10
      $(window).scrollTop(Math.max(scrollTop - 10, 0))

    return false

  getElementDims: (el) =>
    return {
      el: el
      offset: el.offset()
      margin:
        left: getPx(el, "margin-left")
        right: getPx(el, "margin-right")
        top: getPx(el, "margin-top")
      outerWidth: el.outerWidth(true)
      outerHeight: el.outerHeight(true)
      width: el.width()
      height: el.height()
    }

  getNoteDims: =>
    dims = {
      ideas: []
      groups: []
      window:
        width: $(window).width()
        height: $(window).height()
      document:
        height: $(document).height()
    }
    for el in @$(".idea-browser .smallIdea")
      el = $(el)
      parent = el.parents("[data-group-position]")
      dim = @getElementDims(el)
      dim.el = el
      dim.inGroup = parent.is(".group")
      dim.ideaPos = parseInt(el.attr("data-idea-position"))
      dim.groupPos = parseInt(parent.attr("data-group-position"))
      dims.ideas.push(dim)
    for el in @$(".idea-browser .group")
      el = $(el)
      dim = @getElementDims(el)
      dim.el = el
      dim.ideaPos = null
      dim.groupPos = parseInt(el.attr("data-group-position"))
      dims.groups.push(dim)
    return dims

  buildDropTargets: =>
    targets = {
      adjacent: []
      join: []
      create: []
      ungroup: []
      trash: []
    }
    
    droplineOuterWidth = @dragState.dropline.outerWidth(true)
    droplineExtension = 15
    dims = @getNoteDims()

    # add handlers for combining ideas to create new groups.
    for dim in dims.ideas.concat(dims.groups)
      do (dim) =>
        unless dim.inGroup or @dragState.groupPos == dim.groupPos
          match = (pos) =>
            return (
              dim.offset.top < pos.y < dim.offset.top + dim.height and \
              dim.offset.left < pos.x < dim.offset.left + dim.width
            )
          targets.create.push
            onDrag: (pos) =>
              if match(pos)
                @dragState.dropline.hide()
                dim.el.addClass("hovered")
                return true
              return false
            onDrop: =>
              @dotstorm.move(
                @dragState.groupPos, @dragState.ideaPos,
                dim.groupPos, dim.ideaPos
              )

    # add handlers for consolidated targets for moving.
    moveTargets = {}
    lastGroupPos = 0
    for dim in dims.ideas.concat(dims.groups)
      lastGroupPos = Math.max(lastGroupPos, dim.groupPos)
      ideaPos = if dim.inGroup then dim.ideaPos else null
      left = {
        xlims: if dim.inGroup then [0, 0.5] else [0, 0.3]
        ideaPos: ideaPos
        groupPos: dim.groupPos
        name: 'left'
      }
      right = {
        xlims: if dim.inGroup then [0.5, 1.0] else [0.7, 1.0]
        name: 'right'
      }
      if ideaPos == null
        right.groupPos = dim.groupPos + 1
        right.ideaPos = null
      else
        right.groupPos = dim.groupPos
        right.ideaPos = ideaPos + 1
      for side in [left, right]
        unless moveTargets[side.groupPos]?
          moveTargets[side.groupPos] = {}
        unless moveTargets[side.groupPos][side.ideaPos]?
          moveTargets[side.groupPos][side.ideaPos] = {}
        res = _.extend {
          x1: dim.offset.left + dim.outerWidth * side.xlims[0]
          x2: dim.offset.left + dim.outerWidth * side.xlims[1]
          y1: dim.offset.top
          y2: dim.offset.top + dim.outerHeight
        }, dim
        moveTargets[side.groupPos][side.ideaPos][side.name] = res
    # Extend the drop target on the very last line which extends to the right
    # edge of the window.
    moveTargets[lastGroupPos + 1][null].right.x2 = @dragState.windowWidth

    for groupPos, ideaPosDims of moveTargets
      for ideaPos, dims of ideaPosDims
        groupPos = parseInt(groupPos)
        if ideaPos != "null"
          ideaPos = parseInt(ideaPos)
        else
          ideaPos = null
        doDims = []
        if dims.left? and dims.right?
          # We actually want "right" to be left of "left", because the terms
          # are referring to which side is the active target. 
          # [note --activeright]center[activeleft -- note]
          if dims.right.x2 > dims.left.x1
            # We've wrapped.
            doDims.push(dims.left)
            dims.right.x2 = @dragState.windowWidth
            doDims.push(dims.right)
          else
            # Combine the dims -- remember, right is left of left. Think
            # "leftside active".
            dims.left.x1 = dims.right.x1
            dims.left.y1 = Math.min(dims.left.y1, dims.right.y1)
            dims.left.y2 = Math.max(dims.left.y2, dims.right.y2)
            if dims.right.offset.top < dims.left.offset.top
              dims.left.topOffset = dims.right.offset.top - dims.left.offset.top
            dims.left.outerHeight = Math.max(dims.left.outerHeight, dims.right.outerHeight)
            doDims.push(dims.left)
        else
          doDims.push(dims.left or dims.right)
        for dim in doDims
          do (dim, groupPos, ideaPos) =>
            match = (pos) =>
              ph = @dragState.placeholderDims
              if (ph.x1 <= pos.x <= ph.x2 and ph.y1 <= pos.y <= ph.y2) or \
                 (@dragState.inGroup == false and ideaPos == null and \
                   (groupPos == @dragState.groupPos or \
                    groupPos - 1 == @dragState.groupPos)) or \
                 (@dragState.isGroup == true and \
                   groupPos == @dragState.groupPos) or \
                 (groupPos == @dragState.groupPos and \
                   (ideaPos == @dragState.ideaPos or \
                     ideaPos - 1 == @dragState.ideaPos))
                return false
              return dim.x1 < pos.x < dim.x2 and dim.y1 < pos.y < dim.y2
            if ideaPos == null
              type = "adjacent"
            else
              type = "join"
            targets[type].push
              onDrag: (pos) =>
                if match(pos)
                  dim.el.append(@dragState.dropline)
                  # Right side hack..
                  if (ideaPos == null and groupPos > dim.groupPos) or \
                      (ideaPos != null and ideaPos > dim.ideaPos)
                    leftOffset = dim.outerWidth
                  else
                    leftOffset = 0
                  @dragState.dropline.show().css
                    top: -droplineExtension + (dim.topOffset or 0)
                    left: -droplineOuterWidth / 2 - dim.margin.left + leftOffset
                    height: dim.outerHeight + droplineExtension * 2
                  return true
                return false
              onDrop: =>
                @dotstorm.move(
                  @dragState.groupPos, @dragState.ideaPos, groupPos, ideaPos
                )

    # Trash
    trash = $("#trash")
    trashPos =
      offset: trash.offset()
      outerWidth: trash.outerWidth(true)
      outerHeight: trash.outerHeight(true)
    # Drag into trash
    targets.trash.push {
      onDrag: (pos) =>
        tp = trashPos
        if @dragState.groupPos != null and \
            tp.offset.left < pos.x < tp.offset.left + tp.outerWidth and \
            tp.offset.top < pos.y < tp.offset.top + tp.outerHeight
          trash.addClass("active")
          return true
        else
          trash.removeClass("active")
          return false
      onDrop: =>
        @dotstorm.move(@dragState.groupPos, @dragState.ideaPos, null, null)
    }
    # Drag out of trash (but not into another explicit target)
    targets.trash.push {
      onDrag: (pos) =>
        tp = trashPos
        if @dragState.groupPos == null and not (
            tp.offset.left < pos.x < tp.offset.left + tp.outerWidth and \
            tp.offset.top < pos.y < tp.offset.top + tp.outerHeight)
          return true
        return false
      onDrop: =>
        @dotstorm.move(@dragState.groupPos, @dragState.ideaPos, 0, null)
        $(".smallIdea[data-id=#{@dragState.active.attr("data-id")}]").css({
          "outline-width": "12px"
          "outline-style": "solid"
          "outline-color": "rgba(255, 200, 0, 1.0)"
        }).animate({
          "outline-width": "12px"
          "outline-style": "solid"
          "outline-color": "rgb(255, 255, 255, 0.0)"
        }, 5000, ->
          $(this).css
            "outline-width": ""
            "outline-style": ""
            "outline-color": ""
        )
    }



    return targets


  startDragGroup: (event) => return @startDrag(event)
  startDrag: (event) =>
    event.preventDefault()
    event.stopPropagation()
    active = $(event.currentTarget)
    activeOffset = active.offset()
    activeWidth = active.outerWidth(true)
    activeHeight = active.outerHeight(true)
    @dragState = {
      startTime: new Date().getTime()
      active: active
      offset: active.position()
      targetDims: []
      dropline: $("<div class='dropline'></div>")
      placeholder: $("<div class='placeholder'></div>").css
        float: "left"
        width: (activeWidth) + "px"
        height: (activeHeight) + "px"
      placeholderDims:
        x1: activeOffset.left
        y1: activeOffset.top
        x2: activeOffset.left + activeWidth
        y2: activeOffset.top + activeHeight
      startPos: @getPosition(event)
      windowHeight: $(window).height()
      windowWidth: $(window).width()
      documentHeight: $(document).height()
    }
    @dragState.lastPos = @dragState.startPos
    @dragState.mouseOffset =
      x: @dragState.offset.left - @dragState.startPos.x
      y: @dragState.offset.top - @dragState.startPos.y

    @$(".idea-browser").append(@dragState.dropline)
    @$("#trash").addClass("dragging")
    if @dragState.active.is(".group")
      @dragState.activeParent = @dragState.active
      @dragState.isGroup = true
      @dragState.inGroup = false
    else
      @dragState.activeParent = @dragState.active.parents("[data-group-position]")
      @dragState.isGroup = false
      @dragState.inGroup = @dragState.activeParent.is(".group")
    @dragState.groupPos = parseInt(@dragState.activeParent.attr("data-group-position"))
    if isNaN(@dragState.groupPos)
      @dragState.groupPos = null
    @dragState.ideaPos = parseInt(@dragState.active.attr("data-idea-position"))
    if isNaN(@dragState.ideaPos)
      @dragState.ideaPos = null

    @dragState.noteTargets = @buildDropTargets()

    active.addClass("active")
    @dragState.active.before(@dragState.placeholder)

    @moveNote()

    # Add window as a listener, so if we drag too fast and aren't on top of it
    # any more, we still pull the note along. Remove this again at @stopDrag.
    $(window).on "mousemove", @continueDrag
    $(window).on "touchmove", @continueDrag
    return false

  continueDragGroup: (event) => return @continueDrag(event)
  continueDrag: (event) =>
    if @dragState?
      @dragState.lastPos = @getPosition(event)
      @moveNote()
    return false

  getGroupPosition: ($el) ->
    # Get the group position of the draggable entity (either a group or an
    # idea).  Returns [groupPos, ideaPos or null]
    if $el.hasClass("group")
      return [parseInt($el.attr("data-group-position")), null]
    return [
      parseInt($el.parents("[data-group-position]").attr("data-group-position"))
      parseInt($el.attr("data-idea-position"))
    ]

  stopDragGroup: (event) => @stopDrag(event)
  stopDrag: (event) =>
    event.preventDefault()
    $(window).off "mousemove", @continueDrag
    $(window).off "touchmove", @continueDrag
    @$(".hovered").removeClass("hovered")
    @$("#trash").removeClass("dragging")

    @dragState?.placeholder?.remove()
    @dragState?.dropline?.remove()
    unless @dragState? and @dragState.active?
      return false

    @dragState.active.removeClass("active")
    @dragState.active.css
      position: "relative"
      left: 0
      top: 0

    if (not @dragState.active.is(".group")) and @checkForClick()
      @showBig(@ideas.get(@dragState.active.attr("data-id")))
      return false

    if @dragState.currentTarget?
      @dragState.currentTarget.onDrop()
      @dotstorm.trigger("change:groups")
      @dotstorm.save null, {
        error: (model, err) =>
          console.error("error", err)
          flash "error", "Error saving: #{err}"
      }
    @dragState = null
    return false

  checkForClick: () =>
    # A heuristic for distinguishing clicks from drags, based on time and
    # distance.
    distance = Math.sqrt(
        Math.pow(@dragState.lastPos.x - @dragState.startPos.x, 2) +
        Math.pow(@dragState.lastPos.y - @dragState.startPos.y, 2)
    )
    elapsed = new Date().getTime() - @dragState.startTime
    return distance < 20 and elapsed < 400
