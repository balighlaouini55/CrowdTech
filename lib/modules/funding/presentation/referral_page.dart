// Parrainage : code personnel, filleuls et bonus de jetons disponibles.

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/modules/funding/domain/crowd_rules.dart';
import 'package:crowdtech/shared/utils/feedback.dart';
import 'package:crowdtech/shared/utils/formatters.dart';
import 'package:crowdtech/shared/widgets/screen_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ReferralPage extends StatefulWidget {
  final String accountKey;
  const ReferralPage({required this.accountKey, super.key});

  @override
  State<ReferralPage> createState() => _ReferralPageState();
}

class _ReferralPageState extends State<ReferralPage> {
  List<Map<String, Object?>> referrals = [];
  int bonuses = 0;

  String get code => CrowdRules.referralCodeFor(widget.accountKey);

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final rows = await CrowdRules.referralsOf(widget.accountKey);
    final available = await CrowdRules.availableBonuses(widget.accountKey);
    if (!mounted) return;
    setState(() {
      referrals = rows;
      bonuses = available;
    });
  }

  Future<void> copyCode() async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    context.showMessage('Code copié 📋');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parrainage')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ScreenHeader(
            title: 'Invitez vos amis 🎁',
            subtitle:
                'Votre ami saisit votre code à l’inscription : vous recevez '
                'chacun +${CrowdRules.referralBonusPercent} % de jetons '
                'offerts sur votre prochain pack.',
            icon: Icons.card_giftcard_rounded,
            palette: ModulePalette.profile,
            stats: [
              ('${referrals.length}', 'filleul(s)'),
              ('$bonuses', 'bonus disponible(s)'),
            ],
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    'Votre code de parrainage',
                    style: TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    code,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      color: ModulePalette.profile.start,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: copyCode,
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Copier le code'),
                  ),
                ],
              ),
            ),
          ),
          if (referrals.isNotEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 8, 4, 8),
              child: Text(
                'Mes filleuls',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          for (final referral in referrals)
            Card(
              child: ListTile(
                leading: const Text('🤝', style: TextStyle(fontSize: 22)),
                title: Text('${referral['refereeKey']}'),
                subtitle: Text(
                  'Inscrit le ${formatDate(referral['createdAt']?.toString())}',
                ),
                trailing: Text(
                  referral['referrerBonusUsed'] == true
                      ? 'Bonus utilisé'
                      : 'Bonus dispo 🎁',
                ),
              ),
            ),
        ],
      ),
    );
  }
}
