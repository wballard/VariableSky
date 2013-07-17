Error making macros.

    module.exports =
        NO_SUCH_COMMAND: (command) ->
            name: "NO_SUCH_COMMAND"
            message: command
        PARSE_ERROR: (err) ->
            name: "PARSE_ERROR"
            message: "This was no parseable. Sorry"
            err: err
        HOOK_ABORTED: (context) ->
            name: "HOOK_ABORTED"
            message: context
        NOT_AN_APP: () ->
            name: "NOT_AN_APP"
            message: "Looks like you maybe passed something that isn't express or connect, it doesn't have .use() method"
