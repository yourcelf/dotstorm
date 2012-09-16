# 
# Socket data!!!!!!!!!!!!!!
#
ds.socket = io.connect("/io", reconnect: false)
Backbone.setSocket(ds.socket)
ds.app = new ds.Router
ds.socket.on 'connect', ->
  ds.client = new Client(ds.socket)
  if ds.settings.userName
    ds.client.setName(ds.settings.userName)
  Backbone.history.start pushState: true
  ds.socket.on 'users', (data) ->
    #console.debug "users", data
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
            ds.ideas.add(new ds.Idea(data.model))
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
    #console.debug 'trigger', data
    switch data.collectionName
      when "Idea"
        ds.ideas.get(data.id).trigger data.event

ds.socket.on 'disconnect', ->
  # Timeout prevents a flash when you are just closing a tab.
  setTimeout ->
    flash "error", "Connection lost.  <a href='' onclick='window.location.reload(); return false;'>Click to reconnect</a>."
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

$("a.soft").on 'touchend click', (event) ->
  ds.app.navigate $(event.currentTarget).attr('href'), trigger: true
  return false
