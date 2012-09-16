getUrlVars = ->
  vars = {}
  hashes = window.location.href.slice(window.location.href.indexOf('?') + 1).split('&')
  for hash in hashes
    [key, val] = hash.split('=')
    vars[key] = val
  return vars

ds.URL_VARS = getUrlVars()
ds.settings = {
  hideHome: ds.URL_VARS.hideHome == "true"
  hideLinks: ds.URL_VARS.hideLinks == "true"
  userName: if ds.URL_VARS.userName then decodeURIComponent(ds.URL_VARS.userName) else null
  userNameReadOnly: ds.URL_VARS.userNameReadOnly == "true"
}
console.log ds.settings
