This is the main junction box to hook up as a server to `http` and `express`.
This takes incoming network activity and generates commands, which are then
sent along to a command processor with a shared memory blackboard.

    _ = require('lodash')
    path = require('path')
    errors = require('./errors')
    Blackboard = require('./blackboard')
    Processor = require('./processor')
    Journal = require('./journal')
    Router = require('./router').PrefixRouter
    wrench = require('wrench')
    browserify = require('browserify')
    parsePath = require('./util').parsePath
    packPath = require('./util').packPath
    connect = require('connect')
    EventEmitter = require('events').EventEmitter
    WebSocketServer = require('ws').Server
    es = require('event-stream')
    inspect = require('./util.litcoffee').inspect
    websocket = require('websocket-stream')

This is the main server object. This is a class to give instancing, I'm not all
the way sure why you would want to, but you can make multiple of these in a
process and have separate sockets or rest url mount points to them. I'd make
some claim abut this being more testable, but I'd be lying :)

    class Server extends EventEmitter
        constructor: (@options) ->
            @options = @options or {}
            @options.storageDirectory = @options.storageDirectory or path.join(process.cwd(), '.server')
            @options.journalDirectory = @options.journalDirectory or path.join(@options.storageDirectory, '.journal')
            wrench.mkdirSyncRecursive(@options.storageDirectory)
            wrench.mkdirSyncRecursive(@options.journalDirectory)

Set up a processor with the server based commands.

            @processor = new Processor()
            @processor.commands.link = require('./commands/server/link')
            @processor.commands.save = require('./commands/server/save')
            @processor.commands.remove = require('./commands/server/remove')
            @processor.on 'done', (todo) =>
                @emit 'done', todo
            @processor.on 'error', (error, todo) =>
                todo.error = error
                @emit 'done', todo

An event stream, paused until recovery is complete, that will process todos.

            @workstream = es.pipeline(
                es.map( (todo, callback) =>
                    @processor.do todo, (error, val, todo) =>
                        if error
                            todo.error = error
                            callback()
                        else
                            todo.val = val
                            callback(null, todo)
                )
            )
            @workstream.pause()

And commands are written to a journal, providing durability. The journal is
given a function to recover each command that takes a 'direct' hook free path
through the command processor.

            recover = (todo, next) =>
                @processor.directExecute todo, (error, todo) =>
                    if error
                        @emit 'error', error, todo
                    next()

On startup, the journal recovers, and when it is full recovered, connect the
command handling `do` directly, no more `enqueue`.

            @journal = new Journal @options, recover, =>
                @workstream.resume()
                @emit 'recovered'

Build an event stream from the processor through to the journal.

            journalstream = es.pipeline(
                es.map( (todo, callback) =>
                    if not @processor.commands[todo.command]?.DO_NOT_JOURNAL
                        @journal.record todo, (error) =>
                            if error
                                @emit 'error', error, todo

                    callback()
                )
            )
            @processor.on 'done', journalstream.write

Clean server shutdown.

        shutdown: (done) ->
            @sock.close() if @sock
            @journal.shutdown done

Hook support forwards to the processor, supports chaining.

        hook: (event, datapath, callback) ->
            switch event
                when 'link'
                    @processor.hookAfter event, datapath, callback
                else
                    @processor.hookBefore event, datapath, callback
            this


This is a web socket listen, attached to a connect application
at a given mount point url with the default `/variablesky`.

        listen: (app, server, url) =>
            @connections = {}
            if not app.use
                throw errors.NOT_AN_APP()
            if @sock
                throw errors.ALREADY_LISTENING()

            url = url or '/variablesky'

If this looks like connect or express, install a client library handler and
and self check sample page. Detect connect/express with the presence of `use`.

            if app.use
                client = "#{path.join(url)}.client"
                app.use path.join(client, 'test'),
                    connect.static(path.join(__dirname, '../test/client'))
                app.use client,  (req, res, next) ->
                    res.setHeader('Content-Type', 'text/javascript')
                    bundle = browserify()
                        .transform(require('coffeeify'))
                        .add(path.join(__dirname, 'client.litcoffee'))
                        .bundle()
                    bundle.pipe(res)
                    bundle.on 'error', (error) ->
                        res.statusCode = 500
                        res.end("#{error}")
                    bundle.on 'end', ->
                        res.statusCode = 404
                        res.end()

And, install the socket processing, this hands off to a `Connection` which is
a per client/connection abstraction.

            @sock = new WebSocketServer({server: server, path: url})
            @sock.on 'connection', (conn) =>
                ret = new Connection(conn, this)
                @emit 'connected', ret
                ret

        traceOn: ->
            remit = @emit
            @emit = ->
                console.error 'emit', arguments[0], inspect(arguments[1])
                remit.apply this, _.toArray(arguments)
            this

A single server side connection instance, isolates the state of each client
from one another on the server.

    class Connection
        constructor: (conn, server) ->
            router = new Router()

When the server says it has journaled something, we need to route it to clients.

            routeDone = (todo) =>
                datapath = packPath(todo.path)
                router.dispatch 'done', datapath, todo, ->
            server.on 'done', routeDone

Streaming web sockets are go.

            socketstream = websocket(conn)

The outbound event stream, send messages along to a connected client.

            outbound = es.pipeline(
                es.map( (todo, callback) ->
                    callback null, JSON.stringify(todo)
                ),
                socketstream
            )

The inbound event stream, messages coming from a connected client.

* Spy for links. This informs you which clients need which messages by doing
a prefix match against all the linked data in this connection.
* Listen for events to reply on completion.
* Write to the server workstream, not that *this is not a pipe*, as multiple
clients are writing to this stream, and clients close

            inbound = es.pipeline(
                es.map( (message, callback) ->
                    todo = JSON.parse(message)
                    callback(null, todo)
                ),
                es.map( (todo, callback) ->
                    if todo.command is 'link'
                        datapath = packPath(todo.path)
                        if not router.has('done', datapath)
                            router.on 'done', datapath, (todo, done) ->
                                todo.__routed__ = true
                                outbound.write(todo)
                                done()
                    callback(null, todo)
                ),
                es.map( (todo, callback) ->
                    server.workstream.write(todo)
                    callback(null, null)
                )
            )
            socketstream.pipe(inbound)

            conn.on 'close', =>
                server.removeListener 'done', routeDone

            conn.on 'error', (error) =>

    module.exports = Server
