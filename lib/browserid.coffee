https = require 'https'
logger = require './logging'

auth_req_options =
  host: "browserid.org"
  port: 443
  path: '/verify'
  method: 'POST'

verify = (assertion, audience, success_callback, error_callback) ->
  # Without the assertion, skip.
  unless assertion?
    error_callback(null)
    return
  logger.debug('browserid verify starting', {assertion, audience})

  # Prepare an http request to the BrowserID verification server
  post_data = JSON.stringify { assertion, audience }

  # Open http connection.
  auth_req = https.request auth_req_options, (auth_res) ->
    auth_res.setEncoding('utf8')
    verification_str = ''
    auth_res.on 'data', (chunk) ->
      verification_str += chunk
    auth_res.on 'end', ->
      # Verify response from BrowserID verification server.
      logger.debug('browserid response', verification_str)
      answer = JSON.parse(verification_str)
      if answer.status == 'okay' and answer.audience == audience
        success_callback(answer)
      else
        error_callback(answer)

  # Write POST data.
  logger.debug('browserid contacting server')
  auth_req.setHeader('Content-Type', 'application/json')
  auth_req.setHeader('Content-Length', post_data.length)
  auth_req.write(post_data)
  auth_req.end()

module.exports = { verify }
