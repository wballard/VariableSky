Link to data on a `Blackboard` by `href`.

Links are asynchronous, dispatching a `link` command to fulfill themselves
with data via event.

This gives you a clone of the linked data, which is a simulation of sending
the data over the wire to a client as JSON. This is to keep behavior the
same on client as on server, in that you must `save`, `remove`, `set`, or call
an Array mutator.

    server = require('./server')
    _ = require('lodash')
    EventEmitter = require('events').EventEmitter

    class Link extends EventEmitter
        constructor: (processor, href) ->
            @href = server.parsePath(href)
            setTimeout =>
                processor.do {command: 'link', href: @href}, (error, val) =>
                    if error
                        @emit 'error', error
                    else
                        @emit 'link', _.cloneDeep(val)

    module.exports = Link
