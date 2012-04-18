#= require lib/jquery
#= require lib/jquery.cookie
#= require lib/underscore
#= require lib/underscore-autoescape
#= require lib/backbone
#= require flash
#= require iorooms.client
#= require backbone-socket.client
#= require models

# Console log safety.
if typeof console == 'undefined'
  @console = {log: (->), error: (->), debug: (->)}

#
# Our namespace: ds.
#
if not window.ds?
  ds = window.ds = {}

getQueryStrParameterByName = (name) ->
  # Get url query parameter by name.
  # http://stackoverflow.com/questions/901115/get-query-string-values-in-javascript
  match = RegExp('[?&]' + name + '=([^&]*)').exec(window.location.search)
  return match && decodeURIComponent(match[1].replace(/\+/g, ' '))


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
    flash "error", "Warning: this is pre-alpha software. Data is periodically deleted without warning."
    @$el.html @template()
    this

  openNamed: (event) =>
    name = @$("#id_join").val()
    if name != ''
      ds.app.open(name)
    return false

  openRandom: (event) =>
    randomChar = =>
      @chars.substr parseInt(Math.random() * @chars.length), 1
    name = (randomChar() for i in [0...12]).join("")
    ds.app.open(name)
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
    console.debug "render topic"
    @$el.html @template
      name: @model.get("name")
      topic: @model.get("topic") or "Click to edit topic..."
      url: window.location.href
    this

  editName: (event) =>
    $(event.currentTarget).hide().after @inputEditorTemplate text: @model.get("name")
    return false

  saveName: (event) =>
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
  containerHeight = container.outerHeight()
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
    'click .sizes a': 'resize'
    'click .add-link': 'softNav'
    'click .sort': 'handleSort'
    'click .tag': 'toggleTag'
    'mousedown  .smallIdea': 'startDrag'
    'mouseup    .smallIdea': 'stopDrag'
    'touchstart .smallIdea': 'startDrag'
    'touchend   .smallIdea': 'stopDrag'

  sizes:
    small: 78
    medium: 118
    large: 238

  initialize: (options) ->
    console.debug 'Dotstorm: NEW DOTSTORM'
    @dotstorm = options.model
    # ID of a single note to show, popped out
    @showId = options.showId
    # name of a tag to show, popped out
    @showTag = options.showTag
    @ideas = options.ideas
    @smallIdeaViews = {}

    @dotstorm.on "change:topic", =>
      console.debug "Dotstorm: topic changed"
      @renderTopic()
    @dotstorm.on "change:name", =>
      console.debug "Dotstorm: topic changed"
      @renderTopic()
    @dotstorm.on "change:ideas", =>
      console.debug "Dotstorm: grouping changed"
      @renderGroups()
    @ideas.on "add", =>
      console.debug "Dotstorm: idea added"
      @renderGroups()
    @ideas.on "sort", =>
      console.debug "Dotstorm: sorted", @sort
      @renderGroups()
    @ideas.on "change:order", =>
      console.debug "Dostorm: sorted", @sort
      if @orderChangeTimeout
        clearTimeout @orderChangeTimeout
      @orderChangeTimeout = setTimeout (=> @renderGroups()), 200
    $(window).on "mouseup", @stopDrag

  softNav: (event) =>
    ds.app.navigate $(event.currentTarget).attr("href"), trigger: true
    return false

  setSort: (sort, options) =>
    @sort = sort or getQueryStrParameterByName('sort')
    switch @sort
      when "date"
        @ideas.comparator = (model) -> return model.get("created")
      when "-date"
        @ideas.comparator = (model) -> return -model.get("created")
      when "votes"
        @ideas.comparator = (model) -> return model.get("votes")?.length or 0
      when "-votes"
        @ideas.comparator = (model) -> return -(model.get("votes")?.length or 0)
      when "-drop"
        @ideas.comparator = (model) -> return -(model.get("order") or 0)
      else
        @ideas.comparator = (model) -> return model.get("order")
    @ideas.sort()
    @ideas.trigger "sort" unless options?.silent
    @$(".sort").removeClass("active reverse")
    if @sort?.substring(0, 1) == "-"
      sort = @sort.substring(1)
      reverse = true
    else
      sort = @sort
      reverse = false
    target = @$("a[data-sort=\"#{sort}\"]")
    target.addClass("active")
    if reverse then target.addClass("reverse")
    if @sort?
      ds.app.navigate window.location.pathname + "?sort=#{@sort}", trigger: false

  handleSort: (event) =>
    sort = $(event.currentTarget).attr("data-sort")
    if @sort? and @sort == sort
      sort = "-#{sort}"
    @setSort sort
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
      cleanedTag = Idea.prototype.cleanTag(tag)
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
      updateNavLinks()
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
  
  resize: (event) =>
    size = $(event.currentTarget).attr("data-size")
    @$(".smallIdea").css
      width: @sizes[size] + "px"
      height: @sizes[size] + "px"
    return false

  render: =>
    console.debug "Dotstorm: RENDER DOTSTORM"
    @$el.html @template
      sorting: true
      slug: @model.get("slug")
    @$el.addClass "sorting"
    @renderTagCloud()
    @renderTopic()
    @setSort() #@renderGroups() -- triggered by sort
    @renderOverlay()

  renderTagCloud: =>
    tags = @getTags()
    max = 0
    min = 100000000000000
    for tag, count of tags
      if count > max
        max = count
      else if count < min
        min = count
    minPercent = 70
    maxPercent = 150
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
    console.debug "render groups"
    @$("#showIdeas").html("")
    if @ideas.length == 0
      @$("#showIdeas").html "To get started, edit the topic or name above, and then <a href='add'>add an idea</a>!"
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
    for dim in @dragState.noteDims
      if dim.el[0] == @dragState.active[0]
        continue
      dim.el.removeClass("hovered leftside rightside")
      if dim.top < pos.y < dim.top + dim.height
        if dim.left < pos.x < dim.left + dim.width * 0.2
          dim.el.addClass("leftside")
        if dim.left + dim.width * 0.2 < pos.x < dim.left + dim.width * 0.8
          dim.el.addClass("hovered")
        if dim.left + dim.width * 0.8 < pos.x < dim.left + dim.width
          dim.el.addClass("rightside")
    return false

  startDrag: (event) =>
    event.preventDefault()
    event.stopPropagation()
    active = $(event.currentTarget)
    active.addClass("active")
    @dragState = {
      startTime: new Date().getTime()
      active: active
      offset: active.position()
      noteDims: []
      placeholder: $("<div></div>").css
        float: "left"
        width: active.outerWidth(true) + "px"
        height: active.outerHeight(true) + "px"
      dropTagrets: []
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
    @dragState.active.before(@dragState.placeholder)
    @moveNote()
    $(window).on "mousemove", @continueDrag
    $(window).on "touchmove", @continueDrag
    return false

  continueDrag: (event) =>
    event.preventDefault()
    event.stopPropagation()
    if @dragState?
      @dragState.lastPos = @getPosition(event)
      @moveNote()
    return false

  stopDrag: (event) =>
    event.preventDefault()
    event.stopPropagation()
    $(window).off "mousemove", @continueDrag
    $(window).off "touchmove", @continueDrag

    # reset drag UI...
    @dragState?.placeholder?.remove()
    unless @dragState? and @dragState.active?
      return
    @dragState.active.removeClass("active")
    @dragState.active.css
      position: "relative"
      left: 0
      top: 0

    # Check for drop targets.
    sourceId = @dragState.active.attr("data-id")
    leftside = @$(".leftside")
    rightside = @$(".rightside")
    hovered = @$(".hovered")
    @$(".smallIdea").removeClass("leftside rightside hovered")

    if @checkForClick()
      @showBig @ideas.get(sourceId)
      @dragState = null
      return

    droppable = hovered[0] or leftside[0] or rightside[0]
    if droppable?
      targetId = droppable.getAttribute("data-id")
      if leftside[0]?
        @dotstorm.putLeftOf(sourceId, targetId)
      else if rightside[0]?
        @dotstorm.putRightOf(sourceId, targetId)
      else
        @dotstorm.groupify(sourceId, targetId)
      @dotstorm.save null, error: (err) => flash "error", "Error saving: #{err}"
      @dotstorm.trigger "change:ideas"
    else
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
            @dotstorm.ungroup(sourceId, true)
          else
            @dotstorm.ungroup(sourceId)
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
    console.debug "render small", @model.id
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
    'click .shadow': 'close'
    'click .close': 'close'
    'click .next': 'next'
    'click .prev': 'prev'
    'click .edit': 'edit'

    'click .tags .clickToEdit': 'editTags'
    'submit .tags form': 'saveTags'

    'click .description .clickToEdit': 'editDescription'
    'submit .description form': 'saveDescription'

    'click .cancel': 'cancel'

    'click .note': 'nothing'

  initialize: (options) ->
    @model = options.model
    @model.on "change:description", @render
    @model.on "change:tags", @render
    @model.on "change:background", @render
    @model.on "change:drawing", @render
    @model.on "change:photo", @render

  render: =>
    console.debug "render big"
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
    @$(".canvasHolder img").on "load", resize
    resize()
    @renderVotes()

    $(window).on "resize", resize
    this

  renderVotes: =>
    @$(".vote-widget").html new ds.VoteWidget(idea: @model, self: ds.users.self).render().el

  cancel: (event) =>
    @render()
    return false

  close: (event) =>
    event.stopPropagation()
    event.preventDefault()
    @trigger "close", this
    @$el.remove()
    ds.app.navigate "/d/#{ds.model.get("slug")}/"
    updateNavLinks()
    return false

  nothing: (event) =>
    event.stopPropagation()
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
    event.stopPropagation()
    @model.save {tags: @$(".tags input[type=text]").val()},
      error: (model, err) => flash "error", err
    return false

  editDescription: (event) =>
    event.stopPropagation()
    @$(event.currentTarget).replaceWith @editorTemplate text: @model.get("description") or ""
    return false

  saveDescription: (event) =>
    event.stopPropagation()
    @model.save {description: @$(".description textarea").val()},
      error: (model, err) => flash "error", err
    return false

class ds.VoteWidget extends Backbone.View
  template: _.template $("#dotstormVoteWidget").html() or ""
  events:
    'click .upvote': 'toggleVote'
  initialize: (options) ->
    @idea = options.idea
    @idea.on "change:votes", @render
    @self = options.self
    @readOnly = options.readOnly
    @hideOnZero = options.hideOnZero
    if @readOnly
      @undelegateEvents()

  render: =>
    console.debug "render votewidget", @idea.id
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

updateNavLinks = ->
  if window.location.pathname == "/"
    $("nav").hide()
  else
    $("nav").show()
  $("nav a").each ->
    href = $(@).attr('href')
    if window.location.pathname == href
      $(@).addClass("active")
    else
      $(@).removeClass("active")

class ds.UsersView extends Backbone.View
  template: _.template $("#usersWidget").html() or ""
  events:
    'click .users': 'toggle'
    'keyup .you input': 'changeName'

  initialize: (options) ->
    @self = options.users.self
    @users = options.users.others
    @open = false
    @url = options.url

  render: =>
    userlist = _.reject (u for i,u of @users), (u) => u.user_id == @self.user_id
    @$el.html @template
      self: @self
      users: userlist
      open: @open
      url: @url
    this

  toggle: (event) =>
    @open = not @open
    @render()
    return false

  changeName: (event) =>
    @self.name = $(event.currentTarget).val()
    if @updateTimeout?
      clearTimeout @updateTimeout
    @updateTimeout = setTimeout =>
      ds.client.setName @self.name
    , 500
    return false

  removeUser: (user) =>
    #TODO: something smarter when we have actual users.
    delete @users[user.user_id]
    @render()

  addUser: (user) =>
    if user.user_id != @self.user_id
      @users[user.user_id] = user
    @render()

  setUser: (user) =>
    @users[user.user_id] = user
    @render()

class ds.Router extends Backbone.Router
  routes:
    'd/:slug/add':        'dotstormAddIdea'
    'd/:slug/edit/:id':   'dotstormEditIdea'
    'd/:slug/tag/:tag':   'dotstormShowTag'
    'd/:slug/:id':        'dotstormShowIdeas'
    'd/:slug/':           'dotstormShowIdeas'
    'd/:slug': ->         'addSlash'
    '':                   'intro'

  intro: ->
    updateNavLinks()
    $("#app").html new ds.Intro().render().el

  addSlash: (slug) => return ds.app.navigate "/d/#{slug}/", trigger: true

  dotstormShowIdeas: (slug, id, tag) =>
    updateNavLinks()
    @open slug, ->
      $("#app").html new ds.ShowIdeas({
        model: ds.model
        ideas: ds.ideas
        showId: id
        showTag: tag
      }).render().el
    return false

  dotstormShowTag: (slug, tag) =>
    @dotstormShowIdeas(slug, null, tag)

  dotstormAddIdea: (slug) =>
    updateNavLinks()
    @open slug, ->
      view = new ds.EditIdea
        idea: new Idea
        dotstorm: ds.model
        cameraEnabled: ds.cameraEnabled
      if ds.cameraEnabled
        view.on "takePhoto", =>
          flash "info", "Calling camera..."
          handleImage = (event) ->
            if event.origin == "file://" and event.data.image?
              view.setPhoto(event.data.image)
            window.removeEventListener "message", handleImage, false
          window.addEventListener 'message', handleImage, false
          window.parent.postMessage('camera', 'file://')
      $("#app").html view.el
      view.render()
    return false

  dotstormEditIdea: (slug, id) =>
    updateNavLinks()
    @open slug, ->
      idea = ds.ideas.get(id)
      if not idea?
        flash "error", "Idea not found.  Check the URL?"
      else
        # Re-fetch to pull in deferred fields.
        idea.fetch
          success: (idea) =>
            view = new ds.EditIdea(idea: idea, dotstorm: ds.model)
            $("#app").html view.el
            view.render()
    return false

  open: (name, callback) =>
    # Open (if it exists) or create a new dotstorm with the name `name`, and
    # navigate to its view.
    slug = Dotstorm.prototype.slugify(name)
    unless callback?
      # force refresh to get new template.
      callback = =>
        ds.app.navigate "/d/#{slug}/"
        @dotstormShowIdeas(slug)

    if ds.model?.get("slug") == slug
      return callback()

    $("nav a.show-ideas").attr("href", "/d/#{slug}/")
    $("nav a.add").attr("href", "/d/#{slug}/add")
    coll = new DotstormList
    coll.fetch
      query: { slug }
      success: (coll) ->
        if coll.length == 0
          new Dotstorm().save { name, slug },
            success: (model) ->
              flash "info", "Created!  Click things to change them."
              ds.joinRoom(model, true, callback)
            error: (model, err) ->
              flash "error", err
        else if coll.length == 1
          ds.joinRoom(coll.models[0], false, callback)
        else
          flash "error", "Ouch. Something broke. Sorry."
      error: (coll, res) => flash "error", res.error
    return false

ds.joinRoom = (newModel, isNew, callback) ->
  if ds.model? and ds.client? and ds.model.id != newModel.id
    ds.client.leave ds.model.id
  if ds.model?.id != newModel.id
    ds.client.join newModel.id
  ds.model = newModel
  ds.ideas = new IdeaList
  if isNew
    # Nothing else to fetch yet -- we're brand spanking new.
    return callback()
  ds.ideas.fetch
    error: (coll, err) -> flash "error", "Error fetching #{attr}."
    success: (coll) -> callback?()
    query: {dotstorm_id: ds.model.id}
    fields: {drawing: 0}

# 
# Socket data!!!!!!!!!!!!!!
#
ds.socket = io.connect("/io", reconnect: false)
Backbone.setSocket(ds.socket)
ds.app = new ds.Router
ds.socket.on 'connect', ->
  ds.client = new Client(ds.socket)
  Backbone.history.start pushState: true
  ds.socket.on 'users', (data) ->
    console.debug "users", data
    ds.users = new ds.UsersView
      users: data
      url: "#{window.location.protocol}//#{window.location.host}/d/#{ds.model.get("slug")}/"
    $("#auth").html ds.users.el
    ds.users.render()
  ds.socket.on 'user_left', (user) ->
    ds.users?.removeUser(user)
  ds.socket.on 'user_joined', (user) ->
    ds.users?.addUser(user)
  ds.socket.on 'username', (user) ->
    ds.users?.setUser(user)

  ds.socket.on 'backbone', (data) ->
    console.debug 'backbone sync', data
    switch data.signature.collectionName
      when "Idea"
        switch data.signature.method
          when "create"
            ds.ideas.add(new Idea(data.model))
          when "update"
            model = ds.ideas.get(data.model._id)
            if model?
              model.set(data.model)
            else
              ds.ideas.fetch({fields: drawing: 0})
          when "delete"
            model = ds.ideas.get(data.model._id)
            if model?
              ds.ideas.remove(model)
            else
              ds.ideas.fetch({fields: drawing: 0})

      when "Dotstorm"
        switch data.signature.method
          when "update"
            ds.model.set data.model

  ds.socket.on 'trigger', (data) ->
    console.debug 'trigger', data
    switch data.collectionName
      when "Idea"
        ds.ideas.get(data.id).trigger data.event

ds.socket.on 'disconnect', ->
  # Timeout prevents a flash when you are just closing a tab.
  setTimeout ->
    flash "error", "Connection lost.  <a href=''>Click to reconnect</a>."
  , 500

window.addEventListener 'message', (event) ->
  if event.origin == "file://"
    if event.data.cameraEnabled?
      ds.cameraEnabled = true
    else if event.data.error?
      flash "info", event.data.error
    else if event.data.reload?
      flash "info", "Reloading..."
      window.location.reload(true)
, false

$("nav a").on 'click', (event) ->
  ds.app.navigate $(event.currentTarget).attr('href'), trigger: true
  return false


# Debug:
do ->
  # Add a widget to the window showing the current size in pixels.
  $(window).on 'resize', ->
    $('#size').html $(window).width() + " x " + $(window).height()
  $(window).resize()

