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

#
# Our namespace: ds.
#
if not window.ds?
  ds = window.ds = {}
ds.socket = io.connect("/io")
ds.client = Client(ds.socket)
Backbone.setSocket(ds.socket)


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

class ds.IdeaCanvas extends Backbone.View
  #
  # A canvas element suitable for drawing and recalling drawn ideas.
  #
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
      x: parseInt((pointerObj.pageX - @offset.left) / @curDims.x * @ctxDims.x)
      y: parseInt((pointerObj.pageY - @offset.top) / @curDims.y * @ctxDims.y)

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
    'click .note-color': 'changeBackgroundColor'
    'touchstart .note-color': 'changeBackgroundColor'

  initialize: (options) ->
    @idea = options.idea
    @dotstorm = options.dotstorm
    @canvas = new ds.IdeaCanvas {idea: @idea}

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
        ds.app.navigate "/d/#{ds.model.get("slug")}/show/#{model.id}", trigger: true
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

class ds.ShowIdeas extends Backbone.View
  #
  # Show a list of ideas, as well as any groupings that they involve.
  #
  template: _.template $("#dotstormShowIdeas").html() or ""
  events:
    'click .sizes a': 'resize'
  sizes:
    small: 78
    medium: 118
    large: 238

  initialize: (options) ->
    @dotstorm = options.model
    # ID of a single note to show, popped out
    @showId = options.showId
    @ideas = new IdeaList
    @groups = new IdeaGroupList
    gotIdeas = gotGroups = false
    doIt = => if gotIdeas and gotGroups then @render()

    @ideas.fetch
      success: (ideas) =>
        @ideas = ideas
        gotIdeas = true
        doIt()
      error: ->
        flash "error", "Error fetching ideas"
      query: dotstorm_id: @dotstorm.id

    @groups.fetch
      success: (groups) =>
        @groups = groups
        gotGroups = true
        doIt()
      error: ->
        flash "error", "Error fetching groups"
      query: dotstorm_id: @dotstorm.id

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
      else if count < @ideas.models.length - 1
        idea.next = model_order[count + 1]
    group_order.push({ models: ungrouped })
    return group_order

  showBig: (model) =>
    # For prev/next navigation, we assume that 'prev' and 'next' have been set
    # on the model for ordering, linked-list style.  This is done by @sortGroups.
    # Without this, prev and next nav buttons just won't show up.
    ds.app.navigate "/d/#{ds.model.get("slug")}/show/#{model.id}"
    if model.prev?
      model.showPrev = => @showBig(model.prev)
    if model.next?
      model.showNext = => @showBig(model.next)
    big = new ds.ShowIdeaBig model: model
    @$el.append big.el
    big.render()
  
  resize: (event) =>
    size = $(event.currentTarget).attr("data-size")
    @$(".smallIdea").css
      width: @sizes[size] + "px"
      height: @sizes[size] + "px"

  render: =>
    @$el.html @template(sorting: false, slug: @model.get("slug"))
    group_order = @sortGroups()
    for group in group_order
      groupView = new ds.ShowIdeaGroup group: group.group, ideas: group.models
      @$("#showIdeas").append groupView.el
      groupView.render()
      groupView.on "ideaClicked", @showBig
    if @showId?
      model = @ideas.get(@showId)
      if model? then @showBig model
    this

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
        label: @group.get('label') or "Click to add label..."
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

class ds.SortIdeas extends ds.ShowIdeas
  #
  # Display a list of ideas, and provide UI for sorting and grouping them via
  # drag and drop.
  #
  events:
    # From parent class
    'click .sizes a': 'resize'
    # From us
    'mousedown  .smallIdea': 'startDrag'
    'mousemove  .smallIdea': 'continueDrag'
    'mouseup    .smallIdea': 'stopDrag'
    'touchstart .smallIdea': 'startDrag'
    'touchmove  .smallIdea': 'continueDrag'
    'touchend   .smallIdea': 'stopDrag'

  render: =>
    @$el.html @template(sorting: true, slug: @model.get("slug"))
    @$el.addClass "sorting"

    group_order = @sortGroups()
    for group in group_order
      groupView = new ds.ShowIdeaGroup group: group.group, ideas: group.models
      @$("#showIdeas").append groupView.el
      groupView.render()
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
    if @mouseIsDown
      @moveNote(event)

  stopDrag: (event) =>
    # reset drag UI...
    @active.css
      position: "relative"
      left: 0
      top: 0
      zIndex: "auto"
      opacity: 1
    @mouseIsDown = false
    @noteDims = []
    @active = null
    @mouseOffset = null
    @placeholder.remove()

    hovered = @$(".hovered")
    source = @ideas.get $(event.currentTarget).attr("data-id")
    if hovered[0]? and hovered[0] != event.currentTarget
      #
      # Are we being dragged into a group?
      #
      target = @ideas.get hovered.attr("data-id")
      targetGroup = null
      for group in @groups.models
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
      groupParent = $(event.currentTarget).parentsUntil(".group").parent()
      if groupParent.length > 0
        pos = @getPosition(event)
        dims = groupParent.position()
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

  render: =>
    @$el.html @template @model.toJSON()
    @$el.attr("data-id", @model.id)
    @$el.addClass("smallIdea")
    @$el.css backgroundColor: @model.get("background")
    canvas = new ds.IdeaCanvas idea: @model, readOnly: true
    @$(".canvas").html canvas.el
    canvas.render()
    this

