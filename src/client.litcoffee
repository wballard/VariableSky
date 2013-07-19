This is the client library, focused on a socket interface.

    uuid = require('node-uuid')
    EventEmitter = require('events').EventEmitter
    Processor = require('./processor.litcoffee')
    Link = require('./link.litcoffee')
    Router = require('./router.litcoffee').PrefixRouter
    packPath = require('./util.litcoffee').packPath
    parsePath = require('./util.litcoffee').parsePath
    trace = require('./util.litcoffee').trace
    if not WebSocket?
        WebSocket = require('ws')

Yes. On purpose. Appeases browserify.

    linkcommand = require('./commands/client/link.litcoffee')
    savecommand = require('./commands/server/save.litcoffee')
    removecommand = require('./commands/server/remove.litcoffee')
    splicecommand = require('./commands/client/splice.litcoffee')

    class Client extends EventEmitter
        constructor: (url) ->
            @trace = ->
            @client = uuid.v1()
            @counter = 0
            if window?
                defaultUrl = "ws://#{window.document.location.host}/variablesky"
            else
                defaultUrl = "/variablesky"
            url = url or defaultUrl

A client has a command processor, in a way it is just like a server
but for a single user.

            @processor = new Processor()
            @processor.commands.link = linkcommand
            @processor.commands.save = savecommand
            @processor.commands.remove = removecommand
            @processor.commands.splice = splicecommand
            @processor.side = 'client'

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
                    todo.__from_server__ = true
                    @trace todo

Messages back from the server, the most important thing is to not
replay errored messages against the local processor.

                    if todo.error
                        @emit todo.__id__, todo
                    else
                        @processor.do todo, (error) =>
                            if error and error.name isnt 'NO_SUCH_COMMAND'
                                @emit 'error', error
                            else
                                @emit todo.__id__, todo

Replies from yourself do not need to be dispatched.

                            if todo.__client__ isnt @client
                                @router.dispatch 'fromserver', packPath(todo.path), todo, ->

            connect()

Fire hose of tracing.

        traceOn: ->
            @trace = trace
            this

Refresh all links.

        relink: =>
            for each in @router.all('fromserver')
                @sock.send JSON.stringify({command: 'link', path: parsePath(each.route)})

Create a new data link to the server.

        link: (path, done) =>

This shims a client side processor into the link which is all about 'do'
being a send to server, events coming back are joined later.

            link = new Link(
                do: (todo, done) =>
                    todo.__id__ = "client#{Date.now()}:#{@counter++}"
                    todo.__client__ = @client
                    @trace todo

A message back from the server with the same id is the signal to fire the
done callback.

                    @once todo.__id__, (todo) ->
                        done todo.error, todo.val
                    @sock.send JSON.stringify(todo)
                , path
                , done
                , => @router.off 'fromserver', path, routeToLink
            )
            routeToLink = (message) =>
                if message.error
                    link.fireCallback error
                else
                    #the link now has the current value from the blackboard
                    link.fireCallback undefined, @processor.blackboard.valueAt(path)
            @router.on 'fromserver', path, routeToLink
            link

Polite close. My money is you never remember to call this, so the server
has a close connection timeout anyhow.

        close: (done) ->
            @forcedClose = true
            @removeAllListeners()
            @sock.close()
            done()

This is the main exported factory API to connect, you can feed this `()` and
it will connect to the default relative location, which is almost always what
you want.

    connect = (url) ->
        new Client(url)

    module.exports = Client

Export to the browser when used in `browserify`.

    if window?
        browser =
            connect: connect
        window.variablesky = window.VariableSky = browser
