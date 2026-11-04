// Attestation d'un investissement : aperçu et téléchargement en PDF.

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/core/auth/session.dart';
import 'package:crowdtech/modules/funding/data/certificate_pdf.dart';
import 'package:crowdtech/shared/utils/feedback.dart';
import 'package:crowdtech/shared/utils/formatters.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

class CertificatePage extends StatefulWidget {
  final Map<String, Object?> investment;
  const CertificatePage({required this.investment, super.key});

  @override
  State<CertificatePage> createState() => _CertificatePageState();
}

class _CertificatePageState extends State<CertificatePage> {
  bool working = false;

  String get holderEmail => CrowdTechSession.accountKey ?? '';
  String get holderName => CrowdTechSession.name ?? holderEmail;

  Future<void> download() async {
    setState(() => working = true);
    try {
      final bytes = await buildCertificatePdf(
        widget.investment,
        holderName: holderName,
        holderEmail: holderEmail,
      );
      await Printing.sharePdf(
        bytes: bytes,
        filename: '${certificateNumber(widget.investment)}.pdf',
      );
    } on Exception catch (error) {
      if (!mounted) return;
      context.showMessage('PDF impossible à créer : $error');
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final investment = widget.investment;
    final refunded = investment['status'] == 'Remboursé';
    Widget line(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: AppColors.muted)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Attestation')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(28),
              boxShadow: softShadow,
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: ModulePalette.funding.gradient,
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📜 CrowdTech',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Attestation d’investissement',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      line('N°', certificateNumber(investment)),
                      line('Investisseur', holderName),
                      line('Projet', '${investment['projectTitle'] ?? ''}'),
                      line('Pack', '${investment['pack'] ?? ''}'),
                      line('Jetons', '${investment['tokens'] ?? 0}'),
                      line(
                        'Montant',
                        formatMoney((investment['amount'] as num?) ?? 0),
                      ),
                      line(
                        'Date',
                        formatDateTime(investment['createdAt']?.toString()),
                      ),
                      line('Statut', refunded ? 'Remboursé' : 'Actif'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: working ? null : download,
            icon: const Icon(Icons.picture_as_pdf_rounded),
            label: const Text('Télécharger le PDF'),
          ),
        ],
      ),
    );
  }
}
