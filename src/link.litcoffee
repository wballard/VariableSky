Link to data on a `Blackboard` by `href`.

    server = require('./server')

    class Link
        constructor: (blackboard, href) ->
            @href = server.parsePath(href)
            @val = blackboard.valueAt(@href)

    module.exports = Link
