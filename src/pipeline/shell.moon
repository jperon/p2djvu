-- Utilitaires d'exécution de sous-processus (encodeurs djvulibre, tesseract).
quote = (s) -> "'" .. tostring(s)\gsub("'", "'\\''") .. "'"

-- args : tableau de chaînes. Retourne true, sortie_combinée ou false, message.
run = (cmd, args) ->
  parts = {quote cmd}
  table.insert parts, quote a for a in *args
  full = table.concat(parts, " ") .. " 2>&1"

  handle = assert io.popen full, "r"
  output = handle\read "*a"
  ok, _, code = handle\close!

  if ok
    true, output
  else
    false, "#{cmd} a échoué (code #{code}) : #{output}"

{:run, :quote}
