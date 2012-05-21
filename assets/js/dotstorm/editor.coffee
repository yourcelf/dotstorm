
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
      @isTouch = true
    else
      pointerObj = event
    @pointer =
      x: parseInt((pointerObj.pageX - @offset.left) / @curDims.x * @ctxDims.x)
      y: parseInt((pointerObj.pageY - @offset.top) / @curDims.y * @ctxDims.y)
    return @pointer

  handleStart: (event) =>
    if @disabled then return
    event.preventDefault()
    event.stopPropagation()
    if event.type == "touchstart"
      @isTouch = true
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
    if @isTouch and event.type != "touchmove"
      # Android 4.0 browser throws a mousemove in here after 100 milliseconds
      # or so.  Assume that if we've seen one touch event, we're touch only.
      return false
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
    [width, height] = ds.fillSquare(@$(".canvasHolder"), @$el, 600, 320)
    @$("#addIdea").css "width", width + "px"
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
        ds.app.navigate "/d/#{@dotstorm.get("slug")}/", trigger: true
        $(".smallIdea[data-id=#{@idea.id}]").css({
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
