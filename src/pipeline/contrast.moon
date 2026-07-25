-- Normalisation de contraste (étirement d'histogramme par canal, indépendant
-- par page) : ramène le point noir et le point blanc de chaque canal R/G/B
-- aux extrêmes (0/255), à partir des centiles bas/haut de sa distribution.
-- Corrige à la fois le manque de contraste (papier grisé) et une dominante
-- de couleur (page sépia/jaunie), et le fait indépendamment sur chaque page
-- : deux pages scannées avec un rendu différent sont chacune recalées sur
-- leur propre plage de valeurs, sans réglage à faire à la main.
ffi = require "ffi"

channel_histogram = (pix) ->
  hist_r, hist_g, hist_b = {}, {}, {}
  for t = 0, 255
    hist_r[t], hist_g[t], hist_b[t] = 0, 0, 0
  for y = 0, pix.height - 1
    for x = 0, pix.width - 1
      r, g, b = pix\at x, y
      hist_r[r] += 1
      hist_g[g] += 1
      hist_b[b] += 1
  hist_r, hist_g, hist_b

-- Retourne (lo, hi) : les valeurs de canal en dessous desquelles / au-dessus
-- desquelles se trouvent respectivement clip_pct% des pixels les plus sombres
-- et clip_pct% des pixels les plus clairs.
percentile_points = (hist, total, clip_pct) ->
  clip_count = math.max 1, math.floor(total * clip_pct / 100)

  cum, lo = 0, 0
  for t = 0, 255
    cum += hist[t]
    if cum >= clip_count
      lo = t
      break

  cum, hi = 0, 255
  for t = 255, 0, -1
    cum += hist[t]
    if cum >= clip_count
      hi = t
      break

  lo, hi

build_lut = (lo, hi) ->
  lut = {}
  if hi <= lo
    -- Bornes dégénérées (couverture d'encre trop faible pour être détachée du
    -- fond au centile choisi, ou canal parfaitement uniforme) : plutôt que
    -- d'écraser la couleur dominante à 0 par une division dégénérée, on
    -- n'altère pas ce canal.
    for t = 0, 255
      lut[t] = t
    return lut

  span = hi - lo
  for t = 0, 255
    v = math.floor((t - lo) * 255 / span + 0.5)
    lut[t] = math.max 0, math.min 255, v
  lut

-- pix : Pixmap (ou tout objet exposant .width/.height/:at). clip_pct : part
-- (en %) de pixels les plus sombres/clairs de chaque canal considérée comme
-- valeur extrême et ramenée à 0/255 (défaut 0.5 ; 0 désactive l'étirement).
-- Une valeur trop élevée sur une page à très faible couverture d'encre
-- (quelques lignes de texte sur une grande page blanche) peut désactiver la
-- correction sur un canal (cf. build_lut) faute de pouvoir isoler l'encre du
-- fond à ce centile ; dans ce cas, réduire clip_pct.
-- Retourne un objet de même interface (.width/.height/:at), à utiliser en
-- lieu et place de pix par la suite (binarisation, encodage couleur, etc.).
--
-- Si un seul canal atteint des bornes dégénérées (cf. build_lut), étirer les
-- autres canaux quand même produirait un décalage colorimétrique (un canal
-- inchangé, les autres étirés) : on désactive alors l'étirement pour les
-- trois canaux, pas seulement celui en cause.
normalize = (pix, clip_pct) ->
  clip_pct = clip_pct or 0.5
  hist_r, hist_g, hist_b = channel_histogram pix
  total = pix.width * pix.height

  lo_r, hi_r = percentile_points hist_r, total, clip_pct
  lo_g, hi_g = percentile_points hist_g, total, clip_pct
  lo_b, hi_b = percentile_points hist_b, total, clip_pct

  if hi_r <= lo_r or hi_g <= lo_g or hi_b <= lo_b
    return width: pix.width, height: pix.height, at: (x, y) => pix\at x, y

  lut_r = build_lut lo_r, hi_r
  lut_g = build_lut lo_g, hi_g
  lut_b = build_lut lo_b, hi_b

  width: pix.width, height: pix.height, at: (x, y) =>
    r, g, b = pix\at x, y
    lut_r[r], lut_g[g], lut_b[b]

{:normalize, :channel_histogram, :percentile_points, :build_lut}
