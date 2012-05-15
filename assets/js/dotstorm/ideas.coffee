

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
      ds.app.open slug, name, =>
        ds.app.navigate "/d/#{slug}/"
        ds.app.dotstormShowIdeas(slug)
    return false

  openRandom: (event) =>
    randomChar = =>
      @chars.substr parseInt(Math.random() * @chars.length), 1
    slug = (randomChar() for i in [0...12]).join("")
    ds.app.open slug, "", =>
        ds.app.navigate "/d/#{slug}/"
        @dotstormShowIdeas(slug)

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
    'mouseup':    'handleEnd'
    'mousemove':  'handleDrag'

    'touchstart': 'handleStart'
    'touchend':   'handleEnd'
    'touchmove':  'handleDrag'

  initialize: (options) ->
    @idea = options.idea
    # don't listen for changes to @idea.. cuz we're busy drawing!
    @tool = "pencil"
    if options.readOnly == true
      @events = undefined
    $(window).on 'mouseup', @handleEnd
    @canvas = @$el

  render: =>
    @ctxDims = @idea.get("dims") or {
      x: 600
      y: 600
    }

    @canvas.attr
      width:  @ctxDims.x
      height: @ctxDims.y

    @ctx = @canvas[0].getContext('2d')
    @actions = @idea.get("drawing")?.slice() or []
    if @idea.get("background")?
      @background = @idea.get("background")
    else
      @$("a.note-color:first").click()
    @redraw()
    # iOS needs this.  Argh.
    setTimeout (=> @delegateEvents()), 100
  
  redraw: () =>
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
    'submit form':       'saveIdea'

    'click .tablinks a': 'tabnav'
    'click .tool': 'changeTool'
    'touchstart .tool': 'changeTool'
    'click .note-color': 'handleChangeBackgroundColor'
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
    if @idea.get("photoVersion")?
      photo = $("<img/>").attr(
        src: @idea.getPhotoURL("full")
        alt: "Loading..."
      ).css("width", "100%")
      photo.on "load", -> photo.attr "alt", "photo thumbnail"
      @$(".image").html photo

    @canvas.render()
    @tool = 'pencil'
    #
    # Canvas size voodoo
    #
    canvasHolder = @$(".canvasHolder")
    resize = =>
      [width, height] = fillSquare(canvasHolder, @$el, 600, 160)
      @$el.css "min-width", width + "px"
      @$(".canvasHolder textarea").css "fontSize", (height / 10) + "px"
    $(window).on "resize", resize
    resize()
    this

  tabnav: (event) =>
    link = @$(event.currentTarget)
    tabgroup = link.parents(".tabgroup:first")
    @$(".tab.active, .tablinks a.active", tabgroup).removeClass("active")
    @$(link.attr("href"), tabgroup).addClass("active")
    link.addClass("active")
    return false

  setPhoto: (imageData) =>
    @photo = imageData
    @$(".image").html $("<img/>").attr(
      "src", "data:image/jpg;base64," + @photo
    ).css({width: "100%"})

  saveIdea: =>
    ideaIsNew = not @idea.id?
    
    # prepare attributes...
    if (@idea.get("drawing") != @canvas.actions or
          @idea.get("background") != @canvas.background)
      @idea.incImageVersion()
    if @photo?
      @idea.incPhotoVersion()
    attrs = {
      dotstorm_id: @dotstorm.id
      description: $("#id_description").val()
      tags: $("#id_tags").val()
      background: @canvas.background
      dims: @canvas.ctxDims
      drawing: @canvas.actions
      editor: ds.users?.self?.user_id
    }
    if ideaIsNew
      attrs.creator = ds.users?.self?.user_id
      attrs.order = ds.ideas.length

    @idea.save attrs,
      success: (model) =>
        if ideaIsNew
          @dotstorm.addIdea(model.id, silent: true)
          @dotstorm.save null, error: (err) => flash "error", "Error saving: #{err}"
        if ideaIsNew
          ds.ideas.add(model)
        finish = ->
          ds.app.navigate "/d/#{ds.model.get("slug")}/#{model.id}", trigger: true
        if @photo?
          # Upload photo
          responseHandle = "img#{new Date().getTime()}"
          flash "info", "Uploading photo..."
          ds.socket.emit "uploadPhoto",
            idea: model.toJSON()
            imageData: @photo
            event: responseHandle
          ds.socket.once responseHandle, (data) =>
            if data.error?
              flash "error", "Error uploading image: #{data.error}"
            @idea.save(null) # trigger reloads now that image is done.
            finish()
        else
          finish()
      error: (model, err) ->
        console.error(err)
        str = if err.error? then err.error else err
        flash "error", "Error saving: #{str}"

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

  editLabel: (event) =>
    $(event.currentTarget).replaceWith @editTemplate
      label: @group.label or ""
    @$("input[type=text]").select()
    return false

  cancelEdit: (event) =>
    @render()
    return false
  
  saveLabel: (event) =>
    @group.label = @$("input[type=text]").val()
    @trigger "change:label", @group
    return false

  render: =>
    @$el.html @template
      label: @group.label
    @$el.addClass("group")
    container = @$(".ideas")
    for view in @ideaViews
      container.append view.el
    this

