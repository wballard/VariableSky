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
    eyes = require('eyes')
    browserify = require('browserify')
    parsePath = require('./util').parsePath
    packPath = require('./util').packPath
    connect = require('connect')
    EventEmitter = require('events').EventEmitter
    WebSocketServer = require('ws').Server

A counter for identifiers.

    counter = 0

And our own very forgiving version of the connect json middleware

    json = (req, res, next) ->
        buf = ''
        req.setEncoding 'utf8'
        req.on 'data', (chunk) -> buf += chunk
        req.on 'end', ->
            try
                req.body = JSON.parse(buf)
                next()
            catch err
                #didn't send JSON, no problem, welcome to stringville
                req.body = buf
                next()

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

And now the journal, intially set up to queue commands until we are recovered.

            @doer = @processor.enqueue

And commands are written to a journal, providing durability. The journal is
given a function to recover each command.

            recover = (todo, next) =>
                todo.__recovering__ = true
                @processor.directExecute todo, (error, todo) =>
                    if error
                        util.error 'recovery error', util.inspect(error)
                    next()

On startup, the journal recovers, and when it is full recovered, connect the
command handling `do` directly, no more `enqueue`.

            @journal = new Journal @options, recover, =>
                console.log 'recovered'
                @processor.drain()
                @doer = @processor.do
            @processor.on 'done', (todo, val) =>
                if @processor.commands[todo.command]?.DO_NOT_JOURNAL
                    #nothing to do
                else
                    @journal.record todo, (error) =>
                        if error
                            @emit 'error', error, todo
                        else
                            @emit 'journal', todo

Clean server shutdown.

        shutdown: (callback) ->
            @journal.shutdown callback

Hook support forwards to the processor, supports chaining.

        hook: (event, href, callback) ->
            switch event
                when 'link'
                    @processor.hookAfter event, href, callback
                else
                    @processor.hookBefore event, href, callback
            this

Express middleware export for use with REST. Note the =>, this sort of
this monkeying is why I really don't like objects all that much... But
anyhow, each request sets up a `doer`, which is responsible for actually
running the each request's command.

        rest: (req, res, next) =>
            json req, res, (error) =>
                if error
                    next(error)
                else
                    todo = switch req.method
                        when 'PUT'
                            command: 'save'
                            href: parsePath(req.url)
                            val: req.body
                        when 'GET'
                            command: 'link'
                            href: parsePath(req.url)
                        when 'DELETE'
                            command: 'remove'
                            href: parsePath(req.url)
                        when 'POST'
                            command: 'splice'
                            href: parsePath(req.url)
                            val:
                                elements: do ->
                                    if _.isArray(req.body)
                                        req.body
                                    else
                                        [req.body]

Hand off to the processor. This is the main thing this middleware does.

                    @doer todo, (error, val, todo) ->

Special case, this has an error code for array operations.

                        if error and error.name is 'NOT_AN_ARRAY'
                            res.setHeader('Allow', 'GET, PUT, DELETE')
                            res.statusCode = 405
                            res.end(JSON.stringify(error))

General purpose errors.

                        else if error
                            res.statusCode = 500
                            if _.isObject(error)
                                res.setHeader('Content-Type', 'application/json')
                                res.end(JSON.stringify(error))
                            else
                                res.setHeader('Content-Type', 'text/main')
                                res.end(error)

Reaching the end of the processing with undefined is a 404.

                        else if _.isUndefined(val)
                            console.log 'not found'
                            res.statusCode = 404
                            res.setHeader('Content-Type', 'application/json')
                            res.end(JSON.stringify(errors.NOT_FOUND(todo.href)), 'utf8')

In this case, we have some kind of val, so send it back.
This is end of the line middleward, no `next`.

                        else
                            if _.isObject(val)
                                res.setHeader('Content-Type', 'application/json')
                                res.end(JSON.stringify(val))
                            else
                                res.setHeader('Content-Type', 'text/main')
                                res.end("#{val}")

This is a web socket listen, attached to a connect application
at a given mount point url with the default `/variablesky`.

        listen: (app, server, url) ->
            @connections = {}
            if not app.use
                throw errors.NOT_AN_APP()

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

            sock = new WebSocketServer(server: server, path: url)
            sock.on 'connection', (conn) =>
                new Connection(conn, this)

A single server side connection instance, isolates the state of each client
from one another on the server.

    class Connection
        constructor: (@conn, server) ->
            @router = new Router()

When the server says it has journaled something, we need to route it to clients.

            server.on 'journal', @route

Connection data handling, parse out the messages and dispatch them.

            @conn.on 'message', (message) =>
                todo = JSON.parse(message)

Spy for links. This informs you which clients need which messages by doing
a prefix match against all the linked data in this connection.

                if todo.command is 'link'
                    href = packPath(todo.href)
                    @router.on 'journal', href, @relay

Handing off to the processor, the only interesting thing is echoing
the complete command back out to the client over the socket.

                server.doer todo, (error, val, todo) =>
                    if error
                        todo.error = error
                    else
                        todo.val = val

A successful link command, echoed back. Only direct respond on the link command
otherwise we are just listening for `journal` events.

                if todo.command is 'link'
                    @conn.send JSON.stringify(todo)

On close, unhook from listening to the journal.

            @conn.on 'close', =>
                server.removeListener 'journal', @relay

            @conn.on 'error', (error) =>
                console.log 'server error', error

When a message comes by, route it.

        route: (todo) =>
            href = packPath(todo.href)
            @router.dispatch 'journal', href, todo, ->

When the server has journaled data, there is a state change. This is an interesting
listening case, time to relay data along to the client if there is any prefix match,
from there the client can sort it out... so this early exits on the first and
any match.

        relay: (todo, done) =>
            @conn.send JSON.stringify(todo)
            done()

    module.exports.Server = Server
