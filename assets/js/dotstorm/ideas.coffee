
getPx = (el, v) -> return parseInt(el.css(v).replace("px", ""))
getBox = (el) ->
  return {
    el: el
    offset: el.offset()
    position: el.position()
    margin:
      top: getPx(el, "margin-top")
      right: getPx(el, "margin-right")
      bottom: getPx(el, "margin-bottom")
      left: getPx(el, "margin-left")
    padding:
      top: getPx(el, "padding-top")
      right: getPx(el, "padding-right")
      bottom: getPx(el, "padding-bottom")
      left: getPx(el, "padding-left")
    border:
      top: getPx(el, "border-top-width")
      right: getPx(el, "border-right-width")
      bottom: getPx(el, "border-bottom-width")
      left: getPx(el, "border-left-width")
    width: el.width()
    height: el.height()
    outerWidth: el.outerWidth(true)
    outerHeight: el.outerHeight(true)
  }
    

class ds.Intro extends Backbone.View
  #
  # A front-page form for opening or creating new dotstorms.
  #
  chars: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890"
  template: _.template $("#intro").html() or ""
  events:
    'submit #named': 'openNamed'
    'submit #random': 'openRandom'
  render: =>
    @$el.html @template()
    this

  openNamed: (event) =>
    name = @$("#id_join").val()
    if name != ''
      slug = ds.Dotstorm.prototype.slugify(name)
      @trigger "open", slug, name
    return false

  openRandom: (event) =>
    randomChar = =>
      @chars.substr parseInt(Math.random() * @chars.length), 1
    slug = (randomChar() for i in [0...12]).join("")
    @trigger "open", slug, ""

    return false

class ds.Topic extends Backbone.View
  #
  # An editor and viewer for a dotstorm "topic" -- just some text that
  # describes an idea.
  #
  template: _.template $("#dotstormTopic").html() or ""
  textareaEditorTemplate: _.template $("#dotstormInPlaceTextarea").html() or ""
  inputEditorTemplate: _.template $("#dotstormInPlaceInput").html() or ""

  events:
    'click .topicEdit .clickToEdit': 'editTopic'
    'submit .topicEdit form': 'saveTopic'
    'click .nameEdit .clickToEdit': 'editName'
    'submit .nameEdit form': 'saveName'
    'click .cancel': 'cancel'

  initialize: (options) ->
    @model = options.model
    @model.on "change", @render

  render: =>
    #console.debug "render topic"
    @$el.html @template
      name: @model.get("name")
      topic: @model.get("topic") or "Click to edit topic..."
      embed_slug: @model.get("embed_slug")
      url: window.location.href
    this

  editName: (event) =>
    $(event.currentTarget).replaceWith @inputEditorTemplate text: @model.get("name")
    return false

  saveName: (event) =>
    event.stopPropagation()
    event.preventDefault()
    val = @$(".nameEdit input[type=text]").val()
    if val == @model.get("name")
      @render()
    else
      @model.save name: val,
        error: (model, err) => flash "error", err
    return false

  editTopic: (event) =>
    $(event.currentTarget).hide().after @textareaEditorTemplate text: @model.get("topic")
    return false

  saveTopic: (event) =>
    val = @$(".topicEdit textarea").val()
    if val == @model.get("topic")
      @render()
    else
      @model.save topic: val,
        error: (model, err) => flash "error", err
    return false

  cancel: (event) =>
    @render()
    return false

