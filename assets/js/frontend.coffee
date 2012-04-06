#= require lib/jquery
#= require lib/underscore
#= require lib/underscore-autoescape
#= require lib/backbone
#= require flash
#= require iorooms.client
#= require backbone-socket

# Console log safety.
if typeof console == 'undefined'
  @console = {log: (->), error: (->), debug: (->)}
