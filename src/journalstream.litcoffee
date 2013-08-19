Journal


    es = require('event-stream')

    module.exports = (options) ->
      stream = es.through (message) ->
        if options.journal and not message.DO_NOT_JOURNAL
          null
        stream.emit 'data', message