class ds.IdeaCanvas extends Backbone.View
  #
  # A canvas element suitable for drawing and recalling drawn ideas.
  #
  tagName: "canvas"
  events:
    'mousedown':  'handleStart'
    'touchstart': 'handleStart'
    'mouseup':    'handleEnd'
    'touchend':   'handleEnd'
    'mousemove':  'handleDrag'
    'touchmove':  'handleDrag'

  initialize: (options) ->
    @idea = options.idea
    # don't listen for changes to @idea.. cuz we're busy drawing!
    @tool = "pencil"
    $(window).on 'mouseup', @handleEnd
    @canvas = @$el

  render: =>
    @ctxDims = @idea.get("dims") or { x: 600, y: 600 }
    @canvas.attr { width: @ctxDims.x, height: @ctxDims.y }

    @ctx = @canvas[0].getContext('2d')
    @actions = @idea.get("drawing")?.slice() or []
    if @idea.get("background")?
      @background = @idea.get("background")
    else
      @$("a.note-color:first").click()
    @redraw()
    # iOS needs this.  Argh.
    setTimeout (=> @delegateEvents()), 100
  
  redraw: =>
    for action in @actions
      @drawAction(action)

  getPointer: (event) =>
    if event.originalEvent.touches?
      touch = event.originalEvent.touches?[0] or event.originalEvent.changedTouches?[0]
      pointerObj = touch
    else
      pointerObj = event
    @pointer =
      x: parseInt((pointerObj.pageX - @offset.left) / @curDims.x * @ctxDims.x)
      y: parseInt((pointerObj.pageY - @offset.top) / @curDims.y * @ctxDims.y)
    return @pointer

  handleStart: (event) =>
    if @disabled then return
    event.preventDefault()
    @offset = @canvas.offset()
    @curDims = { x: @canvas.width(), y: @canvas.height() }
    @mouseIsDown = true
    @getPointer(event)
    @handleDrag(event)
    return false
  handleEnd: (event) =>
    event.preventDefault()
    @mouseIsDown = false
    @pointer = null
    return false
  handleDrag: (event) =>
    if @disabled then return
    event.preventDefault()
    event.stopPropagation()
    if @mouseIsDown
      old = @pointer
      @getPointer(event)
      if old?.x and old.x == @pointer.x and old.y == @pointer.y
        old.x -= 1
      action = [@tool, old?.x, old?.y, @pointer.x, @pointer.y]
      @drawAction(action)
      @actions.push(action)
    return false

  drawAction: (action) =>
    tool = action[0]
    if tool != @lastTool
      switch tool
        when 'pencil'
          @ctx.lineCap = 'round'
          @ctx.lineWidth = 8
          @ctx.strokeStyle = '#000000'
        when 'eraser'
          @ctx.lineCap = 'round'
          @ctx.lineWidth = 32
          @ctx.strokeStyle = @background
      @lastTool = tool

    @ctx.beginPath()
    if action[1]?
      @ctx.moveTo action[1], action[2]
    else
      @ctx.moveTo action[3], action[4]
    @ctx.lineTo action[3], action[4]
    @ctx.stroke()

fillSquare = (el, container, max=600, min=240) ->
  totalHeight = $(window).height()
  totalWidth = $(window).width()
  top = container.position().top
  el.css("height", 0)
  containerHeight = container.outerHeight(true)
  elHeight = Math.min(max, Math.max(min, totalHeight - top - containerHeight))
  elWidth = Math.max(Math.min(totalWidth, elHeight), min)
  elWidth = elHeight = Math.min(elWidth, elHeight)
  el.css
    height: elHeight + "px"
    width: elWidth + "px"
  return [elWidth, elHeight]

class ds.EditIdea extends Backbone.View
  #
  # Container for editing ideas, including a canvas for drawing, a form for
  # adding descriptions and tags, and access to the camera if available.
  #
  template: _.template $("#dotstormAddIdea").html() or ""
  events:
    'submit            form': 'saveIdea'
    'click            .tool': 'changeTool'
    'touchstart       .tool': 'changeTool'
    'click      .note-color': 'handleChangeBackgroundColor'
    'touchstart .note-color': 'handleChangeBackgroundColor'

  initialize: (options) ->
    @idea = options.idea
    @dotstorm = options.dotstorm
    @canvas = new ds.IdeaCanvas {idea: @idea}
    @cameraEnabled = options.cameraEnabled

  render: =>
    @$el.html @template
      longDescription: @idea.get "longDescription"
      description: @idea.get "description"
      tags: @idea.get("tags") or ""
      cameraEnabled: @cameraEnabled
    @changeBackgroundColor @idea.get("background") or @$(".note-color:first").css("background-color")
    @noteTextarea = @$("#id_description")
    @$(".canvas").append(@canvas.el)
    if @idea.get("photoURLs")?.full
      photo = $("<img/>").attr(
        src: @idea.get("photoURLs").full
        alt: "Loading..."
      ).css("width", "100%")
      photo.on "load", -> photo.attr "alt", "photo thumbnail"
      @$(".photo").html photo

    @canvas.render()
    @tool = 'pencil'
    #
    # Canvas size voodoo
    #
    $(window).on "resize", @resize
    @resize()
    this

  resize: =>
    [width, height] = fillSquare(@$(".canvasHolder"), @$el, 600, 160)
    @$el.css "min-width", width + "px"
    @$(".canvasHolder textarea").css "fontSize", (height / 10) + "px"

  setPhoto: (imageData) =>
    @photo = imageData
    @$(".photo").html $("<img/>").attr(
      "src", "data:image/jpg;base64," + @photo
    ).css({width: "100%"})

  saveIdea: =>
    ideaIsNew = not @idea.id?
    attrs = {
      dotstorm_id: @dotstorm.id
      description: $("#id_description").val()
      tags: @idea.cleanTags($("#id_tags").val())
      background: @canvas.background
      dims: @canvas.ctxDims
      drawing: @canvas.actions
      editor: ds.users?.self?.user_id
      photoData: @photo
    }
    @idea.save(attrs, {
      success: (model) =>
        if ideaIsNew
          @dotstorm.addIdea(model, silent: true)
          @dotstorm.save null, {
            error: (model, err) =>
              console.error "error", err
              flash "error", "Error saving: #{err}"
          }
          ds.ideas.add(model)
        ds.app.navigate "/d/#{@dotstorm.get("slug")}/#{model.id}", trigger: true
      error: (model, err) ->
        console.error("error", err)
        str = err.error?.message
        flash "error", "Error saving: #{str}. See log for details."
    })
    return false

  changeTool: (event) =>
    event.preventDefault()
    event.stopPropagation()
    el = $(event.currentTarget)
    tool = el.attr("data-tool")
    if tool == "camera"
      @trigger "takePhoto"
      el = @$(".tool[data-tool=text]")
      tool = "text"
    if tool == "text"
      @$(".text").before(@$(".canvas"))
    else
      @$(".text").after(@$(".canvas"))
      @canvas.tool = tool
    @$(".tool").removeClass("active")
    el.addClass("active")
    return false

  handleChangeBackgroundColor: (event) =>
    @changeBackgroundColor $(event.currentTarget).css("background-color")
    return false

  changeBackgroundColor: (color) =>
    @canvas.background = color
    @$(".canvasHolder").css "background", @canvas.background

