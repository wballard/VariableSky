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
                context.val = context.val or {}
                #on purpose, make sure we don't double hook, but that
                #the resulting hook value is saved below with durably.
                stashAt = context.val.at = Date.now()
                next()
            ).hook('save', 'withtimestamp', (context, next) ->
                context.val.name = 'Fred'
                next()
            ).hook('save', 'withtimestamp', (context, next) ->
                #make type a write once property
                if context?.prev?.type
                    context.val.type = context.prev.type
                next()
            ).hook('save', 'withtimestamp', (context, next) ->
                #and link to other data, looping back to the server
                context.link('hello', (error, snapshot) ->
                    context.val.message = snapshot
                    next()
                )
            ).hook('link', 'hello', (context, next) ->
                context.val = 'hello'
                next()
            )
            client.link('withtimestamp', (error, snapshot) ->
                if snapshot and this.count is 3
                    snapshot.at.should.equal(stashAt)
                    snapshot.name.should.equal('Fred')
                    snapshot.type.should.equal('monster')
                    snapshot.message.should.equal('hello')
                    done()
            ).save({type: 'monster'}).save({type: 'nonmonster'})
        it "will let you link to other data in a hook, and save it", (done) ->
            server.hook('save', 'modifier', (context, next) ->
                #linking to other data, saving it, and only coming out of
                #the hook when complete
                context.link('modified').save(context.val, ->
                    next()
                )
            )
            client.link('modified', (error, snapshot) ->
                if this.count is 2
                    snapshot.should.equal('X')
                    done()
            )
            client.link('modifier').save('X')
        it "will let you link to other data in a hook, and delete it", (done) ->
            server.hook('save', 'remover', (context, next) ->
                #link to some other data and delete it
                context.link('removed').remove(next)
            )
            #now set up some data that will be deleted by the link
            client.link('removed', (error, snapshot) ->
                if this.count is 2
                    snapshot.should.equal('X')
                if this.count is 3
                    should.not.exist(snapshot)
                    done()
            ).save('X')
            #and cross delete
            client.link('remover').save('Y')
        it "will let you hook a remove to prevent it", (done) ->
            server.hook('remove', 'immortal', (context, next) ->
                context.abort()
                #aborted, no need for next
            )
            client
                .link('immortal')
                .save('Zeus')
                .remove( (error) ->
                    error.name.should.equal("HOOK_ABORTED")
                    client.link('immortal', (error, snapshot) ->
                        console.log 'linkback', error, snapshot
                        snapshot.should.equal('Zeus')
                        done()
                    )
                )
        it "will let you hook posting to an array", (done) ->
            server.hook('splice', 'things', (context, next) ->
                #put in another item for every item
                context.elements.push 'Another Item'
                next()
            )
            client.link('things').push('Item One', (error, snapshot) ->
                snapshot.should.eql(['Item One', 'Another Item'])
                done()
            )
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
