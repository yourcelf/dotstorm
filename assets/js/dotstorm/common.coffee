# Console log safety.
if typeof console == 'undefined'
  @console = {log: (->), error: (->), debug: (->)}

#
# Our namespace: ds.
#
if not window.ds?
  ds = window.ds = {}

# Debug:
do ->
  # Add a widget to the window showing the current size in pixels.
  $(window).on 'resize', ->
    $('#size').html $(window).width() + " x " + $(window).height()
  $(window).resize()
