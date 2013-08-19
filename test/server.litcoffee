The most basic server self tests are here.

    sky = require('../index')
    path = require('path')
    wrench = require('wrench')
    connect = require('connect')
    should = require('chai').should()

This is a side effect test variable to make sure we are journaling post hook.

    stashAt = 0

    options =
        storageDirectory: path.join __dirname, '.test'

    wrench.rmdirSyncRecursive options.storageDirectory, true

Client library tests, the most interesting thing is this is a self connecting /
reconnecting client, so you don't wait for it to open, you just start doing
stuff and it will queue.

    describe "Client", ->
        server = null
        httpserver = null
        before (done) ->
            app = connect()
            httpserver = require('http').createServer(app)
            server = new sky.Server(options).traceOn()
            server.listen app, httpserver
            httpserver.listen 9999, ->
                done()
        after (done) ->
            httpserver.close ->
                server.shutdown ->
                    done()
        it "will queue up actions so you don't need to wait for an open", (done) ->
            client = new sky.Client('ws://localhost:9999/variablesky').traceOn()
            client.link('qbert', (error, snapshot) ->
                if this.count is 2
                    snapshot.should.eql('boop')
                    client.close done
            )
            .save('boop')

Server side hooks.

    describe "Hooks", ->
        client = null
        server = null
        httpserver = null
        before (done) ->
            app = connect()
            httpserver = require('http').createServer(app)
            server = new sky.Server(options).traceOn()
            console.log 'ggggg'
            server.listen app, httpserver
            console.log 'iggggg'
            httpserver.listen 9999, ->
                console.log 'iiggggg'
                client = new sky.Client('ws://localhost:9999/variablesky')
                done()
        after (done) ->
            client.close ->
                server.shutdown ->
                    httpserver.close ->
                        done()
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
                context.link('modified').save(context.val, next)
            )
            client.link('modified', (error, snapshot) ->
                if this.count is 3
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
                if this.count is 4
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
                        snapshot.should.equal('Zeus')
                        done()
                    )
                )
        it "will let you hook posting to an array", (done) ->
            server.hook('save', 'things', (context, next) ->
                #put in another item for every item
                context.val.push 'Another Item'
                next()
            )
            client.link('things').save(['Item One'], (error, snapshot) ->
                snapshot.should.eql(['Item One', 'Another Item'])
                done()
            )
        it "will save a diff to directly modified array", (done) ->
            link = client.link('morethings').save(['One'], (error, snapshot) ->
                snapshot.should.eql(['One'])
                snapshot.push('Two')
                link.save(snapshot, (error, s2) ->
                    s2.should.eql(['One', 'Two'])
                    client.link('morethings', (error, final) ->
                        final.should.eql(['One', 'Two'])
                        done()
                    )
                )
            )
        it "will give you an error message with hook exceptions", (done) ->
            server.hook('link', 'error', (context, next) ->
                throw "Oh my!"
            )
            client.link('error', (error, snapshot) ->
                error.should.eql('Oh my!')
                should.not.exist(snapshot)
                done()
            )
        it "will give you an error message with hook error callbacks", (done) ->
            server.hook('link', 'error.2', (context, next) ->
                next("Oh my!!")
            )
            client.link('error.2', (error, snapshot) ->
                error.should.eql('Oh my!!')
                should.not.exist(snapshot)
                done()
            )

Fire up again, should have the log playback. This proves we can come back from
a restart/crash.

    describe "Hooks -- durable server", ->
        server = null
        before (done) ->
            server = new sky.Server(options)
            server.on 'recovered', ->
                done()
        after (done) ->
            server.shutdown done
        it "recovers previous commands", (done) ->
            server.processor.blackboard.immortal.should.eql('Zeus')
            done()
        it "recovers the result of hooks", (done) ->
            server.processor.blackboard.withtimestamp.should.eql(
                at: stashAt
                name: 'Fred'
                type: 'monster'
                message: 'hello'
            )
            done()
