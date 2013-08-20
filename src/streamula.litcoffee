**Streamula**, puts its fangs into your program and makes everything flow.

More to the point, Streamula uses new and exciting v0.10.x streams to allow
simple functional streaming programming. Use these exciting stream types, pipe
them together and go wild. Wild I say!

    stream = require('stream')

## Notes
All of these streams are classes, but for the object disinclined, you can go
at them with a function too. Save the baby `new`s.

So, for stream `new streamula.Glow()` you can also say `streamula.glow()`. I'm
just that considerate.

## streamula.Map(mapFunction)
Map every incoming object to an output object. This is smart enough that when
it gets a `null` it knows the stream is over and it doesn't bother you.

### mapFunction(value)
This handles the synchronous case, whatever you return will be sent along. If
you come back with a `null`, you are telling everyone downstream that it's all
over.

    class Map extends stream.Transform
      constructor: (@mapFunction)->
        super objectMode: true
      _transform: (object, encoding, callback) ->
        if object
          try
            @push(@mapFunction(object))
            callback()
          catch err
            callback(err)
        else
          @push(null)
          callback()

    module.exports =
      Map: Map
      map: (mapFunction) -> new Map(mapFunction)

