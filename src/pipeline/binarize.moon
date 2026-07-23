-- Binarisation adaptative (seuil d'Otsu) d'un Pixmap RGB MuPDF, et export du
-- résultat aux formats attendus par djvulibre : PBM (mode N&B pur, cjb2) et
-- RLE bitonal "R4" (avant-plan mixte, csepdjvu — cf. man csepdjvu).
ffi = require "ffi"
bit = require "bit"

luminance = (r, g, b) -> math.floor((r * 299 + g * 587 + b * 114) / 1000)

otsu_threshold = (histogram, total) ->
  sum = 0
  for t = 0, 255
    sum += t * histogram[t]

  sum_b, w_b, max_variance, threshold = 0, 0, 0, 127
  for t = 0, 255
    w_b += histogram[t]
    continue if w_b == 0
    w_f = total - w_b
    break if w_f == 0

    sum_b += t * histogram[t]
    m_b = sum_b / w_b
    m_f = (sum - sum_b) / w_f
    variance = w_b * w_f * (m_b - m_f) * (m_b - m_f)

    if variance > max_variance
      max_variance = variance
      threshold = t

  threshold

-- pix : instance Pixmap (src/ffi/mupdf.moon). opts (optionnel) :
--   threshold : seuil absolu (0-255) imposé, court-circuite le calcul d'Otsu.
--   bias      : décalage (positif ou négatif) appliqué au seuil d'Otsu calculé
--               automatiquement (un pixel est classé "encre" si sa luminance
--               est < seuil) ; un bias négatif classe moins de pixels en
--               "encre" (utile sur les illustrations hachurées, cf.
--               --threshold-bias dans le CLI), un bias positif en classe
--               davantage.
-- Retourne {width, height, threshold, rows} où rows[y] est un ffi uint8_t[width] :
-- 1 = encre (noir), 0 = fond (blanc/transparent).
binarize = (pix, opts) ->
  opts or= {}
  histogram = {}
  for t = 0, 255
    histogram[t] = 0
  for y = 0, pix.height - 1
    for x = 0, pix.width - 1
      r, g, b = pix\at x, y
      histogram[luminance r, g, b] += 1

  threshold = opts.threshold or otsu_threshold histogram, pix.width * pix.height
  threshold += opts.bias or 0
  threshold = math.max 0, math.min 255, threshold

  ink_pixels = 0
  for t = 0, threshold - 1
    ink_pixels += histogram[t]
  ink_ratio = ink_pixels / (pix.width * pix.height)

  rows = {}
  for y = 0, pix.height - 1
    row = ffi.new "uint8_t[?]", pix.width
    for x = 0, pix.width - 1
      r, g, b = pix\at x, y
      row[x] = (luminance(r, g, b) < threshold) and 1 or 0
    rows[y + 1] = row

  {width: pix.width, height: pix.height, :threshold, :ink_ratio, :rows}

-- Écrit le résultat de binarize() au format PBM binaire (P4), pour cjb2 (mode N&B pur).
write_pbm = (result, path) ->
  row_bytes = math.floor((result.width + 7) / 8)
  f = assert io.open path, "wb"
  f\write "P4\n#{result.width} #{result.height}\n"
  packed = ffi.new "unsigned char[?]", row_bytes
  for row in *result.rows
    ffi.fill packed, row_bytes, 0
    for x = 0, result.width - 1
      if row[x] == 1
        byte_index = math.floor(x / 8)
        bit_index = 7 - (x % 8)
        packed[byte_index] = bit.bor packed[byte_index], bit.lshift(1, bit_index)
    f\write ffi.string(packed, row_bytes)
  f\close!

-- Encode un entier de run-length au format VLQ de csepdjvu (man csepdjvu,
-- "Bitonal RLE format") : 0-191 sur un octet, 192-16383 sur deux octets.
encode_run_length = (n) ->
  if n <= 191
    string.char n
  else
    -- 6 bits de poids fort dans le premier octet (0xc0 + ...), 8 bits restants dans le second.
    hi = 0xc0 + bit.rshift(n, 8)
    lo = bit.band(n, 0xff)
    string.char(hi, lo)

-- Retourne les octets du flux "R4" (avant-plan bitonal) attendu par csepdjvu :
-- résultat de binarize() -> "R4 W H\n" suivi des runs alternés blanc/noir par ligne
-- (chaque ligne commence par un run blanc, éventuellement de longueur 0).
encode_r4 = (result) ->
  parts = {"R4 #{result.width} #{result.height}\n"}
  for row in *result.rows
    x, run_len, run_is_black = 0, 0, false
    while x < result.width
      pixel_is_black = row[x] == 1
      if pixel_is_black == run_is_black
        run_len += 1
      else
        table.insert parts, encode_run_length run_len
        run_is_black = pixel_is_black
        run_len = 1
      x += 1
    table.insert parts, encode_run_length run_len
  table.concat parts

{:binarize, :write_pbm, :encode_r4, :otsu_threshold, :luminance}
