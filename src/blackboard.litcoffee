This is a big shared memory, a blackboard that all commands can write to. This
provides the location for the variables in the sky to live.

    class Blackboard
        constructor: ->

Get at variables with an array of path segments. This is a bit different
than just going . . .

        valueAt: (href) ->
            at = this
            for segment in href
                if at[segment]
                    at = at[segment]
                else
                    #undefined, not null
                    return
            at

    module.exports = Blackboard
