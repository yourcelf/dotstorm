#
# Manage rooms with express sessions and socket IO.
#
# 1. On socket connection, attach the current session to the socket from the
#    express session cookie.
#
# 2. On 'join', 

logger      = require './logging'
parseCookie = require('connect').utils.parseCookie

attach = (route, io, store) ->
  # A map of rooms to sessions and users.
  io.roomSessions = {}
  # A map of sessions to rooms.
  io.sessionRooms = {}

  io.of(route).on 'connection', (socket) ->
    socket.on 'identify', (data) ->
      unless data.sid
        socket.emit "error", error: "sid missing."
        return
      store.get data.sid, (err, session) ->
        if err or not session
          socket.emit "error", error: "Session not found."
        else
          socket.session = session
          socket.sessionID = data.sid
          socket.join data.sid
          socket.emit "identified", {sid: data.sid}

    socket.on 'join', (data) ->
      unless data.room
        socket.emit "error", error: "Room not specified or session ID not found"
        return
      unless socket.sessionID
        socket.emit "error", error: "Session ID not found."
        return

      # Set up sessionRooms and roomSessions
      unless io.sessionRooms[socket.sessionID]?
        io.sessionRooms[socket.sessionID] = rooms: {}
      unless io.roomSessions[data.room]
        io.roomSessions[data.room] = sessions: {}
      
      # Increment counts
      unless io.sessionRooms[socket.sessionID].rooms[data.room]?
        io.sessionRooms[socket.sessionID].rooms[data.room] = 0
      io.sessionRooms[socket.sessionID].rooms[data.room] += 1
      unless io.roomSessions[data.room].sessions[socket.sessionID]?
        io.roomSessions[data.room].sessions[socket.sessionID] = 0
      io.roomSessions[data.room].sessions[socket.sessionID] += 1
      socket.join(data.room)
      socket.emit "joined",
        room: data.room

    leave_room = (name) ->
      io.sessionRooms[socket.sessionID].rooms[name] -= 1
      if io.sessionRooms[socket.sessionID].rooms[name] == 0
        delete io.sessionRooms[socket.sessionID].rooms[name]
      io.roomSessions[name].sessions[socket.sessionID] -= 1
      if io.roomSessions[name].sessions[socket.sessionID] == 0
        delete io.roomSessions[name].sessions[socket.sessionID]
      socket.leave(name)

    socket.on 'leave', (data) ->
      unless data.room and socket.sessionID
        socket.emit "error", error: "Room or sessionID not found"
        return
      leave_room(data.room)
      socket.emit "left", room: data.room

    socket.on 'disconnect', ->
      if socket.sessionID
        socket.leave(socket.sessionID)
        for name, count of io.sessionRooms[socket.sessionID].rooms
          leave_room(name)

module.exports = { attach }
