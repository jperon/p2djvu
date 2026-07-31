-- Génère le texte caché DjVu (format lisp attendu par `djvused ... set-txt`)
-- à partir des lignes extraites par Document:extract_text_lines (espace
-- page, points, origine haut-gauche). Utilisé pour les modes "bw"/"color",
-- qui (contrairement au mode "mixed") n'encodent pas via csepdjvu et n'ont
-- donc pas de canal de commentaires texte intégré à l'encodage lui-même :
-- le calque texte y est injecté après coup via `djvused set-txt`.
--
-- width/height : dimensions en pixels de la page encodée (mask_dpi). dpi :
-- résolution utilisée pour ce rendu (pour passer de points à pixels).

escape_djvu_string = (s) ->
  (s\gsub("\\", "\\\\")\gsub('"', '\\"'))

build_hidden_text = (lines, width, height, dpi) ->
  scale = dpi / 72
  parts = {"(page 0 0 #{width} #{height}\n"}
  for line in *lines
    x0 = math.floor line.x0 * scale
    x1 = math.ceil line.x1 * scale
    -- DjVu text zones use a bottom-left origin; extract_text_lines gives
    -- top-left-origin coordinates (see ffi.mupdf), hence the y-flip.
    y0 = math.floor(height - line.y1 * scale)
    y1 = math.ceil(height - line.y0 * scale)
    text = escape_djvu_string line.text
    table.insert parts, " (line #{x0} #{y0} #{x1} #{y1} \"#{text}\")\n"
  table.insert parts, ")\n"
  table.concat parts

{:build_hidden_text}
