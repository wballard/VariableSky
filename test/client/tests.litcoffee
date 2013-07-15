Test scenarios that use the client library from a browser.

    describe "Socket API", ->
        conn = null
        otherConn = null
        should = chai.should()

Two connections, there are a lot of scenarios that are about cross browser
eventing, so we simulate these with two connections.

        before (done) ->
            conn = variablesky.connect()
            conn.on 'connection', ->
                otherConn = variablesky.connect()
                otherConn.on 'connection', ->
                    done()

        after (done) ->
            conn.close()
            otherConn.close()
            done()

        it "can connect", (done) ->
            done()

        it "can get data at all", (done) ->
            conn.link('/test').on 'link', (snapshot) ->
                done()

        it "can save data, and read it back", (done) ->
            conn.link('/testback').on('save', (snapshot) ->
                snapshot.a.should.equal(1)
                done()
            )
            .save(a: 1)

        it "can remove previously saved data", (done) ->
            link = conn.link('/testremove')
            .on('remove', (snapshot) ->
                console.log 'remove', snapshot
                done()
            )
            .on('link', (snapshot) ->
                console.log 'link', snapshot
            )
            .on('save', (snapshot) ->
                console.log 'save', snapshot
            )
            .save(a: 1)
            .remove()

        it "will notify other connections on save", (done) ->
            conn.link('/testcross').on('save', (snapshot) ->
                done()
            )
            otherConn.link('/testcross')
            .save('Hi')

        it "will replicate variables between connections", (done) ->
            #the connection that is going to get another's save
            conn.link('/replicated').on('change', (snapshot) ->
                snapshot.hi.should.equal('mom')
                snapshot.should.equal(this.val)
                snapshot.should.equal(conn.replicated)
                done()
            )
            #the save
            otherConn.link('/replicated')
            .save(hi: 'mom')
