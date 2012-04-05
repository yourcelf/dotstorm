#= require jquery
#= require underscore
#= require underscore-autoescape
#= require backbone
#= require flash
#= require iorooms.client

# Console log safety.
if typeof console == 'undefined'
  @console = {log: (->), error: (->), debug: (->)}
