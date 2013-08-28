The most basic server self tests are here.

    sky = require('../index')
    path = require('path')
    wrench = require('wrench')
    connect = require('connect')
    should = require('chai').should()
    deferred = require('deferred')

This is a side effect test variable to make sure we are journaling post hook.

    stashAt = 0

    options =
      storageDirectory: path.join __dirname, '.test'

    wrench.rmdirSyncRecursive options.storageDirectory, true

# Client Works-At-All

Client library tests, the most interesting thing is this is a self connecting /
reconnecting client, so you don't wait for it to open, you just start doing
stuff and it will queue.

    describe "Client", ->
      server = null
      httpserver = null
      before (done) ->
        app = connect()
        httpserver = require('http').createServer(app)
        server = new sky.Server(options)
        server.listen app, httpserver
        httpserver.listen 9999, ->
          done()
      after (done) ->
        httpserver.close ->
          server.shutdown ->
            done()
      it "will queue up actions so you don't need to wait for an open", (done) ->
        client = new sky.Client('ws://localhost:9999/variablesky')
        client.link('qbert', (error, snapshot) ->
          if this.count is 2
            snapshot.should.eql('boop')
            client.close done
        )
        .save('boop')
      it "will let you save data", (done) ->
        client = new sky.Client('ws://localhost:9999/variablesky')
        link = client.link 'smurfs', (error, snapshot) ->
          if this.count is 3
            snapshot.should.eql
              hi: 'there'
              from: 'me'
            client.close done
        link.save(hi: 'there').merge(from: 'me')
      it "lets you directly send messages to other clients", (done) ->
        one = new sky.Client('ws://localhost:9999/variablesky')
        two = new sky.Client('ws://localhost:9999/variablesky')
        one.on 'A-topic', (value, from) ->
          value.should.eql('yep')
          from.should.eql(two.client)
          one.close ->
            two.close ->
              done()
        two.send(one.client, 'A-topic', 'yep')
      it "lets you broadcast messages to multiple clients", (done) ->
        one = new sky.Client('ws://localhost:9999/variablesky')
        two = new sky.Client('ws://localhost:9999/variablesky')
        onedef = deferred()
        twodef = deferred()
        one.on 'A', (value, from) ->
          value.should.eql('go')
          onedef.resolve(value)
        two.on 'A', (value, from) ->
          value.should.eql('go')
          twodef.resolve(value)
        deferred(onedef.promise, twodef.promise).then ->
          one.close ->
            two.close ->
              done()
        one.send('A', 'go')


# Server Hooks

    describe "Hooks", ->
      client = null
      server = null
      httpserver = null
      before (done) ->
        app = connect()
        httpserver = require('http').createServer(app)
        server = new sky.Server(options)
        server.listen app, httpserver
        httpserver.listen 9999, ->
          client = new sky.Client('ws://localhost:9999/variablesky')
          done()
      after (done) ->
        client.close ->
          server.shutdown ->
            httpserver.close ->
              done()
      afterEach ->
        client.links.forEach (x) -> x.close()
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
        )
        client.link('withtimestamp', (error, snapshot) ->
          if snapshot and this.count is 3
            snapshot.at.should.equal(stashAt)
            snapshot.name.should.equal('Fred')
            snapshot.type.should.equal('monster')
            done()
        ).save({type: 'monster'}).save({type: 'nonmonster'})
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
      client = null
      server = null
      httpserver = null
      before (done) ->
        app = connect()
        httpserver = require('http').createServer(app)
        server = new sky.Server(options)
        server.listen app, httpserver
        httpserver.listen 9999, ->
          client = new sky.Client('ws://localhost:9999/variablesky')
          done()
      after (done) ->
        client.close ->
          server.shutdown ->
            httpserver.close ->
              done()
      afterEach ->
        client.links.forEach (x) -> x.close()
      it "recovers previous commands", (done) ->
        client.link 'immortal', (error, snapshot) ->
          snapshot.should.eql('Zeus')
          done()
      it "recovers the result of hooks", (done) ->
        client.link 'withtimestamp', (error, snapshot) ->
          snapshot.should.eql(
            at: stashAt
            name: 'Fred'
            type: 'monster'
          )
          done()
