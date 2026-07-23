{:run} = require "cli"

ok, err = pcall run, arg
unless ok
  message = (type(err) == "table" and err.msg) and err.msg or tostring(err)
  io.stderr\write "p2djvu : erreur : #{message}\n"
  os.exit 1
