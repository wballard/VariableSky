This is the main junction box to hook up as a server to `http` and `express`.
This takes incoming network activity and generates commands, which are then
sent along to a command processor with a shared memory blackboard.

    _ = require('lodash')
    path = require('path')
    errors = require('./errors')
    Blackboard = require('./blackboard')
    Processor = require('./processor')

Paths are always something to deal with. Here is the general representation,
an array of path segments.

    parsePath = (path) ->
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
        constructor: ->
            @processor = new Processor()

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
                            content: req.body
                        when 'GET'
                            command: 'link'
                            href: parsePath(req.url)
                        when 'DELETE'
                            command: 'remove'
                            href: parsePath(req.url)
                        when 'POST'
                            command: 'push'
                            href: parsePath(req.url)
                            content: req.body
                    handled = (error, content) ->
                        if error
                            switch error.name
                                when 'NOT_FOUND'
                                    res.send(404, error).end()
                                when 'NOT_AN_ARRAY'
                                    res
                                        .set('Allow', 'GET, PUT, DELETE')
                                        .send(405, error)
                                        .end()
                                else
                                    res.send(500, error).end()
                        else
                            res
                                .set('Content-Type', 'application/json')
                                .send(200, JSON.stringify(content)).end()
                    doer todo, handled, next

    module.exports.Server = Server