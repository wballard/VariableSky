This is a stream that lets you install dynamic hooks, which are a lot like
[connect] middleware. The difference is, that this works on a single stream
message, not on a (req, res) pairing.

So, you define a matcher, which is message -> String, which then serves as a
routing key. Turn your messages into any string you like this way.

With a matcher in hand, you define a `hook`, which is `(pattern, action)`, you
supply the pattern as a String or a RegExp, and the `action` which is the acual
hook.  This `action` is the middleware bit, and needs to be a function like
`(message, next)`, which you get a chance to modify the message in place.

After all your hooks have had a chance to fire, the message is written out of
the end of the stream, ready to be piped.

    es = require('event-stream')
    _ = require('lodash')

    module.exports = (matcher) ->

This stream flows through a substream before coming back up, this is where
a spot emerges to have a dynamic series of hooks as a pipeline. So by default,
the substream just sends along.

      match = (pattern, str) ->
        if pattern.test
          pattern.test str
        else
          pattern is str

      stream = es.through (message) ->
        segments = _.clone(hooks)
        next = ->
          if segments.length
            segment = segments.shift()
            if match(segment.pattern, matcher(message))
              try
                segment.action message, (err) ->
                  if err
                    message.error = err
                    stream.queue(message)
                  else
                    next()
              catch err
                message.error = err
                stream.queue(message)
            else
              next()
          else
            stream.queue(message)
        next()

Build up the dynamic pipeline as hooks are added. Each hook chains along unless
there is an error, in which case it sends the error up the stream as a stream
error.

      hooks = []
      stream.hook = (pattern, action) ->
        hooks.push
          pattern: pattern
          action: action

      stream