class ds.ShowIdeaGroup extends Backbone.View
  template: _.template $("#dotstormSmallIdeaGroup").html() or ""
  editTemplate: _.template $("#dotstormSmallIdeaGroupEditLabel").html() or ""
  events:
    'click   .label': 'editLabel'
    'click  .cancel': 'cancelEdit'
    'submit    form': 'saveLabel'

  initialize: (options) ->
    @group = options.group
    @ideaViews = options.ideaViews
    @position = options.position

  editLabel: (event) =>
    unless @editing
      event.stopPropagation()
      event.preventDefault()
      @editing = true
      $(event.currentTarget).html @editTemplate
        label: @group.label or ""
      @$("input[type=text]").select()

  cancelEdit: (event) =>
    event.stopPropagation()
    event.preventDefault()
    @editing = false
    @render()
    return false
  
  saveLabel: (event) =>
    event.stopPropagation()
    event.preventDefault()
    @editing = false
    @group.label = @$("input[type=text]").val()
    @trigger "change:label", @group
    return false

  render: =>
    @$el.html @template
      showGroup: @ideaViews.length > 1
      label: @group.label
      group_id: @group._id
    @$el.addClass("masonry")
    if @ideaViews.length > 1
      @$el.addClass("group")
    @$el.attr({
      "data-group-id": @group._id
      "data-group-position": @position
    })
    container = @$(".ideas")
    container.css("height", "100%")
    _.each @ideaViews, (view, i) =>
      container.append view.el
      view.$el.attr("data-idea-position", i)
      view.render()
    # HACK: Obsessive hack for equal margins of children -- depends on:
    #  - 14px smallIdeaMargin
    #  - 4px encroachment from group
    # This is duplicated from assets/css/style.styl
