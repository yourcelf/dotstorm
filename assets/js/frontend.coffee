#= require lib/jquery
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

dotstorm = {}
dotstorm.socket = io.connect("/io")
dotstorm.client = Client(dotstorm.socket)
Backbone.setSocket(dotstorm.socket)

class dotstorm.Intro extends Backbone.View
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
      dotstorm.app.open(name)
    return false

  openRandom: (event) =>
    randomChar = =>
      @chars.substr parseInt(Math.random() * @chars.length), 1
    name = (randomChar() for i in [0...12]).join("")
    dotstorm.app.open(name)
    return false

class dotstorm.DotstormTopic extends Backbone.View
  template: _.template $("#dotstormTopic").html() or ""
  editorTemplate: _.template $("#dotstormTopicEditor").html() or ""
  events:
    'click .topic': 'editTopic'
    'submit form': 'saveTopic'
    'click .cancel': 'cancel'

  initialize: (options) ->
    @model = options.model
    @model.on "change", @render

  render: =>
    @$el.html @template
      name: @model.get("name")
      topic: @model.get("topic") or "Click to edit topic..."
    this

  editTopic: (event) =>
    topic = @model.get("topic")
    $(event.currentTarget).replaceWith @editorTemplate { topic }

  saveTopic: (event) =>
    val = @$("textarea").val()
    if val == @model.get("topic")
      @render()
    else
      @model.save topic: val
    return false

  cancel: (event) =>
    @render()
    return false

class dotstorm.IdeaCanvas extends Backbone.View
  tagName: 'canvas'
  events:
    'mousedown':  'handleStart'
    'mouseup':    'handleEnd'
    'mousemove':  'handleDrag'

    'touchstart': 'handleStart'
    'touchend':   'handleEnd'
    'touchmove':  'handleDrag'

  initialize: (options) ->
    @idea = options.idea
    @canvas = @$el
    @tool = "pencil"
    if options.readOnly == true
      @events = undefined

  render: =>
    @ctxDims = @idea.get("dims") or {
      x: @$el.width() * 2
      y: @canvas.height() * 2
    }
    @canvas.attr
      width: @ctxDims.x
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
    @ctx.fillStyle = @background
    @ctx.beginPath()
    @ctx.fillRect(0, 0, @ctxDims.x, @ctxDims.y)
    @ctx.fill()
    @ctx.closePath()
    @lastTool = null
    for action in @actions
      @drawAction(action)

  getPointer: (event) =>
    if event.originalEvent.touches?
      touch = event.originalEvent.touches?[0] or event.originalEvent.changedTouches?[0]
      pointerObj = touch
    else
      pointerObj = event
    @pointer =
      x: (pointerObj.pageX - @offset.left) / @curDims.x * @ctxDims.x
      y: (pointerObj.pageY - @offset.top) / @curDims.y * @ctxDims.y

  # Draw!

  handleStart: (event) =>
    @offset = @canvas.offset()
    @curDims = { x: @canvas.width(), y: @canvas.height() }
    event.preventDefault()
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


