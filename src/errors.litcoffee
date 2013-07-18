Error making macros.

    module.exports =
        NO_SUCH_COMMAND: (command) ->
            name: "NO_SUCH_COMMAND"
            message: command
        PARSE_ERROR: (err) ->
            name: "PARSE_ERROR"
            message: "This was no parseable. Sorry"
            err: err
        HOOK_ABORTED: (context, message) ->
            name: "HOOK_ABORTED"
            message: message or "The hook was stopped with .abort()"
        NOT_AN_APP: () ->
            name: "NOT_AN_APP"
            message: "Looks like you maybe passed something that isn't express or connect, it doesn't have .use() method"
