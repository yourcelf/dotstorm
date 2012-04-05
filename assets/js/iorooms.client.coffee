class Client
  constructor: (socket) ->
    @socket = socket
    @socket.on 'connected', => @identify()

  identify: (sid) =>
    sid = sid or $.cookie("express.sid")
    @socket.emit 'identify', { sid: sid }

  join:  (room) => @socket.emit 'join', room: room
  leave: (room) => @socket.emit 'leave', room: room

if typeof exports != "undefined"
  exports.Client = Client
