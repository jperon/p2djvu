-- Wrappers autour des encodeurs djvulibre (cjb2, c44, csepdjvu, djvm, djvused).
-- Pas de réimplémentation de l'encodage DjVu : ces binaires sont matures et
-- optimisés, on se contente de les piloter en sous-processus.
{:run} = require "pipeline.shell"

-- Encode un masque bitonal (chemin PBM) en page DjVu N&B pure.
encode_bw = (pbm_path, out_djvu) ->
  ok, msg = run "cjb2", {pbm_path, out_djvu}
  error msg unless ok

-- Encode une image couleur/N&B (chemin PPM/PNM) en page DjVu couleur pure.
encode_color = (ppm_path, out_djvu) ->
  ok, msg = run "c44", {ppm_path, out_djvu}
  error msg unless ok

-- Encode une page en mode mixte à partir d'un fichier "séparé" déjà assemblé
-- (voir pipeline.sepfile : avant-plan RLE R4 + fond PPM + calque texte en
-- commentaires). C'est le format natif attendu par csepdjvu (man csepdjvu).
encode_mixed = (sep_path, dpi, out_djvu) ->
  ok, msg = run "csepdjvu", {"-d", tostring(dpi), "-t", sep_path, out_djvu}
  error msg unless ok

-- Fusionne une liste de fichiers .djvu de pages en un unique document multi-pages.
merge_pages = (page_paths, out_djvu) ->
  ok, msg = run "djvm", {"-c", out_djvu, unpack page_paths}
  error msg unless ok

-- Injecte un calque texte caché sur une page (texte au format djvused set-txt,
-- voir pipeline.text_layer pour la génération de ce format). Note : "save-page
-- <name>" est une commande différente (extrait la page sélectionnée vers un
-- fichier externe, <name> obligatoire) -- ce n'est PAS ce qui persiste les
-- changements ici. C'est l'option "-s" de djvused qui sauvegarde le document
-- modifié ; il ne faut donc pas appeler save-page dans ce script.
set_hidden_text = (djvu_path, page_index, txt_path) ->
  script = "select #{page_index + 1}\nset-txt #{txt_path}\n"
  script_path = os.tmpname!
  f = assert io.open script_path, "w"
  f\write script
  f\close!

  ok, msg = run "djvused", {djvu_path, "-f", script_path, "-s"}
  os.remove script_path
  error msg unless ok

{:encode_bw, :encode_color, :encode_mixed, :merge_pages, :set_hidden_text}
