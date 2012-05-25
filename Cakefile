config  = require './lib/config'

# You can override the configured defaults for port and host with flags.
option '-p', "--port [#{config.port}]", 'port the server runs on'
option '-h', "--host [#{config.host}]", 'base server name'
option '-s', "--secret [#{config.secret}]", 'session secret'

task 'runserver', 'Run the server.', (options) ->
  server = require './lib/server'
  server.start
    host: options.host or config.host
    port: options.port or config.port
    secret: options.secret or config.secret
    dbhost: config.dbhost
    dbport: config.dbport
    dbname: config.dbname

task 'resave', 'Resave all ideas, to recreate their images.', (options) ->
  mongoose = require 'mongoose'
  db = mongoose.connect(
    "mongodb://#{config.dbhost}:#{config.dbport}/#{config.dbname}"
  )
  models = require('./lib/schema')
  models.Idea.find {}, (err, docs) ->
    count = docs.length
    exitCode = 0
    for doc in docs
      doc.incImageVersion()
      doc.save (err) ->
        count--
        if err?
          exitCode = 1
          console.log(count, err)
        else
          console.log(count)
        if count == 0
          process.exit(exitCode)
