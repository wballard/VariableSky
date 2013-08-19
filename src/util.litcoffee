
    _ = require('lodash')
    path = require('path')

Paths are always something to deal with. Here is the general representation,
an array of path segments.

    module.exports.parsePath = (path) ->
      path = path or ''
      if _.isArray(path)
        path
      else
        _(path.split('.'))
          .filter((x) -> x.length)
          .value()

And sometimes you have a parsed path and just want a string for it.

    module.exports.packPath = (pathArray) ->
      if _.isString(pathArray)
        pathArray
      else
        pathArray = pathArray or []
        "#{pathArray.join('.')}"

    module.exports.inspect =  (thing) ->
      if window?
        thing
      else
        require('eyes').inspector({ stream: null })(thing)
