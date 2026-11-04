// Attestation d'investissement au format PDF.

import 'dart:typed_data';

import 'package:crowdtech/shared/utils/formatters.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Numéro unique de l'attestation, par exemple « CT-ATT-000042 ».
String certificateNumber(Map<String, Object?> investment) =>
    'CT-ATT-${displayNumber(investment['id'], width: 6)}';

/// Construit le PDF de l'attestation d'un investissement.
Future<Uint8List> buildCertificatePdf(
  Map<String, Object?> investment, {
  required String holderName,
  required String holderEmail,
}) async {
  final regular = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Poppins-Regular.ttf'),
  );
  final bold = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Poppins-Bold.ttf'),
  );
  const lavender = PdfColor.fromInt(0xFF7C6CF2);
  const ink = PdfColor.fromInt(0xFF2B2459);
  const muted = PdfColor.fromInt(0xFF7A7699);
  final amount = (investment['amount'] as num?)?.toDouble() ?? 0;
  final refunded = investment['status'] == 'Remboursé';

  pw.Widget line(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 6),
    child: pw.Row(
      children: [
        pw.SizedBox(
          width: 170,
          child: pw.Text(label, style: const pw.TextStyle(color: muted)),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(font: bold, color: ink),
          ),
        ),
      ],
    ),
  );

  final document = pw.Document(
    title: 'Attestation d’investissement CrowdTech',
    author: 'CrowdTech',
  );
  document.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      margin: const pw.EdgeInsets.all(48),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(24),
            decoration: const pw.BoxDecoration(
              color: lavender,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(16)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'CrowdTech',
                  style: pw.TextStyle(
                    font: bold,
                    fontSize: 26,
                    color: PdfColors.white,
                  ),
                ),
                pw.Text(
                  'Attestation d’investissement',
                  style: const pw.TextStyle(
                    fontSize: 16,
                    color: PdfColors.white,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 28),
          pw.Text(
            'Nous attestons que $holderName ($holderEmail) a réalisé '
            'l’investissement suivant sur la plateforme CrowdTech :',
            style: const pw.TextStyle(fontSize: 12, color: ink),
          ),
          pw.SizedBox(height: 18),
          line('N° d’attestation', certificateNumber(investment)),
          line('Projet', '${investment['projectTitle'] ?? ''}'),
          line('Pack', '${investment['pack'] ?? ''}'),
          line('Jetons reçus', '${investment['tokens'] ?? 0}'),
          line('Montant', formatMoney(amount)),
          line('Date', formatDateTime(investment['createdAt']?.toString())),
          line(
            'Statut',
            refunded
                ? 'Remboursé le ${formatDate(investment['refundedAt']?.toString())}'
                : 'Actif',
          ),
          pw.Spacer(),
          pw.Divider(color: muted),
          pw.Text(
            'Document généré le ${formatDateTime(DateTime.now().toIso8601String())} '
            'en mode démonstration : aucun paiement réel n’a été effectué.',
            style: const pw.TextStyle(fontSize: 9, color: muted),
          ),
        ],
      ),
    ),
  );
  return document.save();
}
