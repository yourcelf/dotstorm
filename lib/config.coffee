fs = require 'fs'

try
    config = JSON.parse(fs.readFileSync(__dirname + '/../config.json', 'utf-8'))
catch e
    console.log "Skipping config file", e
    config =
        host: "localhost"
        port: 8000
        secret: "this is mah sekrit"
        dbhost: '127.0.0.1'
        dbport: 27017
        dbname: 'dotstorm'
        dbopts: {}

module.exports = config
