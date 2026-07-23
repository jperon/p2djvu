#ifndef P2DJVU_MUPDF_SHIM_H
#define P2DJVU_MUPDF_SHIM_H

#include <stdint.h>

/*
 * Shim minimal autour de libmupdf : la seule raison d'être de ce fichier est
 * d'encapsuler fz_try/fz_catch (setjmp/longjmp) dans un frame C classique,
 * pour pouvoir piloter MuPDF depuis LuaJIT FFI sans risquer un longjmp à
 * travers la pile d'appel FFI. Toute la logique métier reste côté
 * Moonscript ; ce fichier ne fait qu'exposer une API "sûre" qui retourne un
 * code d'erreur ordinaire au lieu de lever une exception C.
 */

typedef struct p2djvu_ctx p2djvu_ctx;
typedef struct p2djvu_doc p2djvu_doc;

typedef struct {
    int width;
    int height;
    int stride;
    int n; /* nombre de composantes par pixel (3 = RGB) */
    unsigned char *samples; /* propriété de l'appelant, libérer avec p2djvu_free_pixmap */
} p2djvu_pixmap;

typedef struct {
    float x0, y0, x1, y1; /* bbox englobante de la ligne, espace page (origine haut-gauche, points) */
    char *utf8;           /* texte de la ligne, UTF-8, terminé par NUL ; propriété de p2djvu_stext_page */
} p2djvu_stext_line;

typedef struct {
    p2djvu_stext_line *lines;
    int count;
} p2djvu_stext_page;

/* Retourne NULL en cas d'échec d'initialisation (jamais d'exception C qui sort d'ici). */
p2djvu_ctx *p2djvu_new_context(void);
void p2djvu_drop_context(p2djvu_ctx *ctx);

/* Retourne 0 si succès, -1 en cas d'erreur (message récupérable via p2djvu_last_error). */
int p2djvu_open_document(p2djvu_ctx *ctx, const char *filename, p2djvu_doc **out_doc);
void p2djvu_drop_document(p2djvu_ctx *ctx, p2djvu_doc *doc);

int p2djvu_count_pages(p2djvu_ctx *ctx, p2djvu_doc *doc, int *out_count);

/* dpi : résolution de rendu. out_pix->samples doit être libéré par p2djvu_free_pixmap. */
int p2djvu_render_page(p2djvu_ctx *ctx, p2djvu_doc *doc, int page_number, float dpi, p2djvu_pixmap *out_pix);
void p2djvu_free_pixmap(p2djvu_pixmap *pix);

/* Extrait le texte par ligne (bbox + chaîne UTF-8). out_page->lines doit être libéré par p2djvu_free_stext. */
int p2djvu_extract_stext(p2djvu_ctx *ctx, p2djvu_doc *doc, int page_number, p2djvu_stext_page *out_page);
void p2djvu_free_stext(p2djvu_stext_page *page);

/* Message de la dernière erreur survenue sur ce contexte (chaîne statique interne, valide jusqu'au prochain appel). */
const char *p2djvu_last_error(p2djvu_ctx *ctx);

#endif