class ds.ShowIdeaBig extends Backbone.View
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
    args = @model.toJSON()
    args.hasNext = @model.showNext?
    args.hasPrev = @model.showPrev?
    @$el.html @template args
    @$el.addClass("bigIdea")
    @$el.css backgroundColor: @model.get("background")
    canvas = new ds.IdeaCanvas idea: @model, readOnly: true
    @$(".canvas").html canvas.el
    canvas.render()
    this

  close: (event) =>
    @$el.remove()
    ds.app.navigate "/d/#{ds.model.get("slug")}/show"

  nothing: (event) =>
    event.preventDefault()
    event.stopPropagation()

  next: (event) =>
    @close()
    @model.showNext() if @model.showNext?

  edit: (event) =>
    ds.app.navigate "/d/#{ds.model.get("slug")}/edit/#{@model.id}",
      trigger: true

  prev: (event) =>
    @close()
    @model.showPrev() if @model.showPrev?

updateNavLinks = ->
  $("nav a").each ->
    href = $(@).attr('href')
    if window.location.pathname == href
      $(@).addClass("active")
    else
      $(@).removeClass("active")

class ds.Router extends Backbone.Router
  routes:
    'd/:slug/add':        'dotstormAddIdea'
    'd/:slug/edit/:id':   'dotstormEditIdea'
    'd/:slug/show':       'dotstormShowIdeas'
    'd/:slug/show/:id':   'dotstormShowIdeas'
    'd/:slug/sort':       'dotstormSortIdeas'
    'd/:slug':            'dotstormTopic'
    '':                   'intro'

  intro: ->
    updateNavLinks()
    $("#app").html new ds.Intro().render().el

  dotstormTopic: (slug) =>
    updateNavLinks()
    @open slug, ->
      $("#app").html new ds.Topic(model: ds.model).render().el
    return false

  dotstormShowIdeas: (slug, id) =>
    updateNavLinks()
    @open slug, ->
      $("#app").html new ds.ShowIdeas(model: ds.model, showId: id).render().el
    return false

  dotstormSortIdeas: (slug) =>
    @open slug, ->
      $("#app").html new ds.SortIdeas(model: ds.model).render().el

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
      model = new Idea _id: id
      model.fetch
        success: (model) ->
          if not model.get("dotstorm_id")
            flash "error", "Model with id #{id} not found."
          else
            view = new ds.EditIdea(idea: model, dotstorm: ds.model)
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

    if ds.model?.get("slug") == slug
      return callback()

    coll = new DotstormList

    coll.fetch
      query: { slug }
      success: (coll) ->
        if coll.length == 0
          new Dotstorm().save { name, slug },
            success: (model) ->
              flash "info", "New dotstorm \"#{name}\" created."
              ds.model = model
              ds.app.navigate "/d/#{model.get("slug")}"
              callback()
            error: (model, err) ->
              flash "error", err
        else if coll.length == 1
          ds.model = model = coll.models[0]
          callback()
        else
          flash "error", "Ouch. Something broke. Sorry."
      error: (coll, res) => flash "error", res.error
    return false

ds.app = new ds.Router
Backbone.history.start pushState: true

$("nav a").on 'click', (event) ->
  # Use soft refresh for nav links.
  ds.app.navigate $(event.currentTarget).attr('href'), trigger: true
  return false

# Debug:
do ->
  # Add a widget to the window showing the current size in pixels.
  $(window).on 'resize', ->
    $('#size').html $(window).width() + " x " + $(window).height()
  $(window).resize()

