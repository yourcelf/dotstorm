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
    @model.on "change", =>
      @render()
      @delegateEvents()

  render: =>
    @$el.html @template
      name: @model.get("name")
      topic: @model.get("topic") or "Click to edit topic..."
      url: window.location.href
    this

  editName: (event) =>
    $(event.currentTarget).hide().after @inputEditorTemplate text: @model.get("name")

  saveName: (event) =>
    val = @$(".nameEdit input[type=text]").val()
    if val == @model.get("name")
      @render()
    else
      @model.save name: val,
        error: (model, err) => flash "error", err

  editTopic: (event) =>
    $(event.currentTarget).hide().after @textareaEditorTemplate text: @model.get("topic")

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
    if @idea.get("drawing")?
      @actions = @idea.get("drawing")
    else
      @actions = []
    if @idea.get("background")?
      @background = @idea.get("background")
    else
      @$("a.note-color:first").click()
    @redraw()
  
  redraw: () =>
    #@ctx.fillStyle = @background
    #@ctx.beginPath()
    #@ctx.fillRect(0, 0, @ctxDims.x, @ctxDims.y)
    #@ctx.fill()
    #@ctx.closePath()
    #@lastTool = null
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

  render: =>
    @$el.html @template
      longDescription: @idea.get "longDescription"
      description: @idea.get "description"
      tags: @idea.get("tags") or ""
      camera: navigator?.camera?
    @changeBackgroundColor @idea.get("background") or @$(".note-color:first").css("background-color")
    @noteTextarea = @$("#id_description")
    @$(".canvas").append(@canvas.el)
    @canvas.render()
    @tool = 'pencil'
    #
    # Canvas size voodoo
    #
    canvasHolder = @$(".canvasHolder")
    resize = =>
      [width, height] = fillSquare(canvasHolder, @$el, 600, 160)
      @$el.css "min-width", width + "px"
      @$(".canvasHolder textarea").css
        fontSize: (height / 10) + "px"
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

  saveIdea: =>
    ideaIsNew = not @idea.id?
    @idea.save {
      dotstorm_id: @dotstorm.id
      description: $("#id_description").val()
      tags: $("#id_tags").val()
      background: @canvas.background
      dims: @canvas.ctxDims
      drawing: @canvas.actions
    }, {
      success: (model) ->
        if ideaIsNew
          ds.ideas.add(model)
        ds.app.navigate "/d/#{ds.model.get("slug")}/#{model.id}", trigger: true
      error: (model, err) ->
        console.log(err)
        str = if err.error? then err.error else err
        flash "error", "Error saving: #{str}"
    }
    return false

  changeTool: (event) =>
    event.preventDefault()
    event.stopPropagation()
    el = $(event.currentTarget)
    tool = el.attr("data-tool")
    if tool == "text"
      @$(".text").before(@$(".canvas"))
    else
      @$(".text").after(@$(".canvas"))
      @canvas.tool = tool
    el.parent().find(".tool").removeClass("active")
    el.addClass("active")

  handleChangeBackgroundColor: (event) =>
    @changeBackgroundColor $(event.currentTarget).css("background-color")
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
    @ideas = options.ideas

  editLabel: (event) =>
    $(event.currentTarget).replaceWith @editTemplate
      label: @group.get("label") or ""
    @$("input[type=text]").select()

  cancelEdit: (event) =>
    @render()
  
  saveLabel: (event) =>
    @group.set "label", @$("input[type=text]").val()
    @render()
    @group.save {},
      error: (model, err) =>
        flash "error", "Error saving group: #{err}"
        @render()
    return false

  render: =>
    if @group?
      @$el.html @template
        label: @group.get('label')
      container = @$(".ideas")
      @$el.attr("data-id", @group.id)
      @$el.addClass("group")
    else
      container = @$el
    for model in @ideas
      idea = new ds.ShowIdeaSmall(model: model)
      container.append idea.el
      idea.render()
      do (model) => idea.$el.on 'click', => @trigger "ideaClicked", model
    this

