// Contrôle des entrées : vérifie le badge chiffré (ou l'ancien numéro de
// billet) et valide l'entrée une seule fois.

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/core/auth/permissions.dart';
import 'package:crowdtech/modules/events/domain/event_access.dart';
import 'package:crowdtech/modules/events/presentation/qr_scanner_page.dart';
import 'package:crowdtech/shared/widgets/access_denied_view.dart';
import 'package:flutter/material.dart';

class CheckInPage extends StatefulWidget {
  const CheckInPage({super.key});

  @override
  State<CheckInPage> createState() => _CheckInPageState();
}

class _CheckInPageState extends State<CheckInPage> {
  final controller = TextEditingController();
  bool loading = false;
  String? message;
  bool valid = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  /// Ouvre la caméra, puis vérifie aussitôt le code lu.
  Future<void> scan() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerPage()),
    );
    if (code == null || !mounted) return;
    controller.text = code;
    await validateTicket();
  }

  Future<void> validateTicket() async {
    final ticket = controller.text.trim();
    if (ticket.isEmpty) {
      setState(() => message = 'Saisissez le code du pass.');
      return;
    }
    setState(() {
      loading = true;
      message = null;
    });
    try {
      // Badge chiffré : authenticité, validité et usage unique vérifiés.
      final result = await AccessBadge.checkIn(ticket);
      if (!mounted) return;
      setState(() {
        message = result.message;
        valid = result.valid;
      });
    } on Exception catch (exception) {
      if (mounted) {
        setState(() => message = 'Erreur pendant le contrôle : $exception');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Permissions.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Contrôle des entrées')),
        body: const AccessDeniedView(),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Contrôle des entrées')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Scannez le QR du badge, ou collez son code (CTB1…) ou l’ancien '
            'numéro de billet. L’authenticité et la date de validité sont '
            'vérifiées, et chaque pass ne sert qu’une fois.',
          ),
          const SizedBox(height: 16),
          if (QrScannerPage.isSupported) ...[
            FilledButton.icon(
              onPressed: loading ? null : scan,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Scanner le QR code'),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Code du pass',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: loading ? null : validateTicket,
            child: loading
                ? const CircularProgressIndicator()
                : const Text('Vérifier le billet'),
          ),
          if (message != null) ...[
            const SizedBox(height: 12),
            Card(
              color: valid ? AppColors.successSoft : AppColors.dangerSoft,
              child: ListTile(
                leading: Icon(
                  valid ? Icons.verified_rounded : Icons.block_rounded,
                  color: valid ? AppColors.success : AppColors.danger,
                ),
                title: Text(message!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
