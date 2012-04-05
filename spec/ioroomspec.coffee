h = require './helper'

describe "Client room connections", ->
  beforeEach -> @server = h.startServer()
  afterEach  -> @server.app.close()

  it "increments room counts on join", ->
    # Connect client to socket.io

    clients = [{
      c: h.newClient()
      id: 'id1'
    }, {
      c: h.newClient()
      id: 'id2'
    }, {
      c: h.newClient()
      id: 'id1'
    }]

    for client_data in clients
      c = client_data.c
      sid = client_data.id
      do (c, sid) =>
        # Connect
        runs ->
          waitsFor ->
            return c.socket.socket.connected == true
          , "client connection", 1000

        # Set up asynch callbacks for later tests
        runs ->
          c.socket.on "identified", h.done
          c.socket.on "joined", h.done
          c.socket.on "left", h.done
          c.socket.on "error", -> expect(true).toBe(false)

        # Create a fake session, since we aren't going through a browser.
        runs =>
          h.waitsForDone "create dummy session", =>
            @server.sessionStore.set sid, {cookie: maxAge: 100000}, h.done

        runs ->
          h.waitsForDone "identify", -> c.identify sid

    runs ->
      # sanity check that we're getting different sockets
      expect(clients[0].c.socket.socket.sessionid).toNotEqual(
             clients[1].c.socket.socket.sessionid)

    # Join the room, and ensure that room and session counts match.
    runs -> h.waitsForDone "join room", -> clients[0].c.join "test"
    runs =>
      expect(@server.io.roomSessions).toEqual(test: sessions: { id1: 1})
      expect(@server.io.sessionRooms).toEqual(id1: rooms: { test: 1})

    # Leave the room, and ensure that room and session counts match.
    runs -> h.waitsForDone "leave room", -> clients[0].c.leave "test"
    runs =>
      expect(@server.io.roomSessions).toEqual(test: sessions: {})
      expect(@server.io.sessionRooms).toEqual(id1: rooms: {})
    
    # Join with multiple sessions and rooms, and ensure counts match.
    runs -> h.waitsForDone "join room", -> clients[0].c.join "test"
    runs -> h.waitsForDone "join room", -> clients[1].c.join "test"
    runs -> h.waitsForDone "join room", -> clients[1].c.join "test2"
    runs -> h.waitsForDone "join room", -> clients[2].c.join "test"
    runs =>
      expect(@server.io.roomSessions).toEqual
        test: sessions: {id1: 2, id2: 1}
        test2: sessions: {id2: 1}
      expect(@server.io.sessionRooms).toEqual
        id1: rooms: {test: 2}
        id2: rooms: {test: 1, test2: 1}
    runs -> h.waitsForDone "leave room", -> clients[0].c.leave "test"
    runs =>
      expect(@server.io.roomSessions).toEqual
        test: sessions: {id1: 1, id2: 1}
        test2: sessions: {id2: 1}
      expect(@server.io.sessionRooms).toEqual
        id1: rooms: {test: 1}
        id2: rooms: {test: 1, test2: 1}
    runs -> h.waitsForDone "leave room", -> clients[1].c.leave "test"
    runs -> h.waitsForDone "leave room",-> clients[2].c.leave "test"
    runs =>
      expect(@server.io.roomSessions).toEqual
        test: sessions: {}
        test2: sessions: {id2: 1}
      expect(@server.io.sessionRooms).toEqual
        id1: rooms: {}
        id2: rooms: {test2: 1}
