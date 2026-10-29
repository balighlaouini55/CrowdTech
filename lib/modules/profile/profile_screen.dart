import 'package:flutter/material.dart';

import '../../data/crowdtech_database.dart';
import '../../models/crowd_models.dart';
import '../../shared/database_error_view.dart';
import '../../shared/account_admin_pages.dart';
import '../../shared/data_record_list_page.dart';
import 'profile_edit_page.dart';

class ProfileScreen extends StatefulWidget {
  final CrowdUser user;
  const ProfileScreen({required this.user, super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late String name = widget.user.name;
  late String email = widget.user.email;
  int? profileId;
  bool loading = true;
  String? loadError;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    setState(() {
      loading = true;
      loadError = null;
    });
    try {
      final profiles = await CrowdTechDatabase.getItems('profiles');
      final saved = profiles.where(
        (profile) => profile['accountKey'] == widget.user.email,
      );
      if (saved.isNotEmpty) {
        final profile = saved.first;
        if (!mounted) return;
        setState(() {
          profileId = profile['id']! as int;
          name = profile['name']! as String;
          email = profile['email']! as String;
          loading = false;
        });
        return;
      }

      final newProfile = {
        'accountKey': widget.user.email,
        'name': widget.user.name,
        'email': widget.user.email,
        'role': widget.user.role,
      };
      final id = await CrowdTechDatabase.insertItem('profiles', newProfile);
      if (!mounted) return;
      setState(() {
        profileId = id;
        loading = false;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        loadError = 'Impossible de charger le profil : $error';
      });
    }
  }

  Future<void> editProfile() async {
    final values = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileEditPage(name: name, email: email),
      ),
    );
    if (!mounted || values == null) return;
    final id = profileId;
    if (id == null) return;
    try {
      final rowsUpdated = await CrowdTechDatabase.updateItem('profiles', id, {
        'accountKey': widget.user.email,
        'name': values['name'],
        'email': values['email'],
        'role': widget.user.role,
      });
      if (rowsUpdated != 1) {
        throw Exception('Le profil à modifier est introuvable.');
      }
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur SQLite : $error')));
      return;
    }
    setState(() {
      name = values['name']!;
      email = values['email']!;
    });
  }

  void openPage(Widget page) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : loadError != null
          ? DatabaseErrorView(message: loadError!, onRetry: loadProfile)
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                const CircleAvatar(
                  radius: 42,
                  backgroundColor: Color(0xFF4F46E5),
                  child: Icon(
                    Icons.person_rounded,
                    size: 44,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.user.role,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 20),
                const Row(
                  children: [
                    Expanded(
                      child: _StatCard(label: 'Projets', value: '—'),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(label: 'Jetons', value: '—'),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(label: 'Score', value: '—'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Gestion du compte',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                _ProfileItem(label: 'Email', value: email),
                const _ProfileItem(
                  label: 'Localisation',
                  value: 'Ariana, Tunisie',
                ),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: editProfile,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Modifier mon profil'),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () =>
                      openPage(PasswordResetPage(initialEmail: email)),
                  icon: const Icon(Icons.lock_reset_outlined),
                  label: const Text('Réinitialiser le mot de passe'),
                ),
                OutlinedButton.icon(
                  onPressed: () => openPage(
                    DataRecordListPage(
                      title: 'Historique des achats',
                      collection: 'orders',
                      emptyMessage: 'Aucun achat enregistré.',
                      ownedOnly: true,
                      accountKey: widget.user.email,
                    ),
                  ),
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Historique des achats'),
                ),
                OutlinedButton.icon(
                  onPressed: () => openPage(
                    DataRecordListPage(
                      title: 'Mes billets',
                      collection: 'reservations',
                      emptyMessage: 'Aucun billet réservé.',
                      ownedOnly: true,
                      accountKey: widget.user.email,
                    ),
                  ),
                  icon: const Icon(Icons.confirmation_number_outlined),
                  label: const Text('Mes billets'),
                ),
                OutlinedButton.icon(
                  onPressed: () => openPage(const AdminRolesPage()),
                  icon: const Icon(Icons.admin_panel_settings_outlined),
                  label: const Text('Utilisateurs et rôles (démo)'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/welcome',
                      (route) => false,
                    ),
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Se déconnecter'),
                  ),
                ),
              ],
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ProfileItem extends StatelessWidget {
  final String label;
  final String value;
  const _ProfileItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