class ds.ShowIdeas extends Backbone.View
  #
  # Display a list of ideas, and provide UI for sorting and grouping them via
  # drag and drop.
  #
  template: _.template $("#dotstormShowIdeas").html() or ""
  events:
    'click .sizes a': 'resize'
    'click .sort-link': 'softNav'
    'mousedown  .smallIdea': 'startDrag'
    'mousemove  .smallIdea': 'continueDrag'
    'mouseup    .smallIdea': 'stopDrag'
    'touchstart .smallIdea': 'startDrag'
    'touchmove  .smallIdea': 'continueDrag'
    'touchend   .smallIdea': 'stopDrag'

  sizes:
    small: 78
    medium: 118
    large: 238

  initialize: (options) ->
    @dotstorm = options.model
    # ID of a single note to show, popped out
    @showId = options.showId
    @ideas = options.ideas
    @groups = options.groups

    @dotstorm.on "change", @render
    @ideas.on "change", =>
      @render()
    @groups.on "change", =>
      @render()

    @topic = new ds.Topic(model: @dotstorm)

    $(window).on "mouseup", @stopDrag

  softNav: (event) =>
    ds.app.navigate $(event.currentTarget).attr("href"), trigger: true
    return false

  sortGroups: =>
    grouped = {}
    for group in @groups.models
      for id in group.get("ideas")
        grouped[id] = true
    ungrouped = []
    for idea in @ideas.models
      unless grouped[idea.id]?
        ungrouped.push(idea)

    # Get linked list for next/previous, and sort models into an array of
    # groups.
    model_order = []
    group_order = []
    count = 0
    for group in @groups.models
      group_set = group: group, models: []
      for id in group.get('ideas')
        idea = @ideas.get(id)
        if count > 0
          idea.prev = model_order[count - 1]
          idea.prev.next = idea
        model_order.push(idea)
        group_set.models.push(idea)
        count += 1
      group_order.push(group_set)
    for idea in ungrouped
      if count > 0
        idea.prev = model_order[count - 1]
        idea.prev.next = idea
      model_order.push(idea)
      count += 1
    group_order.push({ models: ungrouped })
    return group_order

  showBig: (model) =>
    # For prev/next navigation, we assume that 'prev' and 'next' have been set
    # on the model for ordering, linked-list style.  This is done by @sortGroups.
    # Without this, prev and next nav buttons just won't show up.
    ds.app.navigate "/d/#{ds.model.get("slug")}/#{model.id}"
    if model.prev?
      model.showPrev = => @showBig(model.prev)
    if model.next?
      model.showNext = => @showBig(model.next)
    big = new ds.ShowIdeaBig model: model
    big.on "close", => @showId = null
    @$el.append big.el
    big.render()
  
  resize: (event) =>
    size = $(event.currentTarget).attr("data-size")
    @$(".smallIdea").css
      width: @sizes[size] + "px"
      height: @sizes[size] + "px"

  render: =>
    @$el.html @template
      sorting: true
      slug: @model.get("slug")
      url: "#{window.location.protocol}//#{window.location.host}/d/#{@model.get("slug")}/"
    @$el.addClass "sorting"
    @$(".topic").html @topic.render().el

    group_order = @sortGroups()
    if @ideas.length == 0
      @$("#showIdeas").html "To get started, edit the topic or name above, and then <a href='add'>add an idea</a>!"
    for group in group_order
      groupView = new ds.ShowIdeaGroup group: group.group, ideas: group.models
      @$("#showIdeas").append groupView.el
      groupView.render()
    if @showId?
      model = @ideas.get(@showId)
      if model? then @showBig model
    this

  getPosition: (event) =>
    pointerObj = event.originalEvent?.touches?[0] or event
    return {
      x: pointerObj.pageX
      y: pointerObj.pageY
    }

  moveNote: (event) =>
    pos = @getPosition(event)
    @active.css
      position: "absolute"
      left: pos.x + @mouseOffset.x + "px"
      top: pos.y + @mouseOffset.y + "px"
      zIndex: 10
      opacity: 0.8
    for dim in @noteDims
      if dim.left < pos.x < dim.left + dim.width and dim.top < pos.y < dim.top + dim.height
        $(dim.el).addClass("hovered")
      else
        $(dim.el).removeClass("hovered")

  startDrag: (event) =>
    event.preventDefault()
    event.stopPropagation()
    @maybeClick = true
    setTimeout =>
      @maybeClick = false
    , 150
    $(event.currentTarget).addClass("active")
    @mouseIsDown = true
    @active = $(event.currentTarget)
    @placeholder = $("<div class='smallIdea'></div>").css
      width: @active.width() + "px",
      height: @active.height() + "px"

    pos = @getPosition(event)
    offset = @active.position()
    @mouseOffset =
      x: offset.left - pos.x
      y: offset.top - pos.y
    @noteDims = []
    for note in @$(".smallIdea")
      $n = $(note)
      dims = $n.offset()
      dims.width = $n.width()
      dims.height = $n.height()
      dims.el = $n
      @noteDims.push(dims)
    @active.before(@placeholder)
    @moveNote(event)

  continueDrag: (event) =>
    event.preventDefault()
    event.stopPropagation()
    if @mouseIsDown
      @moveNote(event)

  stopDrag: (event) =>
    event.preventDefault()
    event.stopPropagation()
    $(event.currentTarget).removeClass("active")
    # reset drag UI...
    @placeholder?.remove()
    @mouseIsDown = false
    @noteDims = []
    @mouseOffset = null
    unless @active?
      return
    @active.css
      position: "relative"
      left: 0
      top: 0
      zIndex: "auto"
      opacity: 1
    @active = null

    hovered = @$(".hovered")
    dragged = $(event.currentTarget)
    source = @ideas.get dragged.attr("data-id")
    if @maybeClick == true
      @showBig(source)
      return
    unless source?
      return
    if hovered[0]? and hovered[0] != event.currentTarget
      #
      # Are we being dragged into a group?
      #
      target = @ideas.get hovered.attr("data-id")
      targetGroup = null
      for group in @groups.models
        unless group?
          continue
        if $.inArray(target.id, group.get("ideas")) != -1
          targetGroup = group
        # Remove old group, if any
        source_group_index = $.inArray(source.id, group.get("ideas"))
        if group.removeIdea(source.id) and group.get("ideas").length > 0
          group.save {},
            error: (model, err) =>
              flash "error", "Error saving group: #{err}"
              @render()
        else if group.get("ideas").length == 0
          group.destroy
            error: (model, err) =>
              flash "error", "Error removing group: #{err}"
              @render()

      unless targetGroup?
        targetGroup = new IdeaGroup dotstorm_id: @dotstorm.id
        @groups.add(targetGroup)

      ideas = targetGroup.get("ideas") or []
      targetGroup.addIdea(source.id)
      targetGroup.addIdea(target.id)
      targetGroup.save {},
        error: (model, err) =>
          flash "error", "Error saving group: #{err}"
          @render()
      @render()
    else
      #
      # Are we being dragged out of all groups?
      #
      groupParent = dragged.parents(".group:first")
      if groupParent.length == 1 and groupParent.attr("data-id")?
        pos = @getPosition(event)
        dims = groupParent.offset()
        dims.width = groupParent.width()
        dims.height = groupParent.height()
        unless dims.left < pos.x < dims.left + dims.width and dims.top < pos.y < dims.top + dims.height
          # We've been dragged out. Extricate ourselves from our group.
          group = @groups.get(groupParent.attr("data-id"))
          if group.removeIdea(source.id) and group.get("ideas").length > 0
            group.save {},
              error: (model, err) =>
                flash "error", "Error saving group: #{err}"
                @render()
          else if group.get("ideas").length == 0
            group.destroy
              error: (model, err) =>
                flash "error", "Error removing group: #{err}"
                @render()
          @render()

