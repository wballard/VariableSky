Error making macros.

    module.exports =
        NOT_FOUND: (href) ->
            name: "NOT_FOUND"
            message: href.join('/')
        NO_SUCH_COMMAND: (command) ->
            name: "NO_SUCH_COMMAND"
            message: command
        PARSE_ERROR: (err) ->
            name: "PARSE_ERROR"
            message: "This was no parseable. Sorry"
            err: err
        NOT_AN_ARRAY: (href) ->
            name: "NOT_AN_ARRAY"
            message: href.join('/')
        HOOK_ABORTED: (context) ->
            name: "HOOK_ABORTED"
            message: (context?.href or [])?.join('/')
            context: context
