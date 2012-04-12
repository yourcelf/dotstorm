#
# Manage rooms with express sessions and socket IO.
#

logger      = require './logging'
parseCookie = require('connect').utils.parseCookie
_           = require 'underscore'
uuid        = require 'node-uuid'

attach = (route, io, store) ->
  socketSessionMap = {}
  sessionSet = {}

  getUsers = (room, socket) ->
    users = {others: {}}
    socketIDs = io.rooms[[route, room].join("/")]
    unless socketIDs?
      return users
    
    # eliminate duplicate sockets (e.g. multiple tabs in same room)
    uniqueIDs = {}
    selfSession = null
    for id in socketIDs
      if id == socket?.id
        selfSession = socketSessionMap[id]
      else
        uniqueIDs[socketSessionMap[id].sid] = socketSessionMap[id]
    if selfSession?
      users.self =
        user_id: selfSession.user_id
        name: selfSession.name
    for sessionID, session of uniqueIDs
      users.others[session.user_id] =
        user_id: session.user_id
        name: session.name
    return users
 

  io.set 'authorization', (handshake, callback) ->
    # Get session from express sessionID on connection.
    if handshake.headers.cookie
      cookie = parseCookie(handshake.headers.cookie)
      sessionID = cookie['express.sid']
      store.get sessionID, (err, session) ->
        if err? or not session
          callback err?.message or "Error acquiring session", false
        else
          handshake.session = session
          handshake.session.sid = sessionID
          unless session.user_id?
            handshake.session.user_id = uuid.v1()
          store.set sessionID, session, (err) ->
            if err?
              logger.error "Session store error", err
              callback(err)
            else
              callback(null, true)

  io.of(route).on 'connection', (socket) ->
    socket.session = socket.handshake.session
    socketSessionMap[socket.id] = socket.session

    socket.on 'join', (data) ->
      unless data.room? and socket.session?
        socket.emit "error", error: "Room not specified or session not found"
        return
      socket.session.room = data.room
      socket.join data.room
      users = getUsers(data.room, socket)
      socket.emit 'users', users
      unless users.others[socket.session.user_id]
        socket.broadcast.to(data.room).emit 'user_joined', users.self

    socket.on 'leave', (data) ->
      unless data.room? and socket.session?
        socket.emit "error", error: "Room not specified or sessionID not found"
        return
      socket.leave(data.room)
      users = getUsers(data.room, socket)
      unless users.others[socket.session.user_id]
        socket.broadcast.to(data.room).emit 'user_left',
          user_id: session.user_id
          name: session.name

    socket.on 'username', (data) ->
      socket.session.name = data.name
      store.set socket.session.sid, socket.session, (err) ->
        if err?
          logger.error "Session store error", err
        else
          socket.broadcast.to(socket.room).emit 'username', {
            user_id: socket.session.user_id
            name: data.name
          }

    socket.on 'disconnect', ->
      logger.debug "disconnect", socket.id
      for room, connected of io.roomClients[socket.id]
        # chomp off the route part.
        room = room.substring(route.length + 1)
        if room
          socket.leave(room)
          users = getUsers(room, socket)
          unless users.others[socket.session.user_id]
            socket.broadcast.to(room).emit 'user_left',
              user_id: socket.session.user_id
              name: socket.session.name
      delete socketSessionMap[socket.id]

module.exports = { attach }
