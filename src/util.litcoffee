
    _ = require('lodash')
    path = require('path')

Paths are always something to deal with. Here is the general representation,
an array of path segments.

    module.exports.parsePath = (path) ->
        if _.isArray(path)
            path
        else
            _(path.split('/'))
                .map(decodeURIComponent)
                .filter((x) -> x.length)
                .value()
