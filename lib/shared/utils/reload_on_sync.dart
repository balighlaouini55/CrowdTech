// Recharge un écran quand des données reçues d'un autre appareil
// (Firestore) ont modifié la base locale.

import 'package:crowdtech/core/firebase/firebase_sync.dart';
import 'package:flutter/widgets.dart';

mixin ReloadOnSync<T extends StatefulWidget> on State<T> {
  /// Relit les données de l'écran.
  void reloadAfterSync();

  void _onSync() {
    if (mounted) reloadAfterSync();
  }

  @override
  void initState() {
    super.initState();
    FirebaseSync.revision.addListener(_onSync);
  }

  @override
  void dispose() {
    FirebaseSync.revision.removeListener(_onSync);
    super.dispose();
  }
}
