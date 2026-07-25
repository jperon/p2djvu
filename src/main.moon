{:run} = require "cli"

ok, err = xpcall (-> run arg), (e) ->
  return e if type(e) == "table"
  debug.traceback tostring(e), 2

unless ok
  message = (type(err) == "table" and err.msg) and err.msg or tostring(err)
  io.stderr\write "p2djvu : erreur : #{message}\n"
  os.exit 1
