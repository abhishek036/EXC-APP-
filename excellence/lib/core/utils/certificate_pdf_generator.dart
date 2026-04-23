import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class CertificatePdfGenerator {
  static Future<void> generateCertificate(String studentName, String courseName, String type) async {
    final pdf = pw.Document();

    final date = DateFormat('dd MMMM yyyy').format(DateTime.now());
    final title = type == 'ex' ? 'CERTIFICATE OF EXCELLENCE' : 'CERTIFICATE OF COMPLETION';
    final desc = type == 'ex' 
      ? 'This certificate is proudly presented to $studentName for achieving academic excellence in $courseName.'
      : 'This is to certify that $studentName has successfully completed the $courseName course.';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(24),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.blue900, width: 4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.SizedBox(height: 30),
                pw.Text('EXCELLENCE ACADEMY', style: pw.TextStyle(fontSize: 32, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                pw.SizedBox(height: 10),
                pw.Text('Empowering the Future', style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
                pw.SizedBox(height: 50),
                pw.Text(title, style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.amber800)),
                pw.SizedBox(height: 40),
                pw.Text('PROUDLY PRESENTED TO', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
                pw.SizedBox(height: 10),
                pw.Text(studentName, style: pw.TextStyle(fontSize: 42, fontStyle: pw.FontStyle.italic, color: PdfColors.blue900)),
                pw.SizedBox(height: 20),
                pw.Container(width: 300, height: 1, color: PdfColors.grey400),
                pw.SizedBox(height: 20),
                pw.Text(desc, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 16)),
                pw.Spacer(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      children: [
                        pw.Text(date, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                        pw.Container(width: 150, height: 1, color: PdfColors.black, margin: const pw.EdgeInsets.symmetric(vertical: 4)),
                        pw.Text('Date', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Text('Director', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                        pw.Container(width: 150, height: 1, color: PdfColors.black, margin: const pw.EdgeInsets.symmetric(vertical: 4)),
                        pw.Text('Signature', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Certificate_${studentName.replaceAll(' ', '_')}',
    );
  }
}
