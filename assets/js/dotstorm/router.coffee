getUrlVars = ->
  vars = {}
  hashes = window.location.href.slice(window.location.href.indexOf('?') + 1).split('&')
  for hash in hashes
    [key, val] = hash.split('=')
    vars[key] = val
  return vars


ds.URL_VARS = getUrlVars()
ds.settings = {
  hideHome: ds.URL_VARS.hideHome == "true"
  hideLinks: ds.URL_VARS.hideLinks == "true"
}
if ds.settings.hideHome
  $("a.home").hide()

class ds.Router extends Backbone.Router
  routes:
    'd/:slug/add/*query':        'dotstormAddIdea'
    'd/:slug/edit/:id/*query':   'dotstormEditIdea'
    'd/:slug/tag/:tag/*query':   'dotstormShowTag'
    'd/:slug/:id/*query':        'dotstormShowIdeas'
    'd/:slug/*query':            'dotstormShowIdeas'
    '':                          'intro'
    '*query':                    'fourOhFour'

  navigate: (path, options) ->
    if window.location.search
      path += window.location.search
    return super(path, options)


  updateNavLinks: (showNav, active) ->
    if showNav
      $("nav a").removeClass("active")
      if active
        $("nav a.#{active}").addClass("active")
      $("nav").show()
    else
      $("nav").hide()

  intro: ->
    # Keep the nav bar if we've been to a dotstorm already, so we can click
    # back to it.
    if @secondrun
      @updateNavLinks(true, "home")
    else
      @updateNavLinks(false)
      @secondrun = true
    intro = new ds.Intro()
    intro.on "open", (slug, name) =>
      @open slug, name, =>
        @navigate "/d/#{slug}/"
        @dotstormShowIdeas(slug)
    $("#app").html intro.el
    intro.render()

  dotstormShowIdeas: (slug, id, tag) =>
    @updateNavLinks(true, "show-ideas")
    @open slug, "", =>
      $("#app").html new ds.Organizer({
        model: ds.model
        ideas: ds.ideas
        showId: id
        showTag: tag
      }).render().el
    return false

  dotstormShowTag: (slug, tag) =>
    @dotstormShowIdeas(slug, null, tag)

  dotstormAddIdea: (slug) =>
    @updateNavLinks(true, "add")
    @open slug, "", ->
      view = new ds.EditIdea
        idea: new ds.Idea
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
    console.log(slug, id)
    @updateNavLinks(true, "add")
    @open slug, "", ->
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

  fourOhFour: (query) =>
    $("#app").html $("#oops").html()

  open: (slug, name, callback) =>
    # Open (if it exists) or create a new dotstorm with the name `name`, and
    # navigate to its view.
    if ds.model?.get("slug") == slug
      return callback()

    fixLinks = ->
      $("nav a.show-ideas").attr("href", "/d/#{slug}/")
      $("nav a.add").attr("href", "/d/#{slug}/add")
      $("a.embed-dotstorm").attr("href", "/e/#{ds.model.get("embed_slug")}")

    coll = new ds.DotstormList
    coll.fetch
      query: { slug }
      success: (coll) ->
        if coll.length == 0
          new ds.Dotstorm().save { name, slug },
            success: (model) ->
              flash "info", "Created!  Click things to change them."
              ds.joinRoom(model, true, callback)
              fixLinks()
            error: (model, err) ->
              console.log "error", err
              flash "error", err
        else if coll.length == 1
          ds.joinRoom(coll.models[0], false, callback)
          fixLinks()
        else
          flash "error", "Ouch. Something broke. Sorry."
      error: (coll, res) =>
        console.log "error", res
        flash "error", res.error
    return false

ds.joinRoom = (newModel, isNew, callback) ->
  if ds.model? and ds.client? and ds.model.id != newModel.id
    ds.client.leave ds.model.id
  if ds.model?.id != newModel.id
    ds.client.join newModel.id
  ds.model = newModel
  ds.ideas = new ds.IdeaList
  if isNew
    # Nothing else to fetch yet -- we're brand spanking new.
    return callback()
  ds.ideas.fetch
    error: (coll, err) ->
      console.log "error", err
      flash "error", "Error fetching #{attr}."
    success: (coll) -> callback?()
    query: {dotstorm_id: ds.model.id}
    fields: {drawing: 0}

