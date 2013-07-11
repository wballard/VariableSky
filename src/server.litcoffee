This is the main junction box to hook up as a server to `http` and `express`.
This takes incoming network activity and generates commands, which are then
sent along to a command processor with a shared memory blackboard.

    _ = require('lodash')
    path = require('path')
    errors = require('./errors')
    Blackboard = require('./blackboard')
    Processor = require('./processor')
    wrench = require('wrench')
    sockjs = require('sockjs')

Paths are always something to deal with. Here is the general representation,
an array of path segments.

    parsePath = (path) ->
        if _.isArray(path)
            path
        else
            _(path.split('/'))
                .map(decodeURIComponent)
                .filter((x) -> x.length)
                .value()

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

    class Server
        constructor: (@options)->
            @options.storageDirectory = @options.storageDirectory or path.join(__dirname, '.server')
            @options.journalDirectory = @options.journalDirectory or path.join(@options.storageDirectory, '.journal')
            wrench.mkdirSyncRecursive(@options.storageDirectory)
            @processor = new Processor(@options)

Clean server shutdown.

        shutdown: (callback) ->
            @processor.shutdown callback

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
            doer = @processor.do
            json req, res, (error) ->
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

                    doer todo, (error, val) ->
                        if error
                            switch error.name
                                when 'NOT_AN_ARRAY'
                                    res
                                        .set('Allow', 'GET, PUT, DELETE')
                                        .send(405, error)
                                        .end()
                                else
                                    res
                                        .send(500, error)
                                        .end()

Reaching the end of the processing with undefined is a 404.

                        else if _.isUndefined(val)
                            res
                                .send(404, errors.NOT_FOUND(todo.href))
                                .end()

In this case, we have some kind of val, so send it back.
This is end of the line middleward, no `next`.

                        else
                            if _.isObject(val)
                                res
                                    .json(val)
                            else
                                res
                                    .send(val)

This is a web socket listen, attached to a running express/http server
at a given mount point url with the default `/variablesky`

        listen: (server, url) ->
            url = url or '/variablesky'
            processor = @processor
            sock = sockjs.createServer()
            sock.installHandlers server, {prefix: url}
            sock.on 'connection', (conn) ->
                conn.on 'data', (message) ->
                    console.log 'server', message
                    processor.do message, (error, val) ->
                        if error
                            message.error = error
                        else
                            message.val = val
                        console.log 'server sending', message
                        conn.write JSON.stringify(message)
                conn.on 'close', ->

    module.exports.Server = Server
    module.exports.parsePath = parsePath
