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
    'click .cancel': 'render'

  initialize: (options) ->
    @model = dotstorm.model
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


class dotstorm.DotstormShowIdeas extends Backbone.View
  render: =>
    @$el.html "todo show ideas"
    this
class dotstorm.DotstormAddIdea extends Backbone.View
  render: =>
    @$el.html "todo add idea"
    this

class dotstorm.Router extends Backbone.Router
  routes:
    '':             'intro'
    'd/:slug/add':  'dotstormAddIdea'
    'd/:slug/show': 'dotstormShowIdeas'
    'd/:slug':      'dotstormTopic'

  intro: ->
    $("#app").html new dotstorm.Intro().render().el

  dotstormTopic: (slug) =>
    @open slug, ->
      $("#app").html new dotstorm.DotstormTopic().render().el

  dotstormShowIdeas: (slug) =>
    @open slug, ->
      $("#app").html new dotstorm.DotstormShowIdeas().render().el

  dotstormAddIdea: (slug) =>
    @open slug, ->
      $("#app").html new dotstorm.DotstormAddIdea().render().el

  openFirst: (slug) =>
    unless dotstorm.model?.get("slug") == slug
      @open(slug)
      return false
    return true

  open: (name, callback) =>
    # Open (if it exists) or create a new dotstorm with the name `name`, and
    # navigate to its view.
    slug = Dotstorm.prototype.slugify(name)
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

$(window).on 'resize', ->
  $('#size').html $(window).width() + " x " + $(window).height()
$(window).resize()