class dotstorm.DotstormEditIdea extends Backbone.View
  template: _.template $("#dotstormAddIdea").html() or ""
  events:
    'submit form':       'saveIdea'

    'click .tablinks a': 'tabnav'
    'click .tool': 'changeTool'
    'touchstart .tool': 'changeTool'
    'click .note-color': 'changeBackgroundColor'
    'touchstart .note-color': 'changeBackgroundColor'

  initialize: (options) ->
    @idea = options.idea
    @dotstorm = options.dotstorm
    @canvas = new dotstorm.IdeaCanvas {idea: @idea}

  render: =>
    @$el.html @template
      description: @idea.get "description"
      tags: @idea.get("tags") or " "
      camera: navigator?.camera?
    if not @idea.get("background")?
      @canvas.background = @$(".note-color:first").css("background-color")
    @$(".canvas").append(@canvas.el)
    @canvas.render()
    @tool = 'pencil'
    $(window).on 'mouseup', @handleEnd
    this

  tabnav: (event) =>
    link = @$(event.currentTarget)
    tabgroup = link.parent().parent().parent()
    @$(".tab, .tablinks a", tabgroup).removeClass("active")
    @$(link.attr("href"), tabgroup).addClass("active")
    link.addClass("active")
    return false

  saveIdea: =>
    @idea.save {
      dotstorm_id: @dotstorm.id
      description: $("#id_description").val()
      tags: $("#id_tags").val()
      background: @canvas.background
      dims: @canvas.ctxDims
      drawing: @canvas.actions
    }, {
      success: (model) ->
        dotstorm.app.navigate "/d/#{dotstorm.model.get("slug")}/show/#{model.id}", trigger: true
      error: (model, err) ->
        flash "error", "Error saving: #{err}"
    }
    return false

  changeTool: (event) =>
    event.preventDefault()
    event.stopPropagation()
    el = $(event.currentTarget)
    @canvas.tool = el.attr("data-tool")
    el.parent().find(".tool").removeClass("active")
    el.addClass("active")

  changeBackgroundColor: (event) =>
    event.preventDefault()
    event.stopPropagation()
    @canvas.background = $(event.currentTarget).css("background-color")
    @canvas.redraw()

class dotstorm.DotstormShowIdeas extends Backbone.View
  template: _.template $("#dotstormShowIdeas").html() or ""
  events:
    'click .sizes a': 'resize'
  sizes:
    small: 78
    medium: 118
    large: 238

  initialize: (options) ->
    @dotstorm = options.model
    @showId = options.showId
    @ideas = new IdeaList
    @ideas.fetch
      success: (ideas) =>
        @ideas = ideas
        @render()
      error: ->
        flash "error", "Error fetching ideas"
      query: dotstorm_id: @dotstorm.id

  render: =>
    @$el.html @template()

    # Build linked list.
    models = (model for model in @ideas.models)
    for i in [0...models.length]
      if i > 0
        models[i].prev = models[i - 1]
      if i < @ideas.models.length - 1
        models[i].next = models[i + 1]

    showBig = (model) =>
      dotstorm.app.navigate "/d/#{dotstorm.model.get("slug")}/show/#{model.id}"
      if model.prev?
        model.showPrev = -> showBig(model.prev)
      if model.next?
        model.showNext = -> showBig(model.next)
      big = new dotstorm.DotstormShowIdeaBig model: model
      @$el.append big.el
      big.render()

    for model in models
      do (model) =>
        small = new dotstorm.DotstormShowIdeaSmall model: model
        @$("#showIdeas").append small.el
        small.render()
        small.$el.on "click", -> showBig(model)
        if @showId? and model.id == @showId
          showBig(model)
    this
  
  resize: (event) =>
    size = $(event.currentTarget).attr("data-size")
    @$(".smallIdea").css
      width: @sizes[size] + "px"
      height: @sizes[size] + "px"

class dotstorm.DotstormShowIdeaSmall extends Backbone.View
  template: _.template $("#dotstormSmallIdea").html() or ""
  initialize: (options) ->
    @model = options.model

  render: =>
    @$el.html @template @model.toJSON()
    @$el.addClass("smallIdea")
    @$el.css backgroundColor: @model.get("background")
    canvas = new dotstorm.IdeaCanvas idea: @model, readOnly: true
    @$(".canvas").html canvas.el
    canvas.render()
    this

