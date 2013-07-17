The most basic interactions are with REST, this makes a workable server, the only
sad part is that it doesn't have events and thus no replication.

    sky = require('../index')
    path = require('path')
    wrench = require('wrench')
    connect = require('connect')
    should = require('chai').should()

This is a side effect test variable to make sure we are journaling post hook.

    stashAt = 0

The REST API.

    options =
        storageDirectory: path.join __dirname, '.test'

    describe "Hooks", ->
        client =
        server = null
        before (done) ->
            wrench.rmdirSyncRecursive options.storageDirectory, true
            app = connect()
            httpserver = require('http').createServer(app)
            server = new sky.Server(options)
            server.listen app, httpserver
            httpserver.listen 9999, ->
                client = new sky.Client('ws://localhost:9999/variablesky')
                client.on 'open', ->
                    done()
        after (done) ->
            server.shutdown ->
                httpserver.close done
        it "will let you hook a read", (done) ->
            server.hook('link', 'message', (context, next) ->
                context.val =
                    totally: "different"
                next()
            ).hook('link', 'message', (context, next) ->
                context.val.double = "hooked"
                next()
            )
            client.link('message', (error, snapshot) ->
                snapshot.totally.should.equal('different')
                snapshot.double.should.equal('hooked')
                done()
            )
        it "will let you hook a write", (done) ->
            server.hook('save', 'withtimestamp', (context, next) ->
                console.log 'hook 1'
                context.val = context.val or {}
                #on purpose, make sure we don't double hook, but that
                #the resulting hook value is saved below with durably.
                stashAt = context.val.at = Date.now()
                next()
            ).hook('save', 'withtimestamp', (context, next) ->
                console.log 'hook 2'
                context.val.name = 'Fred'
                next()
            ).hook('save', 'withtimestamp', (context, next) ->
                console.log 'hook 3'
                #make type a write once property
                if context?.prev?.type
                    context.val.type = context.prev.type
                next()
            ).hook('save', 'withtimestamp', (context, next) ->
                console.log 'hook 4'
                #and link to other data, looping back to the server
                context.link('hello', (snapshot) ->
                    console.log 'hook 4 linko'
                    context.val.message = snapshot
                    next()
                )
            ).hook('link', 'hello', (context, next) ->
                context.val = 'hello'
                next()
            )
            client.link('withtimestamp', (error, snapshot) ->
                console.log 'snappy', snapshot
                ###
                                at: stashAt
                                name: 'Fred'
                                type: 'monster'
                                message: 'hello'
                ###
            ).save({type: 'monster'}).save({type: 'nonmonster'})
        it "will let you link to other data in a hook, and save it", (done) ->
            server.hook('save', '/modifier', (context, next) ->
                #linking to other data, saving it, and only coming out of
                #the hook when complete
                context
                    .link('/modified')
                    .on('save', (snapshot) ->
                        next()
                    )
                    .save(context.val)
            )
            request(app)
                .put('/mounted/modifier')
                .send('X')
                .expect(200)
                .end ->
                    request(app)
                        .get('/mounted/modified')
                        .expect(200)
                        .expect('X')
                        .end(done)
        it "will let you link to other data in a hook, and delete it", (done) ->
            server.hook('save', '/remover', (context, next) ->
                #link to some other data and delete it
                context
                    .link('/removed')
                    .on('remove', (snapshot) ->
                        next()
                    )
                    .remove()
            )
            #now set up some data that will be deleted by the link
            request(app)
                .put('/mounted/removed')
                .send('X')
                .expect(200)
                .end ->
                    request(app)
                        .get('/mounted/removed')
                        .expect('X')
                        .end ->
                            #hah -- kill it  with the link
                            request(app)
                                .put('/mounted/remover')
                                .send('Y')
                                .expect(200)
                                .end ->
                                    #yep -- all gone, undefined, 404
                                    request(app)
                                        .get('/mounted/removed')
                                        .expect(404)
                                        .end done
        it "will let you hook a remove", (done) ->
            server.hook('remove', '/immortal', (context, next) ->
                context.abort()
                #aborted, no need for next
            )
            request(app)
                .put('/mounted/immortal')
                .send('Zeus')
                .expect 200, ->
                    request(app)
                        .del('/mounted/immortal')
                            .expect(500)
                            .end ->
                                request(app)
                                    .get('/mounted/immortal')
                                    .expect('Content-Type', /text/)
                                    .expect(200)
                                    .expect('Zeus', done)
        it "will let you hook posting to an array", (done) ->
            server.hook('splice', '/things', (context, next) ->
                #put in another item for every item
                context.val.elements.push 'Another Item'
                next()
            )
            request(app)
                .post('/mounted/things')
                .send('Item One')
                .expect(200)
                .end ->
                    request(app)
                        .get('/mounted/things')
                        .expect('Content-Type', /json/)
                        .expect(200)
                        .expect(['Item One', 'Another Item'], done)
        it "will give you an error message with hook exceptions", (done) ->
            server.hook('link', '/error', (context, next) ->
                throw "Oh my!"
            )
            request(app)
                .get('/mounted/error')
                .expect(500)
                .expect('Oh my!', done)
        it "will give you an error message with hook error callbacks", (done) ->
            server.hook('link', '/error', (context, next) ->
                next("Oh my!")
            )
            request(app)
                .get('/mounted/error')
                .expect(500)
                .expect('Oh my!', done)

Fire up again, should have the log playback. This proves we can come back from
a restart/crash.

    describe "REST API durably", ->
        app = null
        server = null
        before ->
            app = connect()
            server = new sky.Server(options)
            app.use '/mounted', server.rest
        after (done) ->
            server.shutdown done
        it "recovers previous commands", (done) ->
            request(app)
                .get('/mounted/message')
                .expect('Content-Type', /json/)
                .expect(200)
                .expect({hi: 'dad', from: ['you']}, done)
        it "recovers the result of hooks", (done) ->
            request(app)
                .get('/mounted/withtimestamp')
                .expect('Content-Type', /json/)
                .expect(200)
                .expect(
                    at: stashAt
                    name: 'Fred'
                    type: 'monster'
                    message: 'hello'
                ).end(done)