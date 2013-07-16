This is the client library, focused on a socket interface.

    EventEmitter = require('events').EventEmitter
    Processor = require('./processor.litcoffee')
    Link = require('./link.litcoffee')
    Router = require('./router.litcoffee').PrefixRouter
    packPath = require('./util.litcoffee').packPath
    parsePath = require('./util.litcoffee').parsePath

Yes. On purpose. Appeases browserify.

    save = require('./commands/server/save.litcoffee')
    remove = require('./commands/server/remove.litcoffee')
    splice = require('./commands/server/splice.litcoffee')

    class Client extends EventEmitter
        constructor: (url) ->
            defaultUrl = "ws://#{window.document.location.host}/variablesky"
            url = url or defaultUrl

A client has a command processor, in a way it is just like a server
but for a single user.

            @processor = new Processor()
            @processor.commands.save = save
            @processor.commands.remove = remove
            @processor.commands.splice = splice

            @val = @processor.blackboard

A router, used to fire events to the right links as messages come back
from the server.

            @router = new Router()

And a socket, so we can actually talk to the server.

            @forcedClose = false

            connect = =>
                @sock = new WebSocket(url)
                timeout = setTimeout =>
                    @sock.close()
                , 1000
                @sock.onopen = =>
                    clearTimeout timeout
                    @emit 'open'
                    @relink()
                @sock.onclose = =>
                    clearTimeout timeout
                    @emit 'close'
                    if not @forcedClose
                        @emit 'reconnect'
                        connect()
                @sock.onerror = (error) =>
                    @emit 'error', error
                @sock.onmessage = (e) =>
                    todo = JSON.parse(e.data)
                    @processor.do todo, (error) =>
                        if error and error.name isnt 'NO_SUCH_COMMAND'
                            @emit 'error', error
                        else
                            @router.dispatch 'fromserver', packPath(todo.href), todo, ->

            connect()

Refresh all links.

        relink: =>
            for each in @router.all('fromserver')
                @sock.send JSON.stringify({command: 'link', href: parsePath(each.route)})

Create a new data link to the server.

        link: (href) =>

This shims a client side processor into the link which is all about 'do'
being a send to server, events coming back are joined later.

            link = new Link(
                do: (todo) =>
                    @sock.send JSON.stringify(todo)
                , href
                , => @router.off 'fromserver', href, routeToLink
            )
            routeToLink = (message, done) =>
                if message.error
                    link.emit 'error', message.error
                    done(error)
                else
                    #fire an event that is 'post' the command running with
                    #the same name, clients can then react to modified deltas
                    #but only on an exact match
                    link.emit message.command, message.val
                    #the link now has the current value from the blackboard
                    link.val = @processor.blackboard.valueAt(href)
                    if @processor.commands[message.command]
                        #and the linked data has changed, refresh the link
                        link.emit 'link', @processor.blackboard.valueAt(href)
                    done()
            @router.on 'fromserver', href, routeToLink
            link

Polite close. My money is you never remember to call this, so the server
has a close connection timeout anyhow.

        close: ->
            @forcedClose = true
            @sock.close()
            @removeAllListeners()

This is the main exported factory API to connect, you can feed this `()` and
it will connect to the default relative location, which is almost always what
you want.

    connect = (url) ->
        new Client(url)

    module.exports = connect

Export to the browser when used in `browserify`.

    if window?
        browser =
            connect: connect
        window.variablesky = window.VariableSky = browser
