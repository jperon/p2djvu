-- Traitement d'une page unique : rendu MuPDF -> binarisation/encodage djvulibre.
{:binarize} = require "pipeline.binarize"
{:downsample} = require "pipeline.image"
{:build, :write} = require "pipeline.sepfile"
encode = require "pipeline.djvu_encode"

-- doc : ffi.mupdf.Document. page_number : 0-indexé. opts :
--   mode: "bw" | "color" | "mixed" (défaut "mixed")
--   mask_dpi: résolution du rendu servant au masque/texte (défaut 300)
--   bg_width: largeur cible du fond couleur en pixels (défaut 300, mode mixte)
--   text: booléen, inclure le calque texte extrait du PDF (défaut true)
--   bw_threshold: seuil de binarisation absolu (0-255), court-circuite l'Otsu
--     automatique (modes "bw" et "mixed")
--   bw_bias: décalage appliqué au seuil d'Otsu calculé automatiquement
--     (modes "bw" et "mixed", ignoré si bw_threshold est fourni)
--   tmp_dir: répertoire de travail pour les fichiers intermédiaires
-- out_path : chemin du fichier .djvu de sortie pour cette page.
process_page = (doc, page_number, opts, out_path) ->
  mode = opts.mode or "mixed"
  mask_dpi = opts.mask_dpi or 300
  bg_width = opts.bg_width or 300
  want_text = opts.text != false
  tmp_dir = opts.tmp_dir or "/tmp"

  pix = doc\render_page page_number, mask_dpi
  mask = binarize pix, {threshold: opts.bw_threshold, bias: opts.bw_bias}

  lines = nil
  if want_text
    ok, result = pcall -> doc\extract_text_lines page_number
    lines = result if ok and #result > 0

  switch mode
    when "bw"
      pbm_path = "#{tmp_dir}/page-#{page_number}.pbm"
      require("pipeline.binarize").write_pbm mask, pbm_path
      encode.encode_bw pbm_path, out_path
      os.remove pbm_path

    when "color"
      ppm_path = "#{tmp_dir}/page-#{page_number}.ppm"
      require("pipeline.image").write_ppm pix, ppm_path
      encode.encode_color ppm_path, out_path
      os.remove ppm_path

    else -- "mixed"
      background = downsample pix, bg_width
      sep_path = "#{tmp_dir}/page-#{page_number}.sep"
      write mask, background, lines, mask_dpi, sep_path
      encode.encode_mixed sep_path, mask_dpi, out_path
      os.remove sep_path

  out_path

{:process_page}