class dotstorm.DotstormShowIdeaBig extends Backbone.View
  template: _.template $("#dotstormBigIdea").html() or ""
  events:
    'click .shadow': 'close'
    'click .close': 'close'
    'click .note': 'nothing'
    'click .next': 'next'
    'click .prev': 'prev'
    'click .edit': 'edit'

  initialize: (options) ->
    @model = options.model

  render: =>
    console.log @model
    args = @model.toJSON()
    args.hasNext = @model.showNext?
    args.hasPrev = @model.showPrev?
    console.log args
    @$el.html @template args
    @$el.addClass("bigIdea")
    @$el.css backgroundColor: @model.get("background")
    canvas = new dotstorm.IdeaCanvas idea: @model, readOnly: true
    @$(".canvas").html canvas.el
    canvas.render()
    this

  close: (event) =>
    @$el.remove()
    dotstorm.app.navigate "/d/#{dotstorm.model.get("slug")}/show"

  nothing: (event) =>
    event.preventDefault()
    event.stopPropagation()

  next: (event) =>
    @close()
    @model.showNext() if @model.showNext?

  edit: (event) =>
    dotstorm.app.navigate "/d/#{dotstorm.model.get("slug")}/edit/#{@model.id}",
      trigger: true

  prev: (event) =>
    @close()
    @model.showPrev() if @model.showPrev?

updateNavLinks = ->
  $("nav a").each ->
    if $(@).attr("href") == window.location.pathname
      $(@).addClass("active")
    else
      $(@).removeClass("active")

class dotstorm.Router extends Backbone.Router
  routes:
    'd/:slug/add':        'dotstormAddIdea'
    'd/:slug/show':       'dotstormShowIdeas'
    'd/:slug/show/:id':   'dotstormShowIdeas'
    'd/:slug/edit/:id':   'dotstormEditIdea'
    'd/:slug':            'dotstormTopic'
    '':                   'intro'

  intro: ->
    updateNavLinks()
    $("#app").html new dotstorm.Intro().render().el

  dotstormTopic: (slug) =>
    updateNavLinks()
    @open slug, ->
      $("#app").html new dotstorm.DotstormTopic(model: dotstorm.model).render().el
    return false

  dotstormShowIdeas: (slug, id) =>
    updateNavLinks()
    @open slug, ->
      $("#app").html new dotstorm.DotstormShowIdeas(model: dotstorm.model, showId: id).render().el
    return false

  dotstormAddIdea: (slug) =>
    updateNavLinks()
    @open slug, ->
      view = new dotstorm.DotstormEditIdea(idea: new Idea, dotstorm: dotstorm.model)
      $("#app").html view.el
      view.render()
    return false

  dotstormEditIdea: (slug, id) =>
    updateNavLinks()
    @open slug, ->
      model = new Idea _id: id
      model.fetch
        success: (model) ->
          if not model.get("dotstorm_id")
            flash "error", "Model with id #{id} not found."
          else
            view = new dotstorm.DotstormEditIdea(idea: model, dotstorm: dotstorm.model)
            $("#app").html view.el
            view.render()
        error: ->
          flash "error", "Model with id #{id} not found."
    return false

  open: (name, callback) =>
    # Open (if it exists) or create a new dotstorm with the name `name`, and
    # navigate to its view.
    slug = Dotstorm.prototype.slugify(name)
    unless callback?
      # force refresh to get new template.
      callback = -> window.location.href = "/d/#{slug}"

    if dotstorm.model?.get("slug") == slug
      return callback()

    coll = new DotstormList

    coll.fetch
      query: { slug }
      success: (coll) ->
        if coll.length == 0
          new Dotstorm().save { name, slug },
            success: (model) ->
              flash "info", "New dotstorm \"#{name}\" created."
              dotstorm.model = model
              dotstorm.app.navigate "/d/#{model.get("slug")}"
              callback()
            error: (model, err) ->
              flash "error", err.error
        else if coll.length == 1
          dotstorm.model = model = coll.models[0]
          callback()
        else
          flash "error", "Ouch. Something broke. Sorry."
      error: (coll, res) => flash "error", res.error
    return false

dotstorm.app = new dotstorm.Router
Backbone.history.start pushState: true

$("nav a").on 'click', (event) ->
  dotstorm.app.navigate $(event.currentTarget).attr('href'), trigger: true
  return false

# Debug
$(window).on 'resize', ->
  $('#size').html $(window).width() + " x " + $(window).height()
$(window).resize()

