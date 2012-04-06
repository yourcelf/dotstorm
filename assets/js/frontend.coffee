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

socket = io.connect("/io")
Backbone.setSocket(socket)
client = Client(socket)
