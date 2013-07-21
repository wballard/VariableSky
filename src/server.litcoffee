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

A counter for identifiers.

    counter = 0

This is the main server object. This is a class to give instancing, I'm not all
the way sure why you would want to, but you can make multiple of these in a
process and have separate sockets or rest url mount points to them. I'd make
some claim abut this being more testable, but I'd be lying :)

    class Server extends EventEmitter
        constructor: (@options) ->
            @options = @options or {}
            @options.storageDirectory = @options.storageDirectory or path.join(__dirname, '.server')
            @options.journalDirectory = @options.journalDirectory or path.join(@options.storageDirectory, '.journal')
            wrench.mkdirSyncRecursive(@options.storageDirectory)
            wrench.mkdirSyncRecursive(@options.journalDirectory)

Set up a processor with the server based commands.

            @processor = new Processor()
            @processor.commands.link = require('./commands/server/link')
            @processor.commands.save = require('./commands/server/save')
            @processor.commands.remove = require('./commands/server/remove')
            @processor.commands.splice = require('./commands/server/splice')



An event stream, paused until recovery is complete, that will
* process todos
* journal them

            workstream = es.pipeline(
                es.map( (todo, callback) =>
                    @emit 'doing', todo
                    @processor.do todo, (error, val) =>
                        if error
                            todo.error = error
                            callback()
                        else
                            todo.val = val
                            callback(null, todo)
                        @emit todo.__id__
                )
            )
            workstream.pause()
            @doer = workstream.write

And commands are written to a journal, providing durability. The journal is
given a function to recover each command that takes a 'direct' hook free path
through the command processor.

            recover = (todo, next) =>
                todo.__recovering__ = true
                @processor.directExecute todo, (error, todo) =>
                    if error
                        util.error 'recovery error', util.inspect(error)
                    next()

On startup, the journal recovers, and when it is full recovered, connect the
command handling `do` directly, no more `enqueue`.

            @journal = new Journal @options, recover, =>
                @processor.drain()
                workstream.resume()
                @emit 'recovered'

Build an event stream from the processor through to the journal.

            journalstream = es.pipeline(
                es.map( (todo, callback) =>
                    if not @processor.commands[todo.command]?.DO_NOT_JOURNAL
                        @journal.record todo, (error) =>
                            if error
                                @emit 'error', error, todo
                            else
                                @emit 'journal', todo

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
                new Connection(conn, this)

        traceOn: ->
            remit = @emit
            @emit = ->
                console.error 'emit', arguments[0], inspect(arguments[1])
                remit.apply this, _.toArray(arguments)

A single server side connection instance, isolates the state of each client
from one another on the server.

    class Connection
        constructor: (@conn, server) ->
            @router = new Router()
            @client = null

When the server says it has journaled something, we need to route it to clients.

            server.on 'journal', @route

Connection data handling, parse out the messages and dispatch them.

            @conn.on 'message', (message) =>
                todo = JSON.parse(message)
                @client = todo.__client__

Spy for links. This informs you which clients need which messages by doing
a prefix match against all the linked data in this connection.

                if todo.command is 'link'
                    datapath = packPath(todo.path)
                    @router.on 'journal', datapath, @relay

Handing off to the processor, the only interesting thing is echoing
the complete command back out to the client over the socket.

                server.once todo.__id__, =>
                    @conn.send JSON.stringify(todo)
                server.doer todo

On close, unhook from listening to the journal.

            @conn.on 'close', =>
                server.removeListener 'journal', @relay

            @conn.on 'error', (error) =>

When a message comes by, route it.

        route: (todo) =>
            datapath = packPath(todo.path)
            @router.dispatch 'journal', datapath, todo, ->

When the server has journaled data, there is a state change. This is an interesting
listening case, time to relay data along to the client if there is any prefix match,
from there the client can sort it out... so this early exits on the first and
any match.

But, don't relay your own client's messages to yourself, that leads to
double messages.

        relay: (todo, done) =>
            if todo.__client__ isnt @client
                @conn.send JSON.stringify(todo)
            done()

    module.exports = Server
