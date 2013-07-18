This is the client library, focused on a socket interface.

    uuid = require('node-uuid')
    EventEmitter = require('events').EventEmitter
    Processor = require('./processor.litcoffee')
    Link = require('./link.litcoffee')
    Router = require('./router.litcoffee').PrefixRouter
    packPath = require('./util.litcoffee').packPath
    parsePath = require('./util.litcoffee').parsePath
    if not WebSocket?
        WebSocket = require('ws')

Yes. On purpose. Appeases browserify.

    linkcommand =
    save = require('./commands/server/save.litcoffee')
    remove = require('./commands/server/remove.litcoffee')
    splice = require('./commands/server/splice.litcoffee')

    class Client extends EventEmitter
        constructor: (url) ->
            @trace = ->
            @id = uuid.v1()
            @counter = 0
            if window?
                defaultUrl = "ws://#{window.document.location.host}/variablesky"
            else
                defaultUrl = "/variablesky"
            url = url or defaultUrl

A client has a command processor, in a way it is just like a server
but for a single user.

            @processor = new Processor()
            @processor.commands.link = require('./commands/client/link.litcoffee')
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
                    @trace 'from-server', todo
                    @processor.do todo, (error) =>
                        if error and error.name isnt 'NO_SUCH_COMMAND'
                            @emit 'error', error
                        else
                            @emit todo.__id__, todo
                            if todo.__client__ isnt @id
                                @router.dispatch 'fromserver', packPath(todo.path), todo, ->

            connect()

Trace flag toggle, this will spew a lot of messages.

        traceOn: ->
            @trace = console.error
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
                    todo.__client__ = @id
                    @trace 'to-server', todo
                    @once todo.__id__, (todo) ->
                        done undefined, todo.val
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

        close: ->
            @forcedClose = true
            @sock.close()
            @removeAllListeners()

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
