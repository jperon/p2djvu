-- p2djvu : CLI. Usage: p2djvu [options] input.pdf output.djvu
mupdf = require "ffi.mupdf"
{:process_page} = require "pipeline.page"
encode = require "pipeline.djvu_encode"

parse_args = (argv) ->
  -- "color" est le mode par défaut : robuste sur tout type de contenu. Le
  -- mode "mixed" (avant-plan texte net + fond basse résolution) donne des
  -- fichiers plus légers sur du texte pur, mais son seuillage binaire peut
  -- mal se comporter sur des illustrations très hachurées ou nuancées —
  -- c'est un choix à faire au cas par cas, pas un défaut sûr.
  opts = {mode: "color", mask_dpi: 300, bg_width: 300, text: true, jobs: 1}
  positional = {}
  i = 1
  while i <= #argv
    a = argv[i]
    switch a
      when "--color", "--mode"
        i += 1
        opts.mode = argv[i]
      when "--dpi"
        i += 1
        opts.mask_dpi = tonumber argv[i]
      when "--bg-width"
        i += 1
        opts.bg_width = tonumber argv[i]
      when "--threshold"
        i += 1
        opts.bw_threshold = tonumber argv[i]
      when "--threshold-bias"
        i += 1
        opts.bw_bias = tonumber argv[i]
      when "--normalize-contrast"
        opts.normalize_contrast = true
      when "--contrast-clip"
        i += 1
        opts.contrast_clip = tonumber argv[i]
      when "--no-text"
        opts.text = false
      when "--ocr"
        opts.ocr = true
      when "--jobs"
        i += 1
        opts.jobs = tonumber argv[i]
      else
        table.insert positional, a
    i += 1
  opts, positional

usage = ->
  io.stderr\write [[
Usage: p2djvu [options] <input.pdf> <output.djvu>

Options:
  --mode bw|color|mixed   Mode de sortie (défaut: color)
  --dpi N                 Résolution du rendu / masque (défaut: 300)
  --bg-width N            Largeur du fond couleur en pixels, mode mixte (défaut: 300)
  --threshold N           Seuil de binarisation absolu (0-255), modes bw/mixed
                          (défaut: calculé automatiquement, cf. --threshold-bias)
  --threshold-bias N      Décalage appliqué au seuil calculé automatiquement,
                          modes bw/mixed (négatif = moins d'encre détectée,
                          positif = plus d'encre détectée ; défaut: 0)
  --normalize-contrast    Étire le contraste de chaque page (par canal,
                          indépendamment d'une page à l'autre) avant tout
                          traitement : corrige les pages sépia/grisées et les
                          écarts de niveaux entre pages. Surtout utile en
                          mode bw, mais s'applique à tous les modes.
  --contrast-clip N       Part en % de pixels extrêmes écrêtés par
                          --normalize-contrast (défaut: 0.5)
  --no-text               Ne pas inclure le calque texte extrait du PDF
  --ocr                   OCR de secours (tesseract) si le PDF n'a pas de texte intégré
]]

run = (argv) ->
  opts, positional = parse_args argv
  unless #positional == 2
    usage!
    os.exit 1

  input_path, output_path = positional[1], positional[2]

  tmp_dir = os.tmpname!
  os.remove tmp_dir
  os.execute "mkdir -p '#{tmp_dir}'"
  opts.tmp_dir = tmp_dir

  doc = mupdf.Document input_path
  n = doc\page_count!
  io.stderr\write "p2djvu : #{n} page(s), mode=#{opts.mode}, dpi=#{opts.mask_dpi}\n"

  page_paths = {}
  for i = 0, n - 1
    out = "#{tmp_dir}/out-#{i}.djvu"
    io.stderr\write "  page #{i + 1}/#{n}...\n"
    process_page doc, i, opts, out
    table.insert page_paths, out

  if #page_paths == 1
    os.rename page_paths[1], output_path
  else
    encode.merge_pages page_paths, output_path
    os.remove p for p in *page_paths

  os.execute "rm -rf '#{tmp_dir}'"
  io.stderr\write "p2djvu : écrit #{output_path}\n"

{:run, :parse_args}
