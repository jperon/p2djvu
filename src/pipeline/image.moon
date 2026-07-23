-- Utilitaires image : sous-échantillonnage (moyenne par bloc) et export PPM.
-- Opère sur un src/ffi/mupdf.moon Pixmap ou toute table exposant :at(x,y)->r,g,b
-- ainsi que .width/.height.
ffi = require "ffi"

-- Réduit pix à environ target_width de large (facteur entier >= 1), par
-- moyenne de blocs (plus fidèle qu'un plus-proche-voisin pour un fond photo).
downsample = (pix, target_width) ->
  factor = math.max 1, math.floor(pix.width / target_width + 0.5)
  return pix if factor <= 1

  out_w = math.ceil pix.width / factor
  out_h = math.ceil pix.height / factor
  out = ffi.new "uint8_t[?]", out_w * out_h * 3

  for oy = 0, out_h - 1
    for ox = 0, out_w - 1
      sum_r, sum_g, sum_b, n = 0, 0, 0, 0
      y0 = oy * factor
      x0 = ox * factor
      for y = y0, math.min(y0 + factor, pix.height) - 1
        for x = x0, math.min(x0 + factor, pix.width) - 1
          r, g, b = pix\at x, y
          sum_r += r
          sum_g += g
          sum_b += b
          n += 1
      offset = (oy * out_w + ox) * 3
      out[offset] = math.floor(sum_r / n)
      out[offset + 1] = math.floor(sum_g / n)
      out[offset + 2] = math.floor(sum_b / n)

  width: out_w, height: out_h, stride: out_w * 3, n: 3, samples_gc: out, at: (x, y) =>
    o = (y * @width + x) * 3
    @samples_gc[o], @samples_gc[o + 1], @samples_gc[o + 2]

-- Écrit pix (Pixmap ou table {width,height,at}) au format PPM binaire (P6).
write_ppm = (pix, path) ->
  f = assert io.open path, "wb"
  f\write "P6\n#{pix.width} #{pix.height}\n255\n"
  row = ffi.new "unsigned char[?]", pix.width * 3
  for y = 0, pix.height - 1
    for x = 0, pix.width - 1
      r, g, b = pix\at x, y
      o = x * 3
      row[o], row[o + 1], row[o + 2] = r, g, b
    f\write ffi.string(row, pix.width * 3)
  f\close!

-- Retourne les octets PPM (P6) de pix sous forme de chaîne (pour assemblage sepfile).
ppm_bytes = (pix) ->
  parts = {"P6\n#{pix.width} #{pix.height}\n255\n"}
  row = ffi.new "unsigned char[?]", pix.width * 3
  for y = 0, pix.height - 1
    for x = 0, pix.width - 1
      r, g, b = pix\at x, y
      o = x * 3
      row[o], row[o + 1], row[o + 2] = r, g, b
    table.insert parts, ffi.string(row, pix.width * 3)
  table.concat parts

{:downsample, :write_ppm, :ppm_bytes}
