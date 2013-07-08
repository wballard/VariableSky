The most basic interactions are with REST, this makes a workable server, the only
sad part is that it doesn't have events and thus no replication.

    request = require 'supertest'
    sky = require('../index')
    path = require('path')
    wrench = require('wrench')

This is a side effect test variable to make sure we are journaling post hook.

    stashAt = 0

The REST API.

    options =
        storageDirectory: path.join __dirname, '.test'

    describe "REST API", ->
        app = null
        server = null
        before ->
            wrench.rmdirSyncRecursive options.storageDirectory, true
            app = require('express')()
            server = new sky.Server(options)
            app.use '/mounted', server.rest
        after (done) ->
            server.shutdown done
        it "404s when you ask for the unknown", (done) ->
            request(app)
                .get('/mounted/message')
                .expect(404)
                .expect({name: 'NOT_FOUND', message: 'message'}, done)
        it "will let you PUT structured data", (done) ->
            request(app)
                .put('/mounted/message')
                .send({hi: "mom"})
                .expect(200, done)
        it "will let you PUT scalar data", (done) ->
            request(app)
                .put('/mounted/scalar')
                .send('bork')
                .expect(200)
                .end ->
                    request(app)
                        .get('/mounted/scalar')
                        .expect(200)
                        .expect('bork', done)
        it "will then GET that data back", (done) ->
            request(app)
                .get('/mounted/message')
                .expect('Content-Type', /json/)
                .expect(200)
                .expect({hi: "mom"}, done)
        it "will let you DELETE", (done) ->
            request(app)
                .del('/mounted/message/hi')
                .expect(200, done)
        it "will let you PUT individual properties", (done) ->
            request(app)
                .put('/mounted/message/hi')
                .send("dad")
                .expect 200, ->
                    request(app)
                        .get('/mounted/message')
                        .expect('Content-Type', /json/)
                        .expect(200)
                        .expect({hi: "dad"}, done)
        it "will let you POST, adding to an array", (done) ->
            request(app)
                .post('/mounted/message/from')
                .send('me')
                .expect 200, ->
                    request(app)
                        .get('/mounted/message/from')
                        .expect('Content-Type', /json/)
                        .expect(200)
                        .expect(['me'], done)
        it "will let you POST to an array again", (done) ->
            request(app)
                .post('/mounted/message/from')
                .send('you')
                .expect 200, ->
                    request(app)
                        .get('/mounted/message/from')
                        .expect('Content-Type', /json/)
                        .expect(200)
                        .expect(['me', 'you'], done)
        it "will let you DELETE an array index", (done) ->
            request(app)
                .del('/mounted/message/from/0')
                .expect 200, ->
                    request(app)
                        .get('/mounted/message/from')
                        .expect('Content-Type', /json/)
                        .expect(200)
                        .expect(['you'], done)
        it "will not let you POST to a non array", (done) ->
            request(app)
                .post('/mounted/message/hi')
                .send('me')
                .expect(405)
                .expect('Allow', 'GET, PUT, DELETE')
                .end(done)
        it "will let you hook a read", (done) ->
            #notice that this is relative
            server.hook('link', '/message', (context, next) ->
                context.val =
                    totally: "different"
                next()
            ).hook('link', '/message', (context, next) ->
                context.val.double = "hooked"
                next()
            )
            request(app)
                .get('/mounted/message')
                .expect('Content-Type', /json/)
                .expect(200)
                .expect({totally: "different", double: "hooked"}, done)
        it "will let you hook a write", (done) ->
            server.hook('save', '/withtimestamp', (context, next) ->
                context.val = context.val or {}
                #on purpose, make sure we don't double hook, but that
                #the resulting hook value is saved below with durably.
                stashAt = context.val.at = Date.now()
                next()
            ).hook('save', '/withtimestamp', (context, next) ->
                context.val.name = 'Fred'
                next()
            ).hook('save', '/withtimestamp', (context, next) ->
                #make type a write once property
                if context?.prev?.type
                    context.val.type = context.prev.type
                next()
            ).hook('save', '/withtimestamp', (context, next) ->
                #and link to other data, notice this is root relative,
                #not mount point relative
                link = context.link('/hello')
                link.on 'link', (snapshot) ->
                    context.val.message = snapshot
                    next()
            ).hook('link', '/hello', (context, next) ->
                context.val = 'hello'
                next()
            )

            request(app)
                .put('/mounted/withtimestamp')
                .send({type: 'monster'})
                .expect(200)
                .end ->
                    request(app)
                        .put('/mounted/withtimestamp')
                        .send({type: 'nonmonster'})
                        .expect(200)
                        .end ->
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
                console.log 'splicing'
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
        it "will give you an error message with hook exceptions on GET", (done) ->
            server.hook('link', '/error', (context, next) ->
                throw "Oh my!"
            )
            request(app)
                .get('/mounted/error')
                .expect(500)
                .expect('Oh my!', done)
        it "will give you an error message with hook exceptions on PUT", (done) ->
            server.hook('save', '/error', (context, next) ->
                throw "Oh gosh!"
            )
            request(app)
                .put('/mounted/error')
                .send('')
                .expect(500)
                .expect('Oh gosh!', done)


Fire up again, should have the log playback. This proves we can come back from
a restart/crash.

    describe "REST API durably", ->
        app = null
        server = null
        before ->
            app = require('express')()
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
