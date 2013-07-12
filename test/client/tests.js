describe("Socket API", function() {
    var conn;

    before(function(done){
        conn = variablesky.connect();
        conn.on('connection', function(){
            console.log("connected...", conn);
            done();
        });
    });

    it("can connect", function(done){
        done();
    });

    it("can get undefined data", function(done){
        conn.link('/test')
        .on('link', function(snapshot){
            done();
        });
    });
})
