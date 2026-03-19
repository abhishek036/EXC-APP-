import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class PdfGenerator {
  static Future<void> generateFeeReceipt(Map<String, dynamic> fee) async {
    final pdf = pw.Document();

    final amount = (fee['amount'] as num?)?.toDouble() ?? 0;
    final paid = (fee['paidAmount'] as num?)?.toDouble() ?? 0;
    final studentName = fee['studentName'] ?? 'Student';
    final batchName = fee['batchName'] ?? 'Batch';
    final month = fee['month'] ?? 'N/A';
    final paymentMode = (fee['paymentMode'] ?? 'N/A').toString().toUpperCase();
    final receiptDate = fee['paidDate'] != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(fee['paidDate']))
        : DateFormat('dd MMM yyyy').format(DateTime.now());
    final receiptId = 'REC-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Excellence Academy',
                          style: pw.TextStyle(
                              fontSize: 24,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue900)),
                      pw.Text('123 Education Hub, Knowledge City',
                          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.Text('Phone: +91 9876543210 | Email: info@excellence.academy',
                          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue50,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('FEE RECEIPT',
                            style: pw.TextStyle(
                                fontSize: 16,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.blue900)),
                        pw.SizedBox(height: 4),
                        pw.Text('No: $receiptId',
                            style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.grey800)),
                      ],
                    ),
                  )
                ],
              ),
              pw.SizedBox(height: 30),
              pw.Divider(color: PdfColors.grey400),
              pw.SizedBox(height: 20),

              // Student Details
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow('Student Name:', studentName),
                        pw.SizedBox(height: 8),
                        _buildDetailRow('Batch/Class:', batchName),
                        pw.SizedBox(height: 8),
                        _buildDetailRow('Fee Month:', month),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow('Date:', receiptDate),
                        pw.SizedBox(height: 8),
                        _buildDetailRow('Payment Mode:', paymentMode),
                        pw.SizedBox(height: 8),
                        _buildDetailRow('Status:', 'PAID', highlight: true),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 30),

              // Fee Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.blue50),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(12),
                        child: pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(12),
                        child: pw.Text('Amount',
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(12),
                        child: pw.Text('Monthly Tuition Fee for $month'),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(12),
                        child: pw.Text('Rs. ${amount.toInt()}', textAlign: pw.TextAlign.right),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 250,
                    child: pw.Column(
                      children: [
                        _buildTotalRow('Total Amount:', amount),
                        pw.SizedBox(height: 6),
                        _buildTotalRow('Paid Amount:', paid),
                        pw.SizedBox(height: 6),
                        pw.Divider(color: PdfColors.grey400),
                        pw.SizedBox(height: 6),
                        _buildTotalRow('Balance Pending:', amount - paid, isBold: true),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 60),

              // Signatures
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(width: 120, height: 1, color: PdfColors.grey400),
                      pw.SizedBox(height: 8),
                      pw.Text('Student/Parent Signature', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(width: 120, height: 1, color: PdfColors.grey400),
                      pw.SizedBox(height: 8),
                      pw.Text('Authorized Signatory', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                ],
              ),
              pw.Spacer(),

              // Footer
              pw.Center(
                child: pw.Text(
                  'This is a computer-generated receipt and does not require a physical signature.',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                ),
              ),
            ],
          );
        },
      ),
    );

    // Print or prompt download
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Fee_Receipt_${studentName}_$month',
    );
  }

  static pw.Widget _buildDetailRow(String label, String value, {bool highlight = false}) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 80,
          child: pw.Text(label, style: const pw.TextStyle(color: PdfColors.grey700)),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(
                fontWeight: highlight ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: highlight ? PdfColors.green700 : PdfColors.black),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildTotalRow(String label, double value, {bool isBold = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.Text(
          'Rs. ${value.toInt()}',
          style: pw.TextStyle(
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