#    if @ideaViews.length > 1
#      totalMargin = (14 * @ideaViews.length - 4) * 2
#      space = parseInt(totalMargin / (@ideaViews.length + 1))
#      @$(".smallIdea").css
#        marginLeft: (space / 2) + "px"
#        marginRight: (space / 2) + "px"
#      @$(".smallIdea:first").css "marginLeft", space + "px"
#      @$(".smallIdea:last").css "marginRight", space + "px"
#    else
#      @$(".smallIdea").css
#        marginLeft: "5px"
#        marginRight: "5px"
#    this


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
      groupPos = parseInt(
        el.parents("[data-group-position]").attr("data-group-position")
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
      if group == @dragState.activeParent[0]
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

class ds.ShowIdeaSmall extends Backbone.View
  template: _.template $("#dotstormSmallIdea").html() or ""
  initialize: (options) ->
    @model = options.model
    @size = options.size or "medium"
    @model.on "change:tags", @render
    @model.on "change:imageVersion", @render
    @model.on "change:description", @render
    @model.on "change:photo", @render

  render: =>
    args = _.extend
      tags: []
      description: ""
    , @model.toJSON()
    @$el.html @template args
    @$el.attr("data-id", @model.id)
    @$el.addClass("smallIdea")
    @renderVotes()

  renderVotes: =>
    @$(".votes").html new ds.VoteWidget({
      idea: @model
      self: ds.users.self
      readOnly: true
      hideOnZero: true
    }).render().el

class ds.ShowIdeaBig extends Backbone.View
  template: _.template $("#dotstormBigIdea").html() or ""
  editorTemplate: _.template $("#dotstormInPlaceInput").html() or ""
  events:
    'mousedown .shadow': 'close'
    'touchstart .shadow': 'close'

    'mousedown .close': 'close'
    'touchstart .close': 'close'

    'mousedown .next': 'next'
    'touchstart .next': 'next'

    'mousedown .prev': 'prev'
    'touchstart .prev': 'prev'

    'mousedown .edit': 'edit'
    'touchstart .edit': 'edit'

    'click .tags .clickToEdit': 'editTags'
    'submit .tags form': 'saveTags'

    'mousedown .note': 'nothing'
    'touchstart .note': 'nothing'

  initialize: (options) ->
    @model = options.model
    @model.on "change:description", @render
    @model.on "change:tags", @render
    @model.on "change:background", @render
    @model.on "change:drawing", @render
    @model.on "change:photo", @render

  render: =>
    #console.debug "render big", @model.get "imageVersion"
    args = _.extend {
      tags: []
      description: ""
      hasNext: @model.showNext?
      hasPrev: @model.showPrev?
    }, @model.toJSON()
    @$el.html @template args
    @$el.addClass("bigIdea")
    resize = =>
      [width, height] = fillSquare(@$(".canvasHolder"), @$(".note"), 600, 200)
      @$(".text").css "font-size", (height / 10) + "px"
      @$(".note").css "max-width", width + "px"
      # Hack for mobile lack of position:fixed.  Not working yet...
      @$(".shadow").css
        position: "absolute"
        top: $("html,body").scrollTop() + 'px'
        minHeight: window.innerHeight
    @$(".canvasHolder img").on "load", resize
    resize()
    @renderVotes()
    $(window).on "resize", resize
    this

  renderVotes: =>
    @$(".vote-widget").html new ds.VoteWidget(idea: @model, self: ds.users.self).render().el

  close: (event) =>
    if event?
      event.preventDefault()
      event.stopPropagation()
    @trigger "close", this
    @$el.remove()
    ds.app.navigate "/d/#{ds.model.get("slug")}/"
    ds.app.updateNavLinks(true, "show-ideas")
    return false

  nothing: (event) =>
    event.stopPropagation()
    #event.preventDefault()

  next: (event) =>
    event.stopPropagation()
    @close()
    @model.showNext() if @model.showNext?
    return false

  prev: (event) =>
    event.stopPropagation()
    @close()
    @model.showPrev() if @model.showPrev?
    return false

  edit: (event) =>
    event.stopPropagation()
    event.preventDefault()
    ds.app.navigate "/d/#{ds.model.get("slug")}/edit/#{@model.id}",
      trigger: true
    return false

  editTags: (event) =>
    event.stopPropagation()
    @$(event.currentTarget).replaceWith @editorTemplate
      text: (@model.get("tags") or []).join(", ")
    @$("input[type=text]").select()
    return false

  saveTags: (event) =>
    val = @$(".tags input[type=text]").val()
    @model.save {tags: @model.cleanTags(val)}, {
      success: (model) =>
      error: (model, err) =>
        console.error "error", err
        flash "error", err
    }
    return false

class ds.VoteWidget extends Backbone.View
  template: _.template $("#dotstormVoteWidget").html() or ""
  events:
    'touchstart .upvote': 'toggleVote'
    'mousedown .upvote': 'toggleVote'
  initialize: (options) ->
    @idea = options.idea
    @idea.on "change:votes", @render
    @self = options.self
    @readOnly = options.readOnly
    @hideOnZero = options.hideOnZero
    if @readOnly
      @undelegateEvents()

  render: =>
    #console.debug "render votewidget", @idea.id
    @$el.addClass("vote-widget")
    votes = @idea.get("votes") or []
    @$el.html @template
      votes: votes.length
      youVoted: _.contains votes, @self?.user_id
      readOnly: @readOnly
    if @hideOnZero
      if votes.length == 0 then @$el.hide() else @$el.show()
    this

  toggleVote: (event) =>
    event.stopPropagation()
    event.preventDefault()
    if @self?.user_id?
      # Must copy array; otherwise change events don't fire properly.
      votes = @idea.get("votes")?.slice() or []
      pos = _.indexOf votes, @self.user_id
      if pos == -1
        votes.push @self.user_id
      else
        votes.splice(pos, 1)
      @idea.save {votes: votes},
        error: (model, err) =>
          console.error "error", err
          flash "error", "Error saving vote: #{err}"
    return false
