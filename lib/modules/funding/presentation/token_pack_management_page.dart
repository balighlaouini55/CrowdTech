// Gestion des packs de jetons : ajouter, modifier, supprimer.

import 'package:crowdtech/core/auth/permissions.dart';
import 'package:crowdtech/modules/funding/data/funding_repository.dart';
import 'package:crowdtech/modules/funding/domain/token_pack.dart';
import 'package:crowdtech/modules/funding/presentation/token_pack_form_page.dart';
import 'package:crowdtech/shared/utils/feedback.dart';
import 'package:crowdtech/shared/widgets/access_denied_view.dart';
import 'package:crowdtech/shared/widgets/database_error_view.dart';
import 'package:crowdtech/shared/widgets/empty_state.dart';
import 'package:crowdtech/shared/widgets/loading_skeleton.dart';
import 'package:flutter/material.dart';

class TokenPackManagementPage extends StatefulWidget {
  const TokenPackManagementPage({super.key});

  @override
  State<TokenPackManagementPage> createState() =>
      _TokenPackManagementPageState();
}

class _TokenPackManagementPageState extends State<TokenPackManagementPage> {
  bool loading = true;
  String? error;
  List<TokenPack> packs = [];

  @override
  void initState() {
    super.initState();
    if (Permissions.isAdmin) loadPacks();
  }

  Future<void> loadPacks() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final rows = await FundingRepository.tokenPacks.seeded(
        TokenPack.defaults.map((pack) => pack.toMap()).toList(),
      );
      if (!mounted) return;
      setState(() {
        packs = TokenPack.sortedFromRows(rows);
        loading = false;
      });
    } on Exception catch (exception) {
      if (!mounted) return;
      setState(() {
        error = 'Impossible de charger les packs : $exception';
        loading = false;
      });
    }
  }

  bool nameTaken(TokenPack pack) => packs.any(
    (other) =>
        other.id != pack.id &&
        other.name.toLowerCase() == pack.name.toLowerCase(),
  );

  Future<void> addPack() async {
    final pack = await Navigator.push<TokenPack>(
      context,
      MaterialPageRoute(builder: (_) => const TokenPackFormPage()),
    );
    if (!mounted || pack == null) return;
    if (nameTaken(pack)) {
      context.showMessage('Un pack « ${pack.name} » existe déjà.');
      return;
    }
    try {
      await FundingRepository.tokenPacks.add(pack.toMap());
      await loadPacks();
      if (!mounted) return;
      context.showMessage('Pack « ${pack.name} » ajouté.');
    } on Exception catch (exception) {
      if (!mounted) return;
      context.showMessage('Impossible d’ajouter le pack : $exception');
    }
  }

  Future<void> editPack(TokenPack pack) async {
    final id = pack.id;
    if (id == null) return;
    final changed = await Navigator.push<TokenPack>(
      context,
      MaterialPageRoute(builder: (_) => TokenPackFormPage(initialPack: pack)),
    );
    if (!mounted || changed == null) return;
    if (nameTaken(changed)) {
      context.showMessage('Un pack « ${changed.name} » existe déjà.');
      return;
    }
    try {
      final rows = await FundingRepository.tokenPacks.update(
        id,
        changed.toMap(),
      );
      if (rows != 1) throw Exception('Ce pack est introuvable.');
      await loadPacks();
    } on Exception catch (exception) {
      if (!mounted) return;
      context.showMessage('Impossible de modifier le pack : $exception');
    }
  }

  Future<void> deletePack(TokenPack pack) async {
    final id = pack.id;
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le pack ?'),
        content: Text('Voulez-vous supprimer le pack « ${pack.name} » ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    try {
      final rows = await FundingRepository.tokenPacks.remove(id);
      if (rows != 1) throw Exception('Ce pack est introuvable.');
      await loadPacks();
    } on Exception catch (exception) {
      if (!mounted) return;
      context.showMessage('Impossible de supprimer le pack : $exception');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Seul l'administrateur peut créer, modifier ou supprimer des packs.
    if (!Permissions.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Gestion des packs de jetons')),
        body: const AccessDeniedView(),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des packs de jetons'),
        actions: [
          IconButton(
            onPressed: loadPacks,
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addPack,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nouveau pack'),
      ),
      body: loading
          ? const LoadingSkeleton()
          : error != null
          ? DatabaseErrorView(message: error!, onRetry: loadPacks)
          : packs.isEmpty
          ? const EmptyState(
              icon: Icons.toll_outlined,
              message: 'Aucun pack enregistré.',
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              itemCount: packs.length,
              itemBuilder: (context, index) {
                final pack = packs[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Icon(
                        pack.highlighted
                            ? Icons.star_rounded
                            : Icons.toll_rounded,
                      ),
                    ),
                    title: Text('Pack ${pack.name}'),
                    subtitle: Text(
                      '${pack.tokens} jetons'
                      ' • +${pack.bonusPercent} % offerts'
                      ' • -${pack.discountPercent} % de réduction',
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (action) {
                        if (action == 'edit') editPack(pack);
                        if (action == 'delete') deletePack(pack);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Modifier')),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Supprimer'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
