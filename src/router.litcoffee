Yes. I broke down and made a router. This is asynchronous only, and focused on context
and dispatch on named strings to callbacks.

    EventEmitter = require('events').EventEmitter
    _ = require('lodash')

    class ExactRouter extends EventEmitter
        constructor: () ->
            @methods = {}

For a named method, install a route. If matched, fire callback. If multiple routes
are installed, they will be called in order asynchronously as each callback completes.

Callbacks are of the form `(context, done)`, if all is well, call `done()`, otherwise
call `done(error)`, which ends the callback link chain.

        on: (method, route, callback) ->
            chain = @methods[method] or []
            newLink =
                route: route
                callback: callback
            chain.push newLink
            @methods[method] = chain

Goodbye, cruel route.

        off: (method, route, callback) ->
            chain = @methods[method] or []
            @methods[method] = _.reject(chain, (x) ->
                x.route == route and x.callback == callback
            )

All the routes in the router.

        all: (method) =>
            @methods[method] or []

Match a route and a link on the chain. This works on strings.

        match: (dispatchRoute, linkRoute) ->
            return dispatchRoute == linkRoute

Fire all installed callbacks, if any for the method and route. Each callback is fired until
they are all done calling `done()`, or you hit an error, in which case `done(error)` is called.

If there are no matching callbacks, `done()` is called. No news is good news.

        dispatch: (method, route, context, done) ->
            links = @methods[method] or []

Each link is a step in the route chain.

            step = (index) =>

End of iteration, fire the final callback without error.

                if index > (links.length-1)
                    done()
                else

Match or not, either way advance along the links. Unless there is an error
which calls back error. This looks for both explicit error callbacks as well
as escaping exceptions.

                    link = links[index]
                    if @match(route, link.route)
                        try
                            link.callback context, (error) ->
                                if error
                                    done(error)
                                else
                                    step(index+1)
                        catch error
                            done(error)
                    else
                        step(index+1)

Start it up, iteration will then stepwise callback.

            step(0)

Special case for prefix matches. Used for hierarchial data routing.

    class PrefixRouter extends ExactRouter
        match: (dispatchRoute, linkRoute) ->
            (dispatchRoute + '.').indexOf(linkRoute + '.') is 0

    module.exports.ExactRouter = ExactRouter
    module.exports.PrefixRouter = PrefixRouter
