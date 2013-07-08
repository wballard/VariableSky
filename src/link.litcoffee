Link to data on a `Blackboard` by `href`.

Links are asynchronous, dispatching a `link` command to fulfill themselves
with data via event.

    server = require('./server')
    EventEmitter = require('events').EventEmitter

    class Link extends EventEmitter
        constructor: (processor, href) ->
            @href = server.parsePath(href)
            setTimeout =>
                processor.do {command: 'link', href: @href}, (error, val) =>
                    if error
                        @emit 'error', error
                    else
                        @val = val
                        @emit 'link', val

    module.exports = Link
