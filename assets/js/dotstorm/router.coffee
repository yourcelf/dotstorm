class ds.Router extends Backbone.Router
  routes:
    'd/:slug/add':        'dotstormAddIdea'
    'd/:slug/edit/:id':   'dotstormEditIdea'
    'd/:slug/tag/:tag':   'dotstormShowTag'
    'd/:slug/:id':        'dotstormShowIdeas'
    'd/:slug/':           'dotstormShowIdeas'
    '':                   'intro'

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
    $("#app").html new ds.Intro().render().el

  dotstormShowIdeas: (slug, id, tag) =>
    @updateNavLinks(true, "show-ideas")
    @open slug, "", =>
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
    @updateNavLinks(true, "add")
    @open slug, "", ->
      console.log slug
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

  open: (slug, name, callback) =>
    # Open (if it exists) or create a new dotstorm with the name `name`, and
    # navigate to its view.
    if ds.model?.get("slug") == slug
      return callback()

    $("nav a.show-ideas").attr("href", "/d/#{slug}/")
    $("nav a.add").attr("href", "/d/#{slug}/add")
    coll = new ds.DotstormList
    coll.fetch
      query: { slug }
      success: (coll) ->
        if coll.length == 0
          new ds.Dotstorm().save { name, slug },
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
  ds.ideas = new ds.IdeaList
  if isNew
    # Nothing else to fetch yet -- we're brand spanking new.
    return callback()
  ds.ideas.fetch
    error: (coll, err) -> flash "error", "Error fetching #{attr}."
    success: (coll) -> callback?()
    query: {dotstorm_id: ds.model.id}
    fields: {drawing: 0}

