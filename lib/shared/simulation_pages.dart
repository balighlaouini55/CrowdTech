import 'package:flutter/material.dart';

class RoiSimulatorPage extends StatefulWidget {
  const RoiSimulatorPage({super.key});

  @override
  State<RoiSimulatorPage> createState() => _RoiSimulatorPageState();
}

class _RoiSimulatorPageState extends State<RoiSimulatorPage> {
  final amountController = TextEditingController();
  final rateController = TextEditingController(text: '5');
  final yearsController = TextEditingController(text: '1');
  final formKey = GlobalKey<FormState>();
  double? estimate;

  @override
  void dispose() {
    amountController.dispose();
    rateController.dispose();
    yearsController.dispose();
    super.dispose();
  }

  void calculate() {
    if (!formKey.currentState!.validate()) return;
    final amount = double.parse(amountController.text);
    final rate = double.parse(rateController.text) / 100;
    final years = int.parse(yearsController.text);
    setState(() => estimate = amount * (1 + rate * years));
  }

  String? positive(String? value, {bool integer = false}) {
    final parsed = integer
        ? int.tryParse(value ?? '')
        : double.tryParse(value ?? '');
    if (parsed == null || parsed <= 0) return 'Saisissez une valeur positive.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Simulateur de rendement')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Simulation indicative uniquement : aucun rendement n’est garanti.',
          ),
          const SizedBox(height: 16),
          Form(
            key: formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Montant investi (€)',
                  ),
                  validator: positive,
                ),
                TextFormField(
                  controller: rateController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Variation annuelle simulée (%)',
                  ),
                  validator: (value) {
                    final number = double.tryParse(value ?? '');
                    return number == null || number < 0 || !number.isFinite
                        ? 'Saisissez un taux valide (0 ou plus).'
                        : null;
                  },
                ),
                TextFormField(
                  controller: yearsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Durée (années)',
                  ),
                  validator: (value) => positive(value, integer: true),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: calculate,
                  child: const Text('Calculer la simulation'),
                ),
              ],
            ),
          ),
          if (estimate != null) ...[
            const SizedBox(height: 20),
            Card(
              child: ListTile(
                title: const Text('Valeur indicative'),
                subtitle: Text('${estimate!.toStringAsFixed(2)} €'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class TicketBadgePage extends StatelessWidget {
  final String eventTitle;
  final String attendeeName;
  final String ticket;

  const TicketBadgePage({
    required this.eventTitle,
    required this.attendeeName,
    required this.ticket,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mon billet')),
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.qr_code_2_rounded, size: 150),
                Text(eventTitle, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('Participant : $attendeeName'),
                const SizedBox(height: 8),
                SelectableText(ticket),
                const SizedBox(height: 12),
                const Text(
                  'QR et billet de démonstration seulement : pas de validation d’accès réelle.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.blueGrey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
