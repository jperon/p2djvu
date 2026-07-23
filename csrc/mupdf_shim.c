#include "mupdf_shim.h"

#include <mupdf/fitz.h>
#include <string.h>
#include <stdlib.h>

struct p2djvu_ctx {
    fz_context *fz;
    char last_error[512];
};

struct p2djvu_doc {
    fz_document *doc;
};

static void remember_error(p2djvu_ctx *ctx, fz_context *fz)
{
    const char *msg = fz_caught_message(fz);
    snprintf(ctx->last_error, sizeof(ctx->last_error), "%s", msg ? msg : "erreur MuPDF inconnue");
}

p2djvu_ctx *p2djvu_new_context(void)
{
    p2djvu_ctx *ctx = calloc(1, sizeof(p2djvu_ctx));
    if (!ctx) return NULL;

    ctx->fz = fz_new_context(NULL, NULL, FZ_STORE_UNLIMITED);
    if (!ctx->fz) {
        free(ctx);
        return NULL;
    }

    fz_try(ctx->fz)
        fz_register_document_handlers(ctx->fz);
    fz_catch(ctx->fz) {
        fz_drop_context(ctx->fz);
        free(ctx);
        return NULL;
    }

    return ctx;
}

void p2djvu_drop_context(p2djvu_ctx *ctx)
{
    if (!ctx) return;
    fz_drop_context(ctx->fz);
    free(ctx);
}

const char *p2djvu_last_error(p2djvu_ctx *ctx)
{
    return ctx->last_error;
}

int p2djvu_open_document(p2djvu_ctx *ctx, const char *filename, p2djvu_doc **out_doc)
{
    fz_context *fz = ctx->fz;
    p2djvu_doc *doc = calloc(1, sizeof(p2djvu_doc));
    if (!doc) {
        snprintf(ctx->last_error, sizeof(ctx->last_error), "mémoire insuffisante");
        return -1;
    }

    fz_try(fz)
        doc->doc = fz_open_document(fz, filename);
    fz_catch(fz) {
        remember_error(ctx, fz);
        free(doc);
        return -1;
    }

    *out_doc = doc;
    return 0;
}

void p2djvu_drop_document(p2djvu_ctx *ctx, p2djvu_doc *doc)
{
    if (!doc) return;
    fz_try(ctx->fz)
        fz_drop_document(ctx->fz, doc->doc);
    fz_catch(ctx->fz) { /* rien de plus à faire : on libère quand même */ }
    free(doc);
}

int p2djvu_count_pages(p2djvu_ctx *ctx, p2djvu_doc *doc, int *out_count)
{
    fz_context *fz = ctx->fz;
    int count = 0;

    fz_try(fz)
        count = fz_count_pages(fz, doc->doc);
    fz_catch(fz) {
        remember_error(ctx, fz);
        return -1;
    }

    *out_count = count;
    return 0;
}

int p2djvu_render_page(p2djvu_ctx *ctx, p2djvu_doc *doc, int page_number, float dpi, p2djvu_pixmap *out_pix)
{
    fz_context *fz = ctx->fz;
    fz_page *page = NULL;
    fz_pixmap *pix = NULL;
    float scale = dpi / 72.0f;

    fz_var(page);
    fz_var(pix);

    fz_try(fz) {
        fz_matrix ctm = fz_scale(scale, scale);
        page = fz_load_page(fz, doc->doc, page_number);
        pix = fz_new_pixmap_from_page(fz, page, ctm, fz_device_rgb(fz), 0);
    }
    fz_always(fz) {
        if (page) fz_drop_page(fz, page);
    }
    fz_catch(fz) {
        remember_error(ctx, fz);
        return -1;
    }

    int stride = fz_pixmap_stride(fz, pix);
    int h = fz_pixmap_height(fz, pix);
    unsigned char *samples = malloc((size_t)stride * (size_t)h);
    if (!samples) {
        fz_drop_pixmap(fz, pix);
        snprintf(ctx->last_error, sizeof(ctx->last_error), "mémoire insuffisante");
        return -1;
    }
    memcpy(samples, fz_pixmap_samples(fz, pix), (size_t)stride * (size_t)h);

    out_pix->width = fz_pixmap_width(fz, pix);
    out_pix->height = h;
    out_pix->stride = stride;
    out_pix->n = fz_pixmap_components(fz, pix);
    out_pix->samples = samples;

    fz_drop_pixmap(fz, pix);
    return 0;
}

void p2djvu_free_pixmap(p2djvu_pixmap *pix)
{
    if (!pix) return;
    free(pix->samples);
    pix->samples = NULL;
}

int p2djvu_extract_stext(p2djvu_ctx *ctx, p2djvu_doc *doc, int page_number, p2djvu_stext_page *out_page)
{
    fz_context *fz = ctx->fz;
    fz_page *page = NULL;
    fz_stext_page *stext = NULL;
    fz_stext_options opts = { 0 };

    fz_var(page);
    fz_var(stext);

    fz_try(fz) {
        page = fz_load_page(fz, doc->doc, page_number);
        stext = fz_new_stext_page_from_page(fz, page, &opts);
    }
    fz_always(fz) {
        if (page) fz_drop_page(fz, page);
    }
    fz_catch(fz) {
        remember_error(ctx, fz);
        return -1;
    }

    /* Première passe : compter les lignes non vides pour dimensionner le tableau. */
    int count = 0;
    for (fz_stext_block *block = stext->first_block; block; block = block->next) {
        if (block->type != FZ_STEXT_BLOCK_TEXT) continue;
        for (fz_stext_line *line = block->u.t.first_line; line; line = line->next)
            if (line->first_char) count++;
    }

    p2djvu_stext_line *lines = count ? calloc((size_t)count, sizeof(p2djvu_stext_line)) : NULL;
    if (count && !lines) {
        fz_drop_stext_page(fz, stext);
        snprintf(ctx->last_error, sizeof(ctx->last_error), "mémoire insuffisante");
        return -1;
    }

    int i = 0;
    for (fz_stext_block *block = stext->first_block; block; block = block->next) {
        if (block->type != FZ_STEXT_BLOCK_TEXT) continue;
        for (fz_stext_line *line = block->u.t.first_line; line; line = line->next) {
            if (!line->first_char) continue;

            /* Chaque rune tient sur au plus 4 octets UTF-8 ; +1 pour le NUL final. */
            int nchars = 0;
            for (fz_stext_char *ch = line->first_char; ch; ch = ch->next) nchars++;
            char *utf8 = malloc((size_t)nchars * 4 + 1);
            if (!utf8) {
                for (int j = 0; j < i; j++) free(lines[j].utf8);
                free(lines);
                fz_drop_stext_page(fz, stext);
                snprintf(ctx->last_error, sizeof(ctx->last_error), "mémoire insuffisante");
                return -1;
            }

            int off = 0;
            for (fz_stext_char *ch = line->first_char; ch; ch = ch->next)
                off += fz_runetochar(utf8 + off, ch->c);
            utf8[off] = '\0';

            lines[i].x0 = line->bbox.x0;
            lines[i].y0 = line->bbox.y0;
            lines[i].x1 = line->bbox.x1;
            lines[i].y1 = line->bbox.y1;
            lines[i].utf8 = utf8;
            i++;
        }
    }

    fz_drop_stext_page(fz, stext);

    out_page->lines = lines;
    out_page->count = count;
    return 0;
}

void p2djvu_free_stext(p2djvu_stext_page *page)
{
    if (!page) return;
    for (int i = 0; i < page->count; i++) free(page->lines[i].utf8);
    free(page->lines);
    page->lines = NULL;
    page->count = 0;
}
