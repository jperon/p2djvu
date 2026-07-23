-- OCR de secours (tesseract) pour les pages sans texte PDF intégré.
-- Produit des lignes {x0,y0,x1,y1,text} en pixels (origine haut-gauche),
-- compatibles avec le format attendu par pipeline.sepfile.text_comments
-- une fois convertie l'échelle (voir page.moon : mêmes DPI que le rendu).
{:run} = require "pipeline.shell"
{:write_ppm} = require "pipeline.image"

-- pix : Pixmap rendu à la résolution voulue pour l'OCR. tmp_dir : répertoire de travail.
-- Retourne une liste de lignes en coordonnées PIXELS (pas en points, contrairement
-- à extract_text_lines de MuPDF) : page.moon doit donc les traiter séparément.
recognize_lines = (pix, tmp_dir, page_number) ->
  ppm_path = "#{tmp_dir}/ocr-#{page_number}.ppm"
  write_ppm pix, ppm_path
  tsv_base = "#{tmp_dir}/ocr-#{page_number}"

  ok, msg = run "tesseract", {ppm_path, tsv_base, "tsv"}
  os.remove ppm_path
  error msg unless ok

  tsv_path = tsv_base .. ".tsv"
  f = assert io.open tsv_path, "r"
  header = f\read "*l"

  by_line = {}
  order = {}
  for row in f\lines!
    fields = [v for v in row\gmatch "[^\t]*"]
    -- colonnes tesseract --tsv : level page_num block_num par_num line_num word_num left top width height conf text
    continue if #fields < 12
    level, block, par, line_no = tonumber(fields[1]), fields[3], fields[4], fields[5]
    left, top, width, height = tonumber(fields[7]), tonumber(fields[8]), tonumber(fields[9]), tonumber(fields[10])
    text = fields[12]
    continue if level != 5 or not text or text == ""

    key = "#{block}:#{par}:#{line_no}"
    unless by_line[key]
      by_line[key] = {x0: left, y0: top, x1: left + width, y1: top + height, words: {}}
      table.insert order, key
    entry = by_line[key]
    entry.x0 = math.min entry.x0, left
    entry.y0 = math.min entry.y0, top
    entry.x1 = math.max entry.x1, left + width
    entry.y1 = math.max entry.y1, top + height
    table.insert entry.words, text
  f\close!
  os.remove tsv_path

  lines = {}
  for key in *order
    e = by_line[key]
    table.insert lines, {x0: e.x0, y0: e.y0, x1: e.x1, y1: e.y1, text: table.concat(e.words, " ")}
  lines

{:recognize_lines}
