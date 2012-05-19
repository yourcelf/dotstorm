getPx = (el, v) -> return parseInt(el.css(v).replace("px", ""))

class ds.Organizer extends Backbone.View
  #
  # Display a list of ideas, and provide UI for grouping them via
  # drag and drop.
  #
  template: _.template $("#dotstormOrganizer").html() or ""
  events:
    'click         .add-link': 'softNav'
    'click              .tag': 'toggleTag'
                
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
    @ideas.on "add", =>
      #console.debug "Dotstorm: idea added"
      @renderGroups()
    @ideas.on "change:tags", =>
      @renderTagCloud()

  softNav: (event) =>
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
  
  render: =>
    #console.debug "Dotstorm: RENDER DOTSTORM"
    @$el.html @template
      sorting: true
      slug: @model.get("slug")
    @$el.addClass "sorting"
    @renderTagCloud()
    @renderTopic()
    @renderGroups()
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
    @dragState.active.css
      position: "absolute"
      left: pos.x + @dragState.mouseOffset.x + "px"
      top: pos.y + @dragState.mouseOffset.y + "px"
    @dragState.currentTarget = null
    @dragState.dropline.hide()
    @$(".hovered").removeClass("hovered")
    for target in @dragState.targetDims
      if target.box.x1 <= pos.x < target.box.x2 and target.box.y1 <= pos.y < target.box.y2
        # Avoid next-door neighbors which don't change position (not in a group)
        if target.ideaPos == null and ((target.right == 0 and target.groupPos == @dragState.groupPos + 1) or (target.right == 1 and target.groupPos == @dragState.groupPos - 1))
          continue
        # Avoid next-door neighbors which don't change position (in a group)
        if target.groupPos == @dragState.groupPos and ((target.right == 0 and target.ideaPos == @dragState.ideaPos + 1) or (target.right == 1 and target.ideaPos == @dragState.ideaPos - 1))
          continue
        if target.dropline?
          target.el.append(@dragState.dropline)
          @dragState.dropline.show().css
            left: target.dropline.left + "px"
            top: target.dropline.top + "px"
            height: target.dropline.height + "px"
        else
          target.el.addClass("hovered")
        @dragState.currentTarget = target
        break
    unless @dragState.currentTarget?
      # Are we breaking the group?
      bg = @dragState.breakGroup
      if bg?
        unless bg.box.x1 <= pos.x < bg.box.x2 and bg.box.y1 <= pos.y < bg.box.y2
          target = @dragState.currentTarget = @dragState.breakGroup
          target.el.append(@dragState.dropline)
          @dragState.dropline.show().css
            left: target.dropline.left + "px"
            top: target.dropline.top + "px"
            height: target.dropline.height + "px"

    scrollTop = $(window).scrollTop()
    if pos.y - scrollTop > @dragState.windowHeight - 10
      $(window).scrollTop(Math.min(
        Math.max(0, @dragState.documentHeight - @dragState.windowHeight),
        scrollTop + 10))
    else if pos.y - scrollTop < 10
      $(window).scrollTop(Math.max(scrollTop - 10, 0))
    return false

  startDragGroup: (event) => return @startDrag(event)
  startDrag: (event) =>
    event.preventDefault()
    event.stopPropagation()
    active = $(event.currentTarget)
    activeOffset = active.offset()
    activeWidth = active.outerWidth(true)
    activeHeight = active.outerHeight(true)
    @dragState = {
      windowHeight: $(window).height()
      documentHeight: $(document).height()
      startTime: new Date().getTime()
      active: active
      offset: active.position()
      targetDims: []
      dropline: $("<div class='dropline'></div>")
      placeholder: $("<div></div>").css
        float: "left"
        width: (activeWidth) + "px"
        height: (activeHeight) + "px"
      placeholderDims:
        x1: activeOffset.left
        y1: activeOffset.top
        x2: activeOffset.left + activeWidth
        y2: activeOffset.top + activeHeight
      startPos: @getPosition(event)
    }
    @dragState.lastPos = @dragState.startPos
    @dragState.mouseOffset =
      x: @dragState.offset.left - @dragState.startPos.x
      y: @dragState.offset.top - @dragState.startPos.y

    @$(".idea-browser").append(@dragState.dropline)
    if @dragState.active.is(".group")
      @dragState.activeParent = @dragState.active
    else
      @dragState.activeParent = @dragState.active.parents("[data-group-position]")
    @dragState.groupPos = parseInt(@dragState.activeParent.attr("data-group-position"))
    @dragState.ideaPos = parseInt(@dragState.active.attr("data-idea-position"))
    if isNaN(@dragState.ideaPos)
      @dragState.ideaPos = null

    ###################################################
    # Set up drop targets
    #

    # Note adjacencies
    droplineOuterWidth = @dragState.dropline.outerWidth(true)
    droplineExtension = 15
    for el in @$(".smallIdea")
      if el == @dragState.active[0]
        continue
      el = $(el)
      ideaPos = parseInt(el.attr("data-idea-position"))
      parent = el.parents("[data-group-position]")
      if parent[0] == @dragState.active[0]
        continue
      groupPos = parseInt(
        parent.attr("data-group-position")
      )
      inGroup = @dotstorm.get("groups")[groupPos].ideas.length > 1
      offset = el.offset()
      outerWidthMargin = el.outerWidth(true)
      outerHeightMargin = el.outerHeight(true)
      outerHeight = el.outerHeight(false)
      # Left side
      @dragState.targetDims.push
        el: el
        box:
          x1: offset.left
          x2: offset.left + outerWidthMargin * (if inGroup then 0.5 else 0.2)
          y1: offset.top
          y2: offset.top + outerHeightMargin
        right: 0
        groupPos: groupPos
        ideaPos: if inGroup then ideaPos else null
        dropline:
          top: -droplineExtension
          left: -droplineOuterWidth / 2 - getPx(el, "margin-left") - 1
          height: outerHeight + droplineExtension * 2
      # Right side
      @dragState.targetDims.push
        el: el
        box:
          x1: offset.left + outerWidthMargin * (if inGroup then 0.5 else 0.8)
          x2: offset.left + outerWidthMargin
          y1: offset.top
          y2: offset.top + outerHeightMargin
        right: 1
        groupPos: groupPos
        ideaPos: if inGroup then ideaPos else null
        dropline:
          top: -droplineExtension
          left: el.outerWidth(false) - droplineOuterWidth / 2 + getPx(el, "margin-right")
          height: outerHeight + droplineExtension * 2
      unless inGroup
        # center
        @dragState.targetDims.push
          el: el
          box:
            x1: offset.left + outerWidthMargin * 0.2
            x2: offset.left + outerWidthMargin * 0.8
            y1: offset.top
            y2: offset.top + outerHeightMargin
          right: 0
          groupPos: groupPos
          ideaPos: ideaPos
          dropline: null

    # Group adjacencies
    for group in @$(".group")
      if group == @dragState.active[0]
        continue
      group = $(group)
      ideaPos = parseInt(
        group.find(".smallIdea:first").attr("data-idea-position")
      )
      groupPos = parseInt(group.attr("data-group-position"))
      offset = group.offset()
      pos = group.position()
      width = group.width()
      outerWidthMargin = group.outerWidth(true)
      outerHeight = group.outerHeight(false)
      outerHeightMargin = group.outerHeight(true)
      # Left of group
      @dragState.targetDims.push
        el: group
        box:
          x1: offset.left
          x2: offset.left + outerWidthMargin * 0.2
          y1: offset.top
          y2: offset.top + outerHeightMargin
        right: 0
        groupPos: groupPos
        ideaPos: null
        dropline:
          top: -droplineExtension
          left: -droplineOuterWidth / 2 - getPx(group, "margin-left")
          height: outerHeight + droplineExtension * 2
      
      # Right of group
      @dragState.targetDims.push
        el: group
        box:
          x1: offset.left + outerWidthMargin * 0.8
          x2: offset.left + outerWidthMargin
          y1: offset.top
          y2: offset.top + outerHeightMargin
        right: 1
        groupPos: groupPos
        ideaPos: null
        dropline:
          top: -droplineExtension
          left: group.outerWidth(false) + getPx(group, "margin-right") - droplineOuterWidth/2
          height: outerHeight + droplineExtension*2

      # Center
      unless group[0] == @dragState.activeParent[0]
        @dragState.targetDims.push
          el: group
          box:
            x1: offset.left + outerWidthMargin * 0.2
            x2: offset.left + outerWidthMargin * 0.8
            y1: offset.top
            y2: offset.top + outerHeightMargin
          right: 0
          groupPos: groupPos
          ideaPos: 0
          dropline: null

    # Pulling out of a group
    if (not @dragState.active.is(".group")) and @dragState.activeParent.is(".group")
      # Inverse target for breaking group
      el = @dragState.activeParent
      offset = el.offset()
      @dragState.breakGroup =
        el: el
        box:
          x1: offset.left
          x2: offset.left + el.outerWidth(false)
          y1: offset.top
          y2: offset.top + el.outerHeight(false)
        right: 1
        groupPos: el.attr("data-group-position")
        ideaPos: null
        dropline:
          top: -droplineExtension
          left: el.outerWidth(false) + getPx(el, "margin-right") - droplineOuterWidth/2
          height: el.outerHeight(true) + droplineExtension*2
    
    # Done setting up drop targets
    ###################################

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
      sourceIdeaPos = parseInt(
        @dragState.active.attr("data-idea-position")
      )
      if isNaN(sourceIdeaPos)
        sourceIdeaPos = null
      sourceGroupPos = parseInt(
        @dragState.activeParent.attr("data-group-position")
      )
      @dotstorm.move(
        sourceGroupPos, sourceIdeaPos,
        @dragState.currentTarget.groupPos,
        @dragState.currentTarget.ideaPos,
        @dragState.currentTarget.right
      )
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
