
    window.holdopen = connToBeOrphaned = null
    should = chai.should()

    describe "Client Library", ->
        connToBeOrphaned = null
        before (done) ->
            connToBeOrphaned = variablesky.connect()
            connToBeOrphaned.once 'open', ->
                done()
        it "should auto reconnect", (done) ->
            #this should fire on the reconnect
            connToBeOrphaned.once 'open', ->
                done()
            #HAVOC, poke under the hood to pretend a disconnect
            connToBeOrphaned.dangerClose()
        it "should re-link data", (done) ->
            link = connToBeOrphaned
                .link('reco', (error, snapshot) ->
                    #this will be called three times
                    # * first link
                    # * save
                    # * re-link on the re-open
                    if this.count is 3
                        snapshot.should.eql('yeah')
                        done()
                )
                #force close, which will then re-open, then re-link...
                .save('yeah', (error, snapshot) ->
                    connToBeOrphaned.dangerClose()
                )

Test scenarios that use the client library from a browser.

    describe "Socket API", ->
        conn = null
        otherConn = null

Two connections, there are a lot of scenarios that are about cross browser
eventing, so we simulate these with two connections.

        before (done) ->
            conn = variablesky.connect()
            conn.on 'open', ->
                otherConn = variablesky.connect()
                otherConn.on 'open', ->
                    done()

        after (done) ->
            conn.close()
            otherConn.close()
            done()

        it "can connect", (done) ->
            done()

        it "can get data at all", (done) ->
            conn.link('test').on 'link', (snapshot) ->
                done()

        it "can save data, and read it back", (done) ->
            conn.link('testback').on('save', (snapshot) ->
                snapshot.a.should.equal(1)
                done()
            )
            .save(a: 1)

        it "gets undefined when you ask for stuff that isn't", (done) ->
            conn.link('mysterypants').on('link', (snapshot) ->
                should.not.exist(snapshot)
                done()
            )

        it "can remove previously saved data", (done) ->
            fired = {}
            link = conn.link('testremove')
            .on('remove', (snapshot) ->
                fired.link.should.exist
                fired.save.should.exist
                done()
            )
            .on('link', (snapshot) ->
                fired.link = true
            )
            .on('save', (snapshot) ->
                fired.save = true
            )
            .save(a: 1)
            .remove()

        it "will notify other connections on save", (done) ->
            conn.link('testcross').on('save', (snapshot) ->
                done()
            )
            otherConn.link('testcross')
            .save('Hi')

        it "will replicate variables between connections", (done) ->
            #the connection that is going to get another's save
            conn.link('replicated').on('link', (snapshot) ->
                snapshot.hi.should.equal('mom')
                snapshot.should.equal(this.val)
                snapshot.should.equal(conn.val.replicated)
                done()
            )
            #the save
            otherConn.link('replicated')
            .save(hi: 'mom')

        it "will notify higher up / parent links when child data changes", (done) ->
            #a parent link, link fires on intial link, and then on the save
            #so we pop in a counter
            times = 0
            conn.link('parenty').on('link', (snapshot) ->
                #the parent sees the child value change. neat
                if times++ > 0
                    snapshot.hi.should.equal('mom')
                    done()
            )
            #a child save
            otherConn.link('parenty.hi').save('mom')

        it "will replicate deleted variables between connection", (done) ->
            hasSaved = false
            hasRemoved = false
            conn.link('delicated')
            .on('save', ->
                hasSaved = true
            )
            .on('remove', ->
                hasRemoved = true
            )
            .on('link', (snapshot) ->
                if hasSaved and hasRemoved
                    should.not.exist(snapshot)
                    should.not.exist(this.val)
                    should.not.exist(conn.val.delicated)
                    done()
                    #interlock this test so the final change does not fire
                    hasSaved = false
            )
            #the remove
            otherConn.link('delicated')
                .save(hi: 'mom')
                .remove()
