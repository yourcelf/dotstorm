
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

