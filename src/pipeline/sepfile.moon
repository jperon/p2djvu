-- Assemblage d'un fichier "séparé" pour csepdjvu (man csepdjvu) : avant-plan
-- RLE bitonal (R4) + fond PPM optionnel + commentaires de calque texte.
{:encode_r4} = require "pipeline.binarize"
{:ppm_bytes} = require "pipeline.image"

-- Échappe une chaîne pour le format "chaîne Postscript" utilisé par les
-- commentaires csepdjvu : parenthèses et antislash protégés.
escape_ps_string = (s) ->
  (s\gsub("\\", "\\\\")\gsub("%(", "\\(")\gsub("%)", "\\)"))

-- lines : résultat de Document:extract_text_lines (espace page, points,
-- origine haut-gauche). mask_width/mask_height : dimensions en pixels de
-- l'avant-plan encodé (R4), dpi : résolution utilisée pour ce rendu.
-- Approximation : la ligne de base est prise au coin bas-gauche de la bbox,
-- déplacement le long de l'axe x uniquement (texte horizontal, cas courant).
text_comments = (lines, mask_height, dpi) ->
  scale = dpi / 72
  parts = {}
  for line in *lines
    x = math.floor line.x0 * scale
    y = math.floor(mask_height - line.y1 * scale) -- origine bas-gauche pour csepdjvu
    w = math.ceil (line.x1 - line.x0) * scale
    h = math.ceil (line.y1 - line.y0) * scale
    text = escape_ps_string line.text
    table.insert parts, "# T #{x}:#{y} #{w}:0 #{w}x#{h}+#{x}+#{y} (#{text})\n"
  table.concat parts

-- mask : résultat de binarize.binarize(). background_pix : Pixmap (ou nil
-- pour fond blanc uniforme). lines : résultat de extract_text_lines, ou nil.
build = (mask, background_pix, lines, dpi) ->
  parts = {encode_r4 mask}
  table.insert parts, ppm_bytes(background_pix) if background_pix
  table.insert parts, text_comments(lines, mask.height, dpi) if lines
  table.concat parts

write = (mask, background_pix, lines, dpi, path) ->
  f = assert io.open path, "wb"
  f\write build(mask, background_pix, lines, dpi)
  f\close!

{:build, :write, :text_comments}
