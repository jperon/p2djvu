-- Utilitaires d'exécution de sous-processus (encodeurs djvulibre, tesseract).
quote = (s) -> "'" .. tostring(s)\gsub("'", "'\\''") .. "'"

-- args : tableau de chaînes. Retourne true, sortie_combinée ou false, message.
run = (cmd, args) ->
  parts = {quote cmd}
  table.insert parts, quote a for a in *args
  full = table.concat(parts, " ") .. " 2>&1"

  handle = assert io.popen full, "r"
  output = handle\read "*a"
  _, _, code = handle\close!
  -- NB : le premier retour de handle:close() (traditionnellement un booléen
  -- "succès") s'est avéré peu fiable sous LuaJIT/io.popen pour des process
  -- ayant échoué (renvoyait true malgré un exit code non nul, cf. le bug
  -- silencieux découvert sur l'injection de texte DjVu) -- on se fie donc
  -- uniquement au code de sortie explicite.
  code = code or 0
  if code == 0
    true, output
  else
    false, "#{cmd} a échoué (code #{code}) : #{output}"

{:run, :quote}
