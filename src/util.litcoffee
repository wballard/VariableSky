
    _ = require('lodash')
    path = require('path')

Paths are always something to deal with. Here is the general representation,
an array of path segments.

    module.exports.parsePath = (path) ->
        if _.isArray(path)
            path
        else
            _(path.split('.'))
                .filter((x) -> x.length)
                .value()

And sometimes you have a parsed path and just want a string for it.

    module.exports.packPath = (pathArray) ->
        "#{pathArray.join('.')}"

    module.exports.trace = (todo, rest...) ->
        todo.__trace__ = true
        console.log ''
        if todo.__from_server__
            console.log '<------'
        else
            console.log '------>'
        console.log todo