class ds.ShowIdeas extends Backbone.View
  #
  # Display a list of ideas, and provide UI for grouping them via
  # drag and drop.
  #
  template: _.template $("#dotstormShowIdeas").html() or ""
  events:
    'click .add-link': 'softNav'
    'click .tag': 'toggleTag'

    'touchstart  .smallIdea': 'startDrag'
    'mousedown   .smallIdea': 'startDrag'
    'touchmove   .smallIdea': 'continueDrag'
    'mousemove   .smallIdea': 'continueDrag'
    'touchend    .smallIdea': 'stopDrag'
    'touchcancel .smallIdea': 'stopDrag'
    'mouseup     .smallIdea': 'stopDrag'

    'touchstart      .group': 'startDragGroup'
    'mousedown       .group': 'startDragGroup'
    'touchmove       .group': 'continueDragGroup'
    'mousemove       .group': 'continueDragGroup'
    'touchend        .group': 'stopDragGroup'
    'mouseup         .group': 'stopDragGroup'


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
    @dotstorm.on "change:ideas", =>
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

  sortGroups: (_model_ids, _prev) =>
    # Recursively run through the grouped ideas referenced in the dotstorm sort
    # order, resolving the ids to models, and adding next/prev links to ideas.
    _model_ids or _model_ids = @dotstorm.get("ideas")
    groups = []
    for id_or_obj in _model_ids
      if id_or_obj.ideas?
        ideas = @sortGroups(id_or_obj.ideas, _prev)
        groups.push {
          label: id_or_obj.label
          ideas: ideas
        }
        _prev = ideas.prev
      else
        idea = @ideas.get(id_or_obj)
        groups.push idea
        if _prev?
          idea.prev = _prev
          idea.prev.next = idea
        _prev = idea
    groups.prev = _prev
    return groups

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
      taglist = idea.getTags()
      for tag in taglist
        hasTags = true
        tags[tag] = (tags[tag] or 0) + 1
    if hasTags
      return tags
    return null

  filterByTag: (tag) =>
    if tag?
      ds.app.navigate "/d/#{@dotstorm.get("slug")}/tag/#{tag}"
      cleanedTag = ds.Idea.prototype.cleanTag(tag)
      regex = new RegExp("(^|,)\\s*(#{cleanedTag})\\s*(,|$)")
      for noteDom in @$(".smallIdea")
        idea = @ideas.get noteDom.getAttribute('data-id')
        match = regex.exec(idea.get("tags"))
        if not match?
          $(noteDom).addClass("fade")
        else
          $(noteDom).removeClass("fade")
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
    @$("#showIdeas").html("")
    if @ideas.length == 0
      @$("#showIdeas").html "To get started, edit the topic or name above, and then add an idea!"
    else
      group_order = @sortGroups()
      for entity in group_order
        if entity.ideas?
          groupView = new ds.ShowIdeaGroup
            group: entity
            ideaViews: (@getIdeaView(idea) for idea in entity.ideas)
          @$("#showIdeas").append groupView.el
          groupView.render()
          groupView.on "change:label", (group) =>
            @dotstorm.setLabelFor(group.ideas[0].id, group.label)
            @dotstorm.save null,
              error: (err) => flash "error", "Error saving: #{err}"
            groupView.render()
        else
          @$("#showIdeas").append @getIdeaView(entity).el
    @$("#showIdeas").append("<div style='clear: both;'></div>")

  getIdeaView: (idea) =>
    unless @smallIdeaViews[idea.id]
      view = new ds.ShowIdeaSmall(model: idea)
      view.render()
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

  moveNote: () =>
    pos = @dragState.lastPos
    @dragState.active.css
      position: "absolute"
      left: pos.x + @dragState.mouseOffset.x + "px"
      top: pos.y + @dragState.mouseOffset.y + "px"
    ph = @dragState.placeholderDims
    inPlaceHolder = ph.x1 < pos.x < ph.x2 and ph.y1 < pos.y < ph.y2
    # Skip drop targets if were inside the placeholder. 
    inIdea = false
    $(".smallIdea, .group").removeClass("hovered leftside rightside")
    for dim in @dragState.noteDims.concat(@dragState.groupDims)
      if dim.el[0] == @dragState.active[0] or inPlaceHolder
        continue
      if dim.top < pos.y < dim.top + dim.height
        if dim.left < pos.x < dim.left + dim.width * 0.2
          dim.el.addClass("leftside")
          return false
        if dim.left + dim.width * 0.2 < pos.x < dim.left + dim.width * 0.8
          dim.el.addClass("hovered")
          return false
        if dim.left + dim.width * 0.8 < pos.x < dim.left + dim.width
          dim.el.addClass("rightside")
          return false
    return false

  startDragGroup: (event) => return @startDrag(event)
  startDrag: (event) =>
    event.preventDefault()
    event.stopPropagation()
    active = $(event.currentTarget)
    activeOffset = active.offset()
    activeWidth = active.outerWidth(true)
    activeHeight = active.outerHeight(true)
    active.addClass("active")
    @dragState = {
      startTime: new Date().getTime()
      active: active
      offset: active.position()
      noteDims: []
      groupDims: []
      placeholder: $("<div></div>").css
        float: "left"
        width: activeWidth + "px"
        height: activeHeight + "px"
      placeholderDims:
        x1: activeOffset.left
        y1: activeOffset.top
        x2: activeOffset.left + activeWidth
        y2: activeOffset.top + activeHeight
    }
    @dragState.lastPos = @dragState.startPos = @getPosition(event)
    @dragState.mouseOffset =
      x: @dragState.offset.left - @dragState.startPos.x
      y: @dragState.offset.top - @dragState.startPos.y
    for note in @$(".smallIdea")
      $n = $(note)
      dims = $n.offset()
      dims.width = $n.width()
      dims.height = $n.height()
      dims.el = $n
      @dragState.noteDims.push(dims)
    for group in @$(".group")
      $g = $(group)
      dims = $g.offset()
      dims.width = $g.outerWidth(true)
      dims.height = $g.outerHeight(true)
      dims.el = $g
      @dragState.groupDims.push(dims)
    @dragState.active.before(@dragState.placeholder)
    @moveNote()
    # Add window as a listener, so if we drag too fast, we still pull the note
    # along. Remove this again in @stopDrag.
    $(window).on "mousemove", @continueDrag
    $(window).on "touchmove", @continueDrag
    return false

  continueDragGroup: (event) => return @continueDrag(event)
  continueDrag: (event) =>
    if @dragState?
      @dragState.lastPos = @getPosition(event)
      @moveNote()
    return false

  clearDragUI: (event) =>
    event.preventDefault()
    $(window).off "mousemove", @continueDrag
    $(window).off "touchmove", @continueDrag

    # reset drag UI...
    @dragState?.placeholder?.remove()
    unless @dragState? and @dragState.active?
      return false
    @dragState.active.removeClass("active")
    @dragState.active.css
      position: "relative"
      left: 0
      top: 0
    
    # Check for drop targets.
    dropTarget =
      leftside: @$(".leftside")[0]
      rightside: @$(".rightside")[0]
      hovered: @$(".hovered")[0]
      sourceId: @dragState.active.attr("data-id")
      sourceIsGroup: false

    if not dropTarget.sourceId?
      dropTarget.sourceId = @dragState.active.find(".smallIdea:first").attr("data-id")
      dropTarget.sourceIsGroup = true

    droppable = dropTarget.hovered or dropTarget.leftside or dropTarget.rightside
    if droppable?
      dropTarget.targetId = droppable.getAttribute("data-id")
      dropTarget.targetIsGroup = false
      if not dropTarget.targetId
        dropTarget.targetId = $(droppable).find(".smallIdea:first").attr("data-id")
        dropTarget.targetIsGroup = true

    @$(".smallIdea, .group").removeClass("leftside rightside hovered")
    return dropTarget

  stopDragGroup: (event) => @stopDrag(event)
  stopDrag: (event) =>
    dropTarget = @clearDragUI(event)
    unless dropTarget
      return

    if (not dropTarget.sourceIsGroup) and @checkForClick()
      @showBig @ideas.get(dropTarget.sourceId)
      @dragState = null
      return

    if dropTarget.targetId? or dropTarget.groupTargetId?
      if dropTarget.hovered
        @dotstorm.combine(
          dropTarget.sourceId,
          dropTarget.sourceIsGroup,
          dropTarget.targetId,
          dropTarget.targetIsGroup,
          false
        )
      else
        @dotstorm.move(
          dropTarget.sourceId,
          dropTarget.sourceIsGroup,
          dropTarget.targetId,
          dropTarget.targetIsGroup,
          dropTarget.rightside?
        )
      @dotstorm.save null, error: (err) => flash "error", "Error saving: #{err}"
    else if (not dropTarget.sourceIsGroup)
      # Are we being dragged out of our current group?
      groupParent = @dragState.active.parents(".group:first")
      if groupParent[0]?
        pos = @dragState.lastPos
        dims = groupParent.offset()
        dims.width = groupParent.width()
        dims.height = groupParent.height()
        unless dims.left < pos.x < dims.left + dims.width and dims.top < pos.y < dims.top + dims.height
          # We've been dragged out.
          if pos.x > dims.left + dims.width * 0.5
            @dotstorm.ungroup(dropTarget.sourceId, true)
          else
            @dotstorm.ungroup(dropTarget.sourceId)
          @dotstorm.save null, error: (err) => flash "error", "Error saving: #{err}"
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
    #console.debug "render small", @model.id
    args = _.extend
      tags: ""
      description: ""
    , @model.toJSON()
    @$el.html @template args
    @$el.attr("data-id", @model.id)
    @$el.addClass("smallIdea")
    @$el.css backgroundColor: @model.get("background")
    resize = =>
      @$(".text").css "fontSize", (@$(".canvasHolder").height() / 10) + "px"
    resize()
    if @model.get("imageVersion")?
      drawing = $("<img/>").attr
        src: @model.getThumbnailURL(@size)
        alt: "Loading..."
      drawing.on "load", ->
        drawing.attr "alt", "drawing thumbnail"
        resize()
      @$(".canvas").html drawing
    if @model.get("photoVersion")?
      photo = $("<img/>").attr
        src: @model.getPhotoURL(@size)
        alt: "Loading..."
      photo.on "load", ->
        photo.attr "alt", "photo thumbnail"
      @$(".image").html photo
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

    'submit .tags form': 'saveTags'
    'click .tags .clickToEdit': 'editTags'

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
    #console.debug "render big"
    args = _.extend {
      tags: ""
      description: ""
      hasNext: @model.showNext?
      hasPrev: @model.showPrev?
    }, @model.toJSON()
    @$el.html @template args
    @$el.addClass("bigIdea")
    @$(".canvasHolder").css backgroundColor: @model.get("background")
    if @model.get("imageVersion")?
      drawing = $("<img/>").attr
        src: @model.getThumbnailURL("full")
        alt: "Loading..."
      drawing.on "load", -> drawing.attr "alt", "drawing thumbnail"
      @$(".canvas").html drawing
    if @model.get("photoVersion")?
      photo = $("<img/>").attr
        src: @model.getPhotoURL("full")
        alt: "Loading..."
      photo.on "load", -> photo.attr "alt", "photo thumbnail"
      @$(".image").html photo
    resize = =>
      [width, height] = fillSquare(@$(".canvasHolder"), @$(".note"), 600, 200)
      @$(".text").css "font-size", (height / 10) + "px"
      @$(".note").css "max-width", width + "px"
      # Hack for mobile lack of position:fixed
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
    if event.tagName.lower() == "input"
      return
    event.stopPropagation()
    event.preventDefault()
    return false

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
    @$(event.currentTarget).replaceWith @editorTemplate text: @model.get("tags") or ""
    return false

  saveTags: (event) =>
    @model.save {tags: @$(".tags input[type=text]").val()},
      error: (model, err) => flash "error", err
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
          flash "error", "Error saving vote: #{err}"
    return false
