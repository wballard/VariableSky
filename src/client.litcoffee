This is the client library, focused on a socket interface.

    EventEmitter = require('events').EventEmitter
    sockjsclient = require('sockjs-client')
    Link = require('./link.litcoffee')

    class Client extends EventEmitter
        constructor: (url) ->
            url = url or '/variablesky'
            @sock = sockjsclient.create(url)
            @sock.on 'connection', =>
                @emit 'connection'

Incoming messages from the socket, the trick here is to send them
to the correct link, by href.

            @sock.on 'data', (message) =>
                message = JSON.parse(message)
                @emit "/#{(message.href or []).join('/')}", message

Create a new data link to the server.

        link: (href) ->

This shims a client side processor into the link which is all about 'do'
being a send to server, events coming back are joined later.

            sock = @sock
            link = new Link(
                do: (todo) ->
                    sock.write todo
                , href
            )
            @on href, (message) ->
                if message.error
                    link.emit 'error', message.error
                else
                    switch message.command
                        when 'link'
                            link.emit 'link', message.val
            link


    connect = (url) ->
        new Client(url)

    module.exports = connect
