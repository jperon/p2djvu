-- Binding FFI vers le shim mupdf_shim (voir csrc/mupdf_shim.c) : seule la
-- petite API "safe" du shim est exposée ici, jamais les fonctions fz_*
-- brutes (celles-ci peuvent lever des exceptions C incompatibles avec FFI).
ffi = require "ffi"

ffi.cdef [[
typedef struct p2djvu_ctx p2djvu_ctx;
typedef struct p2djvu_doc p2djvu_doc;

typedef struct {
    int width;
    int height;
    int stride;
    int n;
    unsigned char *samples;
} p2djvu_pixmap;

typedef struct {
    float x0, y0, x1, y1;
    char *utf8;
} p2djvu_stext_line;

typedef struct {
    p2djvu_stext_line *lines;
    int count;
} p2djvu_stext_page;

p2djvu_ctx *p2djvu_new_context(void);
void p2djvu_drop_context(p2djvu_ctx *ctx);

int p2djvu_open_document(p2djvu_ctx *ctx, const char *filename, p2djvu_doc **out_doc);
void p2djvu_drop_document(p2djvu_ctx *ctx, p2djvu_doc *doc);

int p2djvu_count_pages(p2djvu_ctx *ctx, p2djvu_doc *doc, int *out_count);
int p2djvu_render_page(p2djvu_ctx *ctx, p2djvu_doc *doc, int page_number, float dpi, p2djvu_pixmap *out_pix);
void p2djvu_free_pixmap(p2djvu_pixmap *pix);

int p2djvu_extract_stext(p2djvu_ctx *ctx, p2djvu_doc *doc, int page_number, p2djvu_stext_page *out_page);
void p2djvu_free_stext(p2djvu_stext_page *page);

const char *p2djvu_last_error(p2djvu_ctx *ctx);
]]

-- Le nom de la lib est résolu par le wrapper Nix (LD_LIBRARY_PATH) ; en
-- développement, P2DJVU_SHIM_PATH permet de pointer vers le .so compilé localement.
shim_path = os.getenv("P2DJVU_SHIM_PATH") or "p2djvu_mupdf_shim"
shim = ffi.load shim_path

-- Moonscript n'a pas de classe Exception native : on lève simplement une table {msg=...}
error_from_ctx = (ctx) ->
  error {msg: ffi.string(shim.p2djvu_last_error(ctx))}

class Pixmap
  new: (@width, @height, @stride, @n, @samples_gc) =>

  -- Retourne r, g, b (0-255) au pixel (x, y), origine (0,0) en haut à gauche.
  at: (x, y) =>
    offset = y * @stride + x * @n
    s = @samples_gc
    s[offset], s[offset + 1], s[offset + 2]

class Document
  -- p2djvu est un outil en ligne de commande mono-exécution : le contexte et
  -- le document MuPDF vivent pour toute la durée du processus et sont
  -- récupérés par l'OS à la sortie. On évite volontairement ffi.gc sur ces
  -- deux cdata : leur ordre de finalisation croisé (le drop du document a
  -- besoin du contexte encore valide) n'est pas garanti par le GC de LuaJIT
  -- et provoquait un crash en sortie de programme. Seuls les buffers par
  -- page (pixmap, texte), alloués en boucle sur des centaines de pages,
  -- restent finalisés via ffi.gc pour éviter les fuites mémoire.
  new: (path) =>
    @ctx = shim.p2djvu_new_context!
    error {msg: "impossible d'initialiser MuPDF"} if @ctx == nil

    doc_out = ffi.new "p2djvu_doc*[1]"
    rc = shim.p2djvu_open_document @ctx, path, doc_out
    error_from_ctx @ctx if rc != 0
    @doc = doc_out[0]

  page_count: =>
    out = ffi.new "int[1]"
    rc = shim.p2djvu_count_pages @ctx, @doc, out
    error_from_ctx @ctx if rc != 0
    out[0]

  -- page_number : 0-indexé. dpi : résolution de rendu.
  render_page: (page_number, dpi) =>
    pix = ffi.new "p2djvu_pixmap"
    rc = shim.p2djvu_render_page @ctx, @doc, page_number, dpi, pix
    error_from_ctx @ctx if rc != 0
    samples = ffi.gc pix.samples, -> shim.p2djvu_free_pixmap pix
    Pixmap pix.width, pix.height, pix.stride, pix.n, samples

  -- Retourne la liste des lignes {x0,y0,x1,y1,text} (espace page, points,
  -- origine haut-gauche — cohérent avec fz_stext_line->bbox de MuPDF).
  extract_text_lines: (page_number) =>
    st = ffi.new "p2djvu_stext_page"
    rc = shim.p2djvu_extract_stext @ctx, @doc, page_number, st
    error_from_ctx @ctx if rc != 0

    lines = {}
    for i = 0, st.count - 1
      l = st.lines[i]
      table.insert lines, {x0: l.x0, y0: l.y0, x1: l.x1, y1: l.y1, text: ffi.string l.utf8}
    shim.p2djvu_free_stext st

    lines

{:Document, :Pixmap}
