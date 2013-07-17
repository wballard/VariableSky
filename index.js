//Root module, just a nice place to require bits and shim in coffeescript
require('coffee-script');
module.exports.Server = require('./src/server');
module.exports.Client = require('./src/client');
