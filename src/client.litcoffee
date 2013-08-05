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
    websocket = require('websocket-stream')

Yes. On purpose. Appeases browserify.

    linkcommand = require('./commands/client/link.litcoffee')
    savecommand = require('./commands/server/save.litcoffee')
    removecommand = require('./commands/server/remove.litcoffee')

Two different ways to get a WebSocket depending if we are running in a browser
or in node. Shim it in node, count on the browser otherwise. This little patch
is to make this client work from node-node as well as browser-node via browserify.

    if not WebSocket?
        #not in the browser? shim it
        console.log browser
        console.log 'using'
        global.WebSocket = require('ws')

Websocket stream reconnector.

    reconnect = (url, connectionCallback) ->
        sock = null
        allowReconnect = true
        connectionCount = 0
        backoff = 100
        reconnector = null
        tryReconnect = ->
            if allowReconnect
                clearTimeout(reconnector) if reconnector
                sock.removeAllListeners() if sock
                backoff = Math.min(backoff * 2, 30000)
                reconnector = setTimeout ->
                    connect(url)
                , backoff
        connect = (url) ->
            sock = websocket(url)
            sock.connectionCount = connectionCount++
            connectionCallback(sock)
            sock.on 'connect', ->
                backoff = 100
            sock.on 'end', tryReconnect
            sock.on 'error', tryReconnect
        connect(url)
        do ->
            interrupt: ->
                sock.end()
            close: ->
                allowReconnect = false
                sock.end()



The client, used to connect to VariableSky. This is designed to be used from node
as well as the browser via `browserify`.

    class Client extends EventEmitter
        constructor: (url, options) ->
            @options = options or {}
            @trace = false
            @client = uuid.v1()
            @counter = 0
            if window?
                if window?.location?.protocol is 'https:'
                   defaultUrl = "wss://#{window.document.location.host}/variablesky"
                else
                   defaultUrl = "ws://#{window.document.location.host}/variablesky"
            else
                defaultUrl = "/variablesky"
            url = url or defaultUrl

A client has a command processor, in a way it is just like a server
but for a single user, running commands locally to update the local slice
of variables from the sky.

            @processor = new Processor()
            @processor.commands.link = linkcommand
            @processor.commands.save = savecommand
            @processor.commands.remove = removecommand
            @processor.side = 'client'

Use this to peep into the blackboard. I'm not sure this a good idea or that
I'll stick with it, but it lets you see a partial replica of the variables in
the sky here in the client.

            @val = @processor.blackboard

A router, used to fire events to the right links as messages come back
from the server.

            @router = new Router()

And a socket, so we can actually talk to the server.

            @sock = reconnect url, (stream) =>

The inbound event processing stream, from the server to this client.
Diffs coming back to your self have already been applied as they were
generated by modifying the local variable.

                inbound = es.pipeline(
                    es.map( (message, callback) =>
                        callback(null, JSON.parse(message))
                    ),
                    es.map( (todo, callback) =>
                        if @trace
                            console.log '\n<----'
                            console.log inspect(todo)
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

The outbound event processing stream, from this client to the server.

                outbound = es.pipeline(
                    es.map( (todo, callback) =>
                        todo.__client__ = @client
                        callback(null, todo)
                    ),
                    es.map( (todo, callback) =>
                        if @trace
                            console.log '\n---->'
                            console.log inspect(todo)
                        callback(null, todo)
                    ),
                    es.map( (todo, callback) =>
                        callback(null, JSON.stringify(todo))
                    )
                )

Pipe up the inbound and outbound streams, and provide an outbound reference.

                outbound.pipe(stream)
                stream.pipe(inbound)
                @outbound = outbound
                if stream.connectionCount
                    @relink()

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
            @emit 'relinked'

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
                        done todo.error, todo.val, todo
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

            routeToLink = (todo) =>
                if todo.error
                    link.fireCallback todo.error, undefined, todo
                else
                    if todo.__client__ is @client and path is packPath(todo.path) and not todo.__relink__
                        #
                    else
                        if @trace
                            console.log 'Routed Callback', path
                        link.fireCallback undefined, @processor.blackboard.valueAt(path), todo
            @router.on 'fromserver', path, routeToLink
            link

AngularJS support. Use this from in a controller to link values to your scope.
This will automatically update the linked value in the scope, and clean itself
up when your scope is destroyed.

        linkToAngular: (path, $scope, name, defaultValue) =>

Indeed, you need angular JS, but there is an ability to specify it via options
if you hooked angular into a 'namespace' rather than just on `window`.

            angular = @options.angular or window?.angular
            if not angular
                throw errors.NO_ANGULAR()

This is the link from angular to Variable Sky. The idea is to get value changes
from the sky and reflect them in the angular scope, and take changes in the angular
scope and push them to the sky. The *hard part* is dealing with the initial update
which isn't an update at all, and trying to not spam the server with
non-change-changes.

            exitcount = 0
            link = @link(path, (error, value, todo) =>

Default value, or chain it in the case we got nothing. This doesn't trigger
a save back to the sky, it is just a local client default. And if you don't
specify a default, it just stays undefined. JavaScript magic.

This works with a cloned object, making a separate reference in angular land
so that operations and modifications are synchronized via commands rather than
direct access.

                value = @processor.blackboard.valueAt(path)

                if angular.isUndefined(value)
                    value = defaultValue
                else
                    value = angular.copy(value)

Push into angular scope land. This will trigger binding.

                if exitcount++ < 3
                    $scope.$apply ->
                        $scope[name] = value
            ).equalIs(angular.equals)

Hook back to angular, looking for UI/angular originated changes and push them
back into the sky to automatically save. This little trick keeps you from needing
to call save on your own.

            unwatch = $scope.$watch name, (newValue, oldValue) =>

Firehose for debugging. Whoosh!

                if @trace
                    console.log 'SCOPE', name
                    console.log 'Was:', inspect(oldValue)
                    console.log 'Is:', inspect(newValue)
                    console.log 'Same:', newValue is oldValue

Saving. Not as simple as just saving

* All undefined, there is no action
* No difference with the blackboard, there is no action

                if angular.isUndefined(newValue) and angular.isUndefined(oldValue)
                    null
                else if angular.equals(newValue, @processor.blackboard.valueAt(path))
                    null
                else
                    link.saveDiff newValue, oldValue
            , true

Clean up your room! Put your toys away!

            $scope.$on '$destroy', =>
                if @trace
                    console.log 'CLOSE', link.path
                unwatch()
                link.close()

            link

Polite close. My money is you never remember to call this, so the server
has a close connection timeout anyhow.

        close: (done) ->
            @removeAllListeners()
            @sock.close()
            (done or ->)()

        interrupt: (done) ->
            @sock.interrupt()
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
