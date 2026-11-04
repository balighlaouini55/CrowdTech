// Have I Been Pwned — Pwned Passwords (gratuit, sans clé) : vérifie qu'un
// mot de passe n'apparaît pas dans une fuite de données connue.
//
// Le mot de passe ne quitte jamais l'appareil : seuls les 5 premiers
// caractères de son empreinte SHA-1 sont envoyés (« k-anonymat ») ; le
// serveur renvoie toutes les empreintes qui commencent ainsi, et la
// comparaison se fait sur le téléphone.

import 'dart:convert';

import 'package:crowdtech/core/network/crowdtech_api.dart';
import 'package:crypto/crypto.dart';

class PasswordBreach {
  PasswordBreach._();

  /// Empreinte SHA-1 en majuscules, coupée en préfixe (5) et suffixe.
  static ({String prefix, String suffix}) hashParts(String password) {
    final hash = sha1.convert(utf8.encode(password)).toString().toUpperCase();
    return (prefix: hash.substring(0, 5), suffix: hash.substring(5));
  }

  /// Nombre de fuites où ce suffixe apparaît dans la réponse du serveur.
  static int countIn(String body, String suffix) {
    for (final line in const LineSplitter().convert(body)) {
      final parts = line.trim().split(':');
      if (parts.length == 2 && parts.first == suffix) {
        return int.tryParse(parts.last) ?? 1;
      }
    }
    return 0;
  }

  /// Nombre de fuites contenant [password] (0 = jamais vu), ou null si le
  /// service ne répond pas (la vérification ne bloque alors personne).
  static Future<int?> breachCount(String password) async {
    final (:prefix, :suffix) = hashParts(password);
    try {
      final response = await CrowdTechApi.client
          .get(
            Uri.https('api.pwnedpasswords.com', '/range/$prefix'),
            headers: {'Add-Padding': 'true'},
          )
          .timeout(CrowdTechApi.timeout);
      if (response.statusCode != 200) return null;
      return countIn(response.body, suffix);
    } on Exception {
      return null;
    }
  }

  /// Message d'erreur si le mot de passe a fuité, sinon null.
  static Future<String?> check(String password) async {
    final count = await breachCount(password);
    if (count == null || count == 0) return null;
    return 'Ce mot de passe apparaît dans $count fuite(s) de données '
        'connue(s) : choisissez-en un autre.';
  }
}
