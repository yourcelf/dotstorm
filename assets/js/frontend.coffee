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


class dotstorm.DotstormShowIdeas extends Backbone.View
  initialize: (options) ->
    @model = options.model

  render: =>
    @$el.html "todo show ideas"
    this

class dotstorm.DotstormEditIdea extends Backbone.View
  template: _.template $("#dotstormAddIdea").html() or ""
  events:
    'mousedown canvas':  'handleStart'
    'mouseup canvas':    'handleEnd'
    'mousemove canvas':  'handleDrag'

    'touchstart canvas': 'handleStart'
    'touchend canvas':   'handleEnd'
    'touchmove canvas':  'handleDrag'

    'submit form':       'saveIdea'

    'click .tablinks a': 'tabnav'
    'click .tool': 'changeTool'
    'touchstart .tool': 'changeTool'
    'click .note-color': 'changeBackgroundColor'
    'touchstart .note-color': 'changeBackgroundColor'

  initialize: (options) ->
    @idea = options.model
    @actions = []

  render: =>
    @$el.html @template
      description: @idea.get "description"
      tags: (@idea.get("tags") or []).join(",")
      camera: navigator?.camera?
    @canvas = @$("canvas")
    @ctxDims =
      x: @canvas.width() * 2
      y: @canvas.height() * 2
    @canvas.attr
      width: @ctxDims.x
      height: @ctxDims.y

    @ctx = @canvas[0].getContext('2d')
    @$("a.note-color:first").click()
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
    return false

  changeTool: (event) =>
    event.preventDefault()
    event.stopPropagation()
    el = $(event.currentTarget)
    @tool = el.attr("data-tool")
    el.parent().find(".tool").removeClass("active")
    el.addClass("active")

  changeBackgroundColor: (event) =>
    event.preventDefault()
    event.stopPropagation()
    @background = $(event.currentTarget).css("background-color")
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

  dotstormShowIdeas: (slug) =>
    updateNavLinks()
    @open slug, ->
      $("#app").html new dotstorm.DotstormShowIdeas(model: dotstorm.model).render().el
    return false

  dotstormAddIdea: (slug) =>
    updateNavLinks()
    @open slug, ->
      view = new dotstorm.DotstormEditIdea(model: new Idea)
      $("#app").html view.el
      view.render()
    return false

  dotstormEditIdea: (slug, id) =>
    updateNavLinks()
    @open slug, ->
      model = new Idea _id: id
      $("#app").html new dotstorm.DotstormEditIdea(model: model).render().el
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

