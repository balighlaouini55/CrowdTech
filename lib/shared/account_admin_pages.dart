import 'package:flutter/material.dart';

import '../data/crowdtech_database.dart';
import '../validation/validators.dart';

class PasswordResetPage extends StatefulWidget {
  final String initialEmail;

  const PasswordResetPage({this.initialEmail = '', super.key});

  @override
  State<PasswordResetPage> createState() => _PasswordResetPageState();
}

class _PasswordResetPageState extends State<PasswordResetPage> {
  final formKey = GlobalKey<FormState>();
  late final emailController = TextEditingController(text: widget.initialEmail);

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  void submit() {
    if (!formKey.currentState!.validate()) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Demande de réinitialisation simulée pour ${emailController.text.trim()}. Aucun email réel n’est envoyé.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Réinitialiser le mot de passe')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Cette page prépare la saisie. L’envoi réel nécessite un service d’authentification.',
          ),
          const SizedBox(height: 18),
          Form(
            key: formKey,
            child: TextFormField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email du compte',
                border: OutlineInputBorder(),
              ),
              validator: validateEmail,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: submit,
            child: const Text('Envoyer la demande (démo)'),
          ),
        ],
      ),
    );
  }
}

class AdminRolesPage extends StatefulWidget {
  const AdminRolesPage({super.key});

  @override
  State<AdminRolesPage> createState() => _AdminRolesPageState();
}

class _AdminRolesPageState extends State<AdminRolesPage> {
  bool loading = true;
  String? error;
  List<Map<String, Object?>> profiles = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await CrowdTechDatabase.getItems('profiles');
      if (!mounted) return;
      setState(() {
        profiles = result;
        loading = false;
      });
    } on Exception catch (exception) {
      if (!mounted) return;
      setState(() {
        error = 'Impossible de charger les profils : $exception';
        loading = false;
      });
    }
  }

  Future<void> changeRole(Map<String, Object?> profile, String role) async {
    final id = profile['id'];
    if (id is! int) return;
    try {
      await CrowdTechDatabase.updateItem(
        'profiles',
        id,
        {...profile, 'role': role}..remove('id'),
      );
      if (mounted) await load();
    } on Exception catch (exception) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de modifier le rôle : $exception')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Utilisateurs et rôles (démo)')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(child: Text(error!))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('Administration locale uniquement'),
                    subtitle: Text(
                      'Ces rôles SQLite ne protègent aucune action. Une vraie autorisation doit être contrôlée par un serveur.',
                    ),
                  ),
                ),
                for (final profile in profiles)
                  Card(
                    child: ListTile(
                      title: Text(profile['name']?.toString() ?? 'Utilisateur'),
                      subtitle: Text(profile['email']?.toString() ?? ''),
                      trailing: DropdownButton<String>(
                        value:
                            [
                              'Lecteur',
                              'Investisseur',
                              'Porteur de projet',
                              'Admin',
                            ].contains(profile['role'])
                            ? profile['role']! as String
                            : 'Lecteur',
                        items: const [
                          DropdownMenuItem(
                            value: 'Lecteur',
                            child: Text('Lecteur'),
                          ),
                          DropdownMenuItem(
                            value: 'Investisseur',
                            child: Text('Investisseur'),
                          ),
                          DropdownMenuItem(
                            value: 'Porteur de projet',
                            child: Text('Porteur'),
                          ),
                          DropdownMenuItem(
                            value: 'Admin',
                            child: Text('Admin'),
                          ),
                        ],
                        onChanged: (role) {
                          if (role != null) changeRole(profile, role);
                        },
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class CheckInPage extends StatefulWidget {
  const CheckInPage({super.key});

  @override
  State<CheckInPage> createState() => _CheckInPageState();
}

class _CheckInPageState extends State<CheckInPage> {
  final controller = TextEditingController();
  bool loading = false;
  String? message;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
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
      final reservations = await CrowdTechDatabase.getItems('reservations');
      if (!mounted) return;
      final matching = reservations.where((item) => item['ticket'] == ticket);
      if (matching.isEmpty) {
        setState(() => message = 'Pass introuvable dans la base locale.');
      } else {
        final reservation = matching.first;
        final id = reservation['id']! as int;
        if (reservation['checkedIn'] == true) {
          setState(() => message = 'Ce pass a déjà été contrôlé.');
        } else {
          await CrowdTechDatabase.updateItem(
            'reservations',
            id,
            {...reservation, 'checkedIn': true}..remove('id'),
          );
          setState(
            () => message = 'Entrée validée : ${reservation['attendeeName']}.',
          );
        }
      }
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
    return Scaffold(
      appBar: AppBar(title: const Text('Contrôle des entrées')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Saisissez le code du billet pour le valider une seule fois dans cette base locale.',
          ),
          const SizedBox(height: 16),
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
            Card(child: ListTile(title: Text(message!))),
          ],
        ],
      ),
    );
  }
}
