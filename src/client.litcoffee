This is the client library, focused on a socket interface.

    EventEmitter = require('events').EventEmitter
    sockjsclient = require('sockjs-client')


    connect = (url) ->
        url = url or '/variablesky'

The client is fundamentally an event emitter, we tack on additional methods.

        emitter = new EventEmitter()
        emitter.link = ->

With setup out of the way, create a socket client connection through to the
server.

        sock = sockjsclient.create(url)
        sock.on 'connection', ->
            emitter.emit 'connection'
        emitter


    module.exports = connect