class ds.ShowIdeaSmall extends Backbone.View
  template: _.template $("#dotstormSmallIdea").html() or ""
  initialize: (options) ->
    @model = options.model
    @size = options.size or "medium"

  render: =>
    args = _.extend
      tags: ""
      description: ""
    , @model.toJSON()
    @$el.html @template args
    @$el.attr("data-id", @model.id)
    @$el.addClass("smallIdea")
    @$el.css backgroundColor: @model.get("background")
    img = $("<img/>").attr
      src: @model.getThumbnailURL(@size)
      alt: "Loading..."
    resize = =>
      @$(".text").css
        fontSize: @$(".canvasHolder").height() / 10 + "px"
    img.on "load", ->
      img.attr "alt", "drawing thumbnail"
      resize()
    @$(".canvas").html img
    this

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

  render: =>
    args = _.extend {
      tags: ""
      description: ""
      hasNext: @model.showNext?
      hasPrev: @model.showPrev?
    }, @model.toJSON()
    @$el.html @template args
    @$el.addClass("bigIdea")
    @$el.css backgroundColor: @model.get("background")
    img = $("<img/>").attr
      src: @model.getThumbnailURL("full")
      alt: "Loading..."
    @$(".canvas").html(img)
    resize = =>
      [width, height] = fillSquare(@$(".canvasHolder"), @$(".note"), 600, 200)
      @$(".text").css "font-size", (height / 10) + "px"
      @$(".note").css "max-width", width + "px"
    @$(".canvasHolder img").on "load", resize
    resize()
    $(window).on "resize", resize
    this

  cancel: (event) =>
    @render()

  close: (event) =>
    @trigger "close", this
    @$el.remove()
    ds.app.navigate "/d/#{ds.model.get("slug")}/"

  nothing: (event) =>
    event.stopPropagation()

  next: (event) =>
    @close()
    @model.showNext() if @model.showNext?

  prev: (event) =>
    @close()
    @model.showPrev() if @model.showPrev?

  edit: (event) =>
    ds.app.navigate "/d/#{ds.model.get("slug")}/edit/#{@model.id}",
      trigger: true

  editTags: (event) =>
    @$(event.currentTarget).replaceWith @editorTemplate text: @model.get("tags") or ""

  saveTags: (event) =>
    @model.save {tags: @$(".tags input[type=text]").val()},
      error: (model, err) => flash "error", err
    return false

  editDescription: (event) =>
    @$(event.currentTarget).replaceWith @editorTemplate text: @model.get("description") or ""
  saveDescription: (event) =>
    @model.save {description: @$(".description textarea").val()},
      error: (model, err) => flash "error", err
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

  render: =>
    userlist = _.reject (u for i,u of @users), (u) => u.user_id == @self.user_id
    @$el.html @template
      self: @self
      users: userlist
      open: @open
    this

  toggle: (event) =>
    @open = not @open
    @render()

  changeName: (event) =>
    @self.name = $(event.currentTarget).val()
    if @updateTimeout?
      clearTimeout @updateTimeout
    @updateTimeout = setTimeout =>
      ds.client.setName @self.name
    , 500

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
    'd/:slug/:id':        'dotstormShowIdeas'
    'd/:slug/':           'dotstormShowIdeas'
    'd/:slug': ->         'addSlash'
    '':                   'intro'

  intro: ->
    updateNavLinks()
    $("#app").html new ds.Intro().render().el

  addSlash: (slug) => return ds.app.navigate "/d/#{slug}/", trigger: true

  dotstormShowIdeas: (slug, id) =>
    updateNavLinks()
    @open slug, ->
      $("#app").html new ds.ShowIdeas(model: ds.model, ideas: ds.ideas, groups: ds.groups, showId: id).render().el
    return false

  dotstormAddIdea: (slug) =>
    updateNavLinks()
    @open slug, ->
      view = new ds.EditIdea(idea: new Idea, dotstorm: ds.model)
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
      callback = ->
        ds.app.navigate "/d/#{slug}/", trigger: true

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
              callback()
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
  ds.groups = new IdeaGroupList
  if isNew
    # Nothing else to fetch yet -- we're brand spanking new.
    return
  cbCount = 2
  for attr in ["ideas", "groups"]
    ds[attr].fetch
      error: (coll, err) -> flash "error", "Error fetching data."
      success: (coll) ->
        cbCount -= 1
        if cbCount == 0
          callback?()
      query: {dotstorm_id: ds.model.id}

