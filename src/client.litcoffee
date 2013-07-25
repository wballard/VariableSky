This is the client library, focused on a socket interface.

    uuid = require('node-uuid')
    EventEmitter = require('events').EventEmitter
    Processor = require('./processor.litcoffee')
    Link = require('./link.litcoffee')
    Router = require('./router.litcoffee').PrefixRouter
    packPath = require('./util.litcoffee').packPath
    parsePath = require('./util.litcoffee').parsePath
    inspect = require('./util.litcoffee').inspect
    es = require('event-stream')
    _ = require('lodash')

Two different ways to get a WebSocket depending if we are running in a browser
or in node.

    if not window?.WebSocket
        #not in the browser?
        WebSocket = require('ws')
    else
        #plain old socket, supplied by the browser
        #and if you have a socket less browser, die. horribly.
        WebSocket = window.WebSocket

Yes. On purpose. Appeases browserify.

    linkcommand = require('./commands/client/link.litcoffee')
    savecommand = require('./commands/server/save.litcoffee')
    removecommand = require('./commands/server/remove.litcoffee')

The client, used to connect to VariableSky. This is designed to be used from node
as well as the browser via `browserify`.

    class Client extends EventEmitter
        constructor: (url, options) ->
            @options = options or {}
            @trace = false
            @client = uuid.v1()
            @counter = 0
            if window?
                defaultUrl = "ws://#{window.document.location.host}/variablesky"
            else
                defaultUrl = "/variablesky"
            url = url or defaultUrl

The outbound event processing stream, from this client to the server.

            @outboundGate = es.pause()
            @outbound = es.pipeline(
                @outboundGate,
                es.map( (todo, callback) =>
                    todo.__client__ = @client
                    callback(null, todo)
                ),
                es.map( (todo, callback) =>
                    if @trace
                        console.error '\n---->'
                        console.error inspect(todo)
                    callback(null, todo)
                ),
                es.map( (todo, callback) =>
                    @sock.send(JSON.stringify(todo))
                    callback()
                )
            )
            @outboundGate.pause()

The inbound event processing stream, from the server to this client.

            @inbound = es.pipeline(
                es.map( (message, callback) =>
                    callback(null, JSON.parse(message.data))
                ),
                es.map( (todo, callback) =>
                    if @trace
                        console.error '\n<----'
                        console.error inspect(todo)
                    callback(null, todo)
                ),
                es.map( (todo, callback) =>
                    if todo.error
                        @emit todo.__id__, todo
                        callback()
                    else
                        callback(null, todo)
                ),
                es.map( (todo, callback) =>

Diffs coming back to your self have already been applied as they were
generated by modifying the local variable.

                    if todo.__client__ is @client and todo.skipWhenReplies
                        @emit todo.__id__, todo
                        callback(null, todo)
                    else
                        @processor.do todo, (error) =>
                            if error and error.name isnt 'NO_SUCH_COMMAND'
                                @emit 'error', error
                                callback()
                            else
                                @emit todo.__id__, todo
                                callback(null, todo)
                ),
                es.map( (todo, callback) =>
                    @router.dispatch 'fromserver', packPath(todo.path), todo, ->
                    callback()
                )
            )

A client has a command processor, in a way it is just like a server
but for a single user, running commands locally to update the local slice
of variables from the sky.

            @processor = new Processor()
            @processor.commands.link = linkcommand
            @processor.commands.save = savecommand
            @processor.commands.remove = removecommand
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
                    @outboundGate.resume()
                @sock.onclose = =>
                    clearTimeout timeout
                    @outboundGate.pause()
                    @emit 'close'
                    if not @forcedClose
                        @emit 'reconnect'
                        connect()
                @sock.onerror = (error) =>
                    @emit 'error', error
                @sock.onmessage = (e) =>
                    @inbound.write(e)

            connect()

Fire hose of tracing.

        traceOn: ->
            @trace = true
            this

Refresh all links.

        relink: =>
            for each in @router.all('fromserver')
                @outbound.write
                    __id__ : "client#{Date.now()}:#{@counter++}"
                    command: 'link'
                    path: parsePath(each.route)
                    __relink__: true

Create a new data link to the server.

        link: (path, done) =>


            link = new Link(

This shims a client side processor into the link which is all about `do`
being a send to server, once the todos come back run from the server, they are
run locally by the command processor above.

                do: (todo, done) =>

A message back from the server with the same id is the signal to fire the
done callback when the todo makes it back from the server.

                    todo.__id__ = "client#{Date.now()}:#{@counter++}"
                    @once todo.__id__, (todo) ->
                        done todo.error, todo.val
                    @outbound.write todo
                , @processor.blackboard
                , path
                , done
                , => @router.off 'fromserver', path, routeToLink
            )

When a message comes back from the server, we will route it to all the affected links. The
exception is that you already got a callback on message 'replies' from the server, and more
subtle, if you get a reply on `a.b`, but have a link on `a`, you want to see that routed
to get hierarchial notification.

            routeToLink = (message) =>
                if message.error
                    link.fireCallback error
                else
                    if message.__client__ is @client and path is packPath(message.path) and not message.__relink__
                        #
                    else
                        link.fireCallback undefined, @processor.blackboard.valueAt(path)
            @router.on 'fromserver', path, routeToLink
            link

AngularJS support. Use this from in a controller to link values to your scope.
This will automatically update the linked value in the scope, and clean itself
up when your scope is destroyed.

        linkToAngular: (path, $scope, name, defaultValue) =>
            angular = @options.angular or window?.angular
            if not angular
                throw errors.NO_ANGULAR()
            flipSaveOff = false
            link = @link path, (error, value) ->

Default value, or chain it in the case we got nothing. This doesn't trigger
a save back to the sky, it is just a local client default. And if you don't
specify a default, it just stays undefined. JavaScript magic.

                if _.isUndefined(value)
                    value = defaultValue

Push into angular scope land. This will trigger binding.

                $scope.$apply ->
                    flipSaveOff = true
                    $scope[name] = value

Clean up your room! Put your toys away!

            $scope.$on '$destroy', ->
                link.close()

Hook back to angular, looking for UI/angular originated changes and push them
back into the sky to automatically save. This little trick keeps you from needing
to call save on your own.

            $scope.$watch name, (newValue, oldValue) =>

Firehose for debugging. Whoosh!

                if @trace
                    console.error 'SCOPE', name
                    console.error 'Was:', inspect(newValue)
                    console.error 'Is:', inspect(oldValue)

The flip off, it's not about screwing you, it's about supressing a false
save when your own initial link triggers an angular watch change as the variable
comes back the first time.

                if not flipSaveOff
                    link.save newValue
                flipSaveOff = false
            , true

Polite close. My money is you never remember to call this, so the server
has a close connection timeout anyhow.

        close: (done) ->
            @forcedClose = true
            @removeAllListeners()
            @sock.close()
            done()

        dangerClose: (done) ->
            @sock.close()
            (done or ->)()

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
