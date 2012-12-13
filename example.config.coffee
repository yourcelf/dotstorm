base_config = require '../base_config'
_           = require 'underscore'

conf = _.extend {}, base_config
conf.port = 9003
conf.intertwinkles.api_key = "one"
conf.dbname = "twinkledotstorm"
module.exports = conf
