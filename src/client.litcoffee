This is the client library, focused on a socket interface.

    EventEmitter = require('events').EventEmitter
    SockJS = require('../lib/sockjs')
    Link = require('./link.litcoffee')

    class Client extends EventEmitter
        constructor: (url) ->
            url = url or '/variablesky'
            @sock = new SockJS(url)
            @sock.onopen = =>
                @emit 'connection'

Incoming messages from the socket, the trick here is to send them
to the correct link, by href.

            @sock.onmessage = (e) =>
                message = JSON.parse(e.data)
                @emit "/#{(message.href or []).join('/')}", message

Create a new data link to the server.

        link: (href) ->

This shims a client side processor into the link which is all about 'do'
being a send to server, events coming back are joined later.

            sock = @sock
            link = new Link(
                do: (todo) =>
                    @emit 'do', todo
                    sock.send JSON.stringify(todo)
                , href
            )
            @on href, (message) ->
                if message.error
                    link.emit 'error', message.error
                else
                    #fire an event that is 'post' the command running with
                    #the same name, clients can then react to modified data
                    link.emit message.command, message.val
            link


    connect = (url) ->
        new Client(url)

    module.exports = connect

    if window?
        browser =
            connect: connect
        window.variablesky = window.VariableSky = browser
