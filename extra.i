%module fitz_extra

%{
#include "mupdf/classes2.h"
    
//----------------------------------------------------------------------------
// Deep-copies a specified source page to the target location.
// Modified copy of function of pdfmerge.c: we also copy annotations, but
// we skip **link** annotations. In addition we rotate output.
//----------------------------------------------------------------------------
void page_merge(
        mupdf::PdfDocument& doc_des,
        mupdf::PdfDocument& doc_src,
        int page_from,
        int page_to,
        int rotate,
        int links,
        int copy_annots,
        mupdf::PdfGraftMap& graft_map
        )
{
    // list of object types (per page) we want to copy
    static mupdf::PdfObj const known_page_objs[] = {
        mupdf::PdfObj( PDF_NAME(Contents)),
        mupdf::PdfObj( PDF_NAME(Resources)),
        mupdf::PdfObj( PDF_NAME(MediaBox)),
        mupdf::PdfObj( PDF_NAME(CropBox)),
        mupdf::PdfObj( PDF_NAME(BleedBox)),
        mupdf::PdfObj( PDF_NAME(TrimBox)),
        mupdf::PdfObj( PDF_NAME(ArtBox)),
        mupdf::PdfObj( PDF_NAME(Rotate)),
        mupdf::PdfObj( PDF_NAME(UserUnit))
        };
    int known_page_objs_num = sizeof(known_page_objs) / sizeof(known_page_objs[0]);
    int i, n;

    mupdf::PdfObj   page_ref = mupdf::pdf_lookup_page_obj( doc_src, page_from);

    // make new page dict in dest doc
    mupdf::PdfObj   page_dict = mupdf::pdf_new_dict( doc_des, 4);
    mupdf::pdf_dict_put( page_dict, PDF_NAME(Type), PDF_NAME(Page));

    for (i = 0; i < known_page_objs_num; i++)
    {
        mupdf::PdfObj   obj = mupdf::pdf_dict_get_inheritable( page_ref, known_page_objs[i]);
        if (obj.m_internal)
        {
            mupdf::pdf_dict_put(
                    page_dict,
                    known_page_objs[i],
                    mupdf::pdf_graft_mapped_object( graft_map, obj)
                    );
        }
    }

    // Copy the annotations, but skip types Link, Popup, IRT.
    // Remove dict keys P (parent) and Popup from copied annot.
    if (copy_annots)
    {
        mupdf::PdfObj old_annots = mupdf::pdf_dict_get( page_ref, PDF_NAME(Annots));
        if (old_annots.m_internal)
        {
            n = mupdf::pdf_array_len( old_annots);
            mupdf::PdfObj new_annots = mupdf::pdf_dict_put_array( page_dict, PDF_NAME(Annots), n);
            for (i = 0; i < n; i++)
            {
                mupdf::PdfObj o = mupdf::pdf_array_get( old_annots, i);
                if (mupdf::pdf_dict_get( o, PDF_NAME(IRT)).m_internal) continue;
                mupdf::PdfObj subtype = mupdf::pdf_dict_get( o, PDF_NAME(Subtype));
                if (mupdf::pdf_name_eq( subtype, PDF_NAME(Link))) continue;
                if (mupdf::pdf_name_eq( subtype, PDF_NAME(Popup))) continue;
                if (mupdf::pdf_name_eq( subtype, PDF_NAME(Widget)))
                {
                    mupdf::fz_warn( "skipping widget annotation");
                    continue;
                }
                mupdf::pdf_dict_del( o, PDF_NAME(Popup));
                mupdf::pdf_dict_del( o, PDF_NAME(P));
                mupdf::PdfObj copy_o = mupdf::pdf_graft_mapped_object( graft_map, o);
                mupdf::PdfObj annot = mupdf::pdf_new_indirect(
                        doc_des,
                        mupdf::pdf_to_num( copy_o),
                        0
                        );
                mupdf::pdf_array_push( new_annots, annot);
            }
        }
    }
    // rotate the page
    if (rotate != -1)
    {
        mupdf::pdf_dict_put_int( page_dict, PDF_NAME(Rotate), rotate);
    }
    // Now add the page dictionary to dest PDF
    mupdf::PdfObj ref = mupdf::pdf_add_object( doc_des, page_dict);

    // Insert new page at specified location
    mupdf::pdf_insert_page( doc_des, page_to, ref);
}

%}

void page_merge(
        mupdf::PdfDocument& doc_des,
        mupdf::PdfDocument& doc_src,
        int page_from,
        int page_to,
        int rotate,
        int links,
        int copy_annots,
        mupdf::PdfGraftMap& graft_map
        );