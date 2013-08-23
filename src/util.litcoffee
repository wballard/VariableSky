
    _ = require('lodash')
    path = require('path')

## parsePath(path)
Paths are always something to deal with. Here is the general representation,
an array of path segments.

    parsePath = (path) ->
      path = path or ''
      if _.isArray(path)
        path
      else
        _(path.split('.'))
          .filter((x) -> x.length)
          .value()

## packPath(array)
And sometimes you have a parsed path and just want a string for it.

    packPath = (pathArray) ->
      if _.isString(pathArray)
        pathArray
      else
        pathArray = pathArray or []
        "#{pathArray.join('.')}"

## inspect(thing)
Context specific object dumper, uses coloring if you are servery, and the
console log if you are browsery.

    inspect = (thing) ->
      if window?
        thing
      else
        require('eyes').inspector({ stream: null })(thing)

    module.exports =
      parsePath: parsePath
      packPath: packPath
      inspect: inspect