# Establish socket.
ds.socket = io.connect("/io", reconnect: false)
Backbone.setSocket(ds.socket)
ds.app = new ds.Router
ds.socket.on 'connect', ->
  ds.client = new Client(ds.socket)
  Backbone.history.start pushState: true
  ds.socket.on 'users', (data) ->
    console.log "users", data
    ds.users = new ds.UsersView(users: data)
    $("#auth").html ds.users.el
    ds.users.render()
  ds.socket.on 'user_left', (user) ->
    ds.users?.removeUser(user)
  ds.socket.on 'user_joined', (user) ->
    ds.users?.addUser(user)
  ds.socket.on 'username', (user) ->
    ds.users?.setUser(user)

  ds.socket.on 'backbone', (data) ->
    console.log 'backbone sync', data
    switch data.signature.collectionName
      when "Idea"
        switch data.signature.method
          when "create"
            ds.ideas.add(new Idea(data.model))
            ds.ideas.trigger "change"
          when "update"
            model = ds.ideas.get(data.model._id)
            if model?
              model.set(data.model)
            else
              ds.ideas.fetch()
          when "delete"
            model = ds.ideas.get(data.model._id)
            if model?
              ds.ideas.remove(model)
            else
              ds.ideas.fetch()

      when "IdeaGroup"
        switch data.signature.method
          when "create"
            ds.groups.add(new IdeaGroup(data.model))
            ds.groups.trigger "change"
          when "update"
            model = ds.groups.get(data.model._id)
            if model?
              model.set(data.model)
            else
              ds.groups.fetch()
          when "delete"
            model = ds.groups.get(data.model._id)
            if model?
              ds.groups.remove(model)
            else
              ds.groups.fetch()
            ds.groups.trigger "change"
      when "Dotstorm"
        switch data.signature.method
          when "update"
            ds.model.set data.model

ds.socket.on 'disconnect', ->
  # Timeout prevents a flash when you are just closing a tab.
  setTimeout ->
    flash "error", "Connection lost.  <a href=''>Click to reconnect</a>."
  , 500


$("nav a").on 'click', (event) ->
  ds.app.navigate $(event.currentTarget).attr('href'), trigger: true
  return false


# Debug:
do ->
  # Add a widget to the window showing the current size in pixels.
  $(window).on 'resize', ->
    $('#size').html $(window).width() + " x " + $(window).height()
  $(window).resize()

