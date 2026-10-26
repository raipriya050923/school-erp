import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/utils/formatters.dart';
import '../../data/api_models.dart';

/// The receipt as a file.
///
/// Built as a PDF rather than a screenshot so the numbers stay selectable and
/// the page prints at a sensible size — a parent forwarding a receipt to an
/// employer or an auditor is sending a document, not a picture of a phone.
///
/// The layout deliberately mirrors [ReceiptSheet] and the web's printed slip.
/// If the office and the family end up holding receipts that look like
/// different documents for one payment, the receipt has failed at its only job.
class ReceiptPdf {
  const ReceiptPdf._();

  /// `receipt-RCP-2026-0007.pdf` — the receipt number is what anyone searching
  /// their downloads a year later will have to hand.
  static String fileName(FeeReceipt r) {
    final String safe = r.receiptNo.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '-');
    return 'receipt-$safe.pdf';
  }

  /// Hands the document to the system sheet, which is where saving to
  /// Downloads, sending it on, and printing all live on a phone.
  static Future<void> share(FeeReceipt r) async {
    await Printing.sharePdf(bytes: await build(r), filename: fileName(r));
  }

  static Future<Uint8List> build(FeeReceipt r) async {
    final pw.Document doc = pw.Document(title: 'Receipt ${r.receiptNo}');

    // The bundled font carries ₹ and any Devanagari in a school's name; the
    // default PDF fonts carry neither, and would silently drop both.
    final pw.Font regular = await PdfGoogleFonts.notoSansRegular();
    final pw.Font bold = await PdfGoogleFonts.notoSansBold();
    final pw.Font mono = await PdfGoogleFonts.robotoMonoRegular();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            _header(r, bold, mono),
            pw.SizedBox(height: 18),
            pw.Divider(height: 1, color: PdfColors.grey400),
            pw.SizedBox(height: 14),
            _meta(r),
            if (r.lines.isNotEmpty) ...<pw.Widget>[
              pw.SizedBox(height: 18),
              _particulars(r, bold),
            ],
            pw.SizedBox(height: 18),
            _total(r, bold),
            pw.SizedBox(height: 8),
            pw.Text(
              'In words: ${r.amountInWords}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
            ),
            pw.SizedBox(height: 18),
            pw.Row(
              children: <pw.Widget>[
                pw.Expanded(child: _field('Paid by', r.methodLabel)),
                pw.Expanded(child: _field('Reference', r.reference ?? '—')),
              ],
            ),
            pw.Spacer(),
            pw.Divider(height: 1, color: PdfColors.grey400),
            pw.SizedBox(height: 8),
            pw.Text(
              'This is a computer-generated receipt and needs no signature.',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ],
        ),
      ),
    );

    return doc.save();
  }

  static pw.Widget _header(FeeReceipt r, pw.Font bold, pw.Font mono) {
    final String contact = <String>[
      if ((r.schoolPhone ?? '').isNotEmpty) r.schoolPhone!,
      if ((r.schoolEmail ?? '').isNotEmpty) r.schoolEmail!,
    ].join('  ·  ');

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              pw.Text(r.schoolName,
                  style: pw.TextStyle(font: bold, fontSize: 16)),
              if ((r.schoolAddress ?? '').isNotEmpty)
                pw.Text(r.schoolAddress!,
                    style: const pw.TextStyle(
                        fontSize: 10, color: PdfColors.grey800)),
              if (contact.isNotEmpty)
                pw.Text(contact,
                    style: const pw.TextStyle(
                        fontSize: 10, color: PdfColors.grey800)),
            ],
          ),
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: <pw.Widget>[
            pw.Text('FEE RECEIPT',
                style: pw.TextStyle(
                    font: bold, fontSize: 10, letterSpacing: 1.4)),
            pw.SizedBox(height: 2),
            pw.Text(r.receiptNo,
                style: pw.TextStyle(font: mono, fontSize: 12)),
            if (r.paidDate != null)
              pw.Text(_date(r.paidDate!),
                  style: const pw.TextStyle(
                      fontSize: 10, color: PdfColors.grey800)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _meta(FeeReceipt r) => pw.Wrap(
        spacing: 28,
        runSpacing: 10,
        children: <pw.Widget>[
          _field('Student', r.studentName),
          if ((r.admissionNo ?? '').isNotEmpty)
            _field('Admission no', r.admissionNo!),
          if ((r.classLabel ?? '').isNotEmpty) _field('Class', r.classLabel!),
          if ((r.invoiceNo ?? '').isNotEmpty) _field('Invoice', r.invoiceNo!),
          if ((r.month ?? '').isNotEmpty) _field('For', r.month!),
          _field('Issued', _date(r.issuedAt)),
        ],
      );

  static pw.Widget _particulars(FeeReceipt r, pw.Font bold) => pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        columnWidths: const <int, pw.TableColumnWidth>{
          0: pw.FlexColumnWidth(3),
          1: pw.FlexColumnWidth(1),
        },
        children: <pw.TableRow>[
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey100),
            children: <pw.Widget>[
              _cell('Particulars', bold: bold),
              _cell('Amount', bold: bold, alignRight: true),
            ],
          ),
          for (final ReceiptLine l in r.lines)
            pw.TableRow(
              children: <pw.Widget>[
                _cell(l.description),
                _cell(Format.money(l.amount), alignRight: true),
              ],
            ),
        ],
      );

  static pw.Widget _total(FeeReceipt r, pw.Font bold) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Row(
          children: <pw.Widget>[
            pw.Expanded(
              child: pw.Text('Amount paid',
                  style: pw.TextStyle(font: bold, fontSize: 12)),
            ),
            pw.Text(Format.money(r.amountPaid),
                style: pw.TextStyle(font: bold, fontSize: 14)),
          ],
        ),
      );

  static pw.Widget _field(String label, String value) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Text(label.toUpperCase(),
              style: const pw.TextStyle(
                  fontSize: 8, color: PdfColors.grey600, letterSpacing: 0.8)),
          pw.SizedBox(height: 2),
          pw.Text(value, style: const pw.TextStyle(fontSize: 11)),
        ],
      );

  static pw.Widget _cell(String text,
          {pw.Font? bold, bool alignRight = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: pw.Text(
          text,
          textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
          style: pw.TextStyle(font: bold, fontSize: 10),
        ),
      );

  static const List<String> _months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _date(DateTime d) =>
      '${d.day} ${_months[d.month - 1]} ${d.year}';
}
