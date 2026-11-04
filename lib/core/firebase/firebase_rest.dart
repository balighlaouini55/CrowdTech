// Firebase (plan Spark, gratuit) par ses API REST, sans SDK natif :
// - Firebase Auth : inscription, connexion, email de réinitialisation ;
// - Cloud Firestore : partage des données entre appareils (voir FirebaseSync) ;
// - Firebase Storage : envoi des photos de produits.
//
// Configuration (fichier config.json, voir config.example.json) :
//   flutter run --dart-define-from-file=config.json
// Sans configuration, l'application fonctionne en mode local (SQLite).

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class FirebaseException implements Exception {
  final String code;
  final String message;
  const FirebaseException(this.code, this.message);

  @override
  String toString() => message;
}

class FirebaseRest {
  FirebaseRest._();

  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
  );

  /// Remplaçables dans les tests.
  static http.Client client = http.Client();
  static bool? enabledOverride;

  static bool get authEnabled => enabledOverride ?? apiKey.isNotEmpty;
  static bool get firestoreEnabled =>
      enabledOverride ?? (apiKey.isNotEmpty && projectId.isNotEmpty);
  static bool get storageEnabled =>
      enabledOverride ?? (apiKey.isNotEmpty && storageBucket.isNotEmpty);

  /// Jeton de la session Firebase (envoyé à Firestore et Storage).
  static String? idToken;
  static String? uid;

  static const _timeout = Duration(seconds: 15);

  /// Messages Firebase traduits pour l'utilisateur.
  static const _messages = {
    'EMAIL_EXISTS': 'Un compte existe déjà avec cet email.',
    'EMAIL_NOT_FOUND': 'Email ou mot de passe incorrect.',
    'INVALID_PASSWORD': 'Email ou mot de passe incorrect.',
    'INVALID_LOGIN_CREDENTIALS': 'Email ou mot de passe incorrect.',
    'USER_DISABLED': 'Ce compte a été désactivé.',
    'TOO_MANY_ATTEMPTS_TRY_LATER': 'Trop de tentatives : réessayez plus tard.',
    'WEAK_PASSWORD': 'Mot de passe trop faible (6 caractères minimum).',
    'INVALID_EMAIL': 'Email invalide.',
  };

  static Future<Map<String, Object?>> _post(
    Uri uri,
    Map<String, Object?> body, {
    Map<String, String> headers = const {},
  }) async {
    final http.Response response;
    try {
      response = await client
          .post(
            uri,
            headers: {'Content-Type': 'application/json', ...headers},
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } on Exception catch (error) {
      throw FirebaseException('NETWORK', 'Firebase injoignable : $error');
    }
    return _decode(response);
  }

  static Map<String, Object?> _decode(http.Response response) {
    final Object? json;
    try {
      json = response.body.isEmpty ? const {} : jsonDecode(response.body);
    } on FormatException {
      throw FirebaseException(
        'HTTP_${response.statusCode}',
        'Réponse Firebase invalide.',
      );
    }
    if (response.statusCode >= 400) {
      final error = json is Map ? json['error'] : null;
      final raw = error is Map ? error['message']?.toString() ?? '' : '';
      final code = raw.split(' ').first.split(':').first.trim();
      throw FirebaseException(
        code.isEmpty ? 'HTTP_${response.statusCode}' : code,
        _messages[code] ?? 'Erreur Firebase : $raw',
      );
    }
    return json is Map ? Map<String, Object?>.from(json) : const {};
  }

  // ---------------------------------------------------------------------------
  // Firebase Auth (Identity Toolkit)

  static Uri _auth(String action) => Uri.https(
    'identitytoolkit.googleapis.com',
    '/v1/accounts:$action',
    {'key': apiKey},
  );

  /// Jeton de renouvellement et heure d'expiration du jeton de session
  /// (valable une heure).
  static String? _refreshToken;
  static DateTime? _expiresAt;

  static void _keepSession(Map<String, Object?> json) {
    idToken = json['idToken']?.toString();
    uid = json['localId']?.toString();
    _refreshToken = json['refreshToken']?.toString();
    final seconds = int.tryParse('${json['expiresIn']}');
    _expiresAt = seconds == null
        ? null
        : DateTime.now().add(Duration(seconds: seconds - 60));
  }

  /// Renouvelle le jeton de session s'il a expiré (Secure Token API).
  static Future<void> _refreshIfNeeded() async {
    final expiresAt = _expiresAt;
    final refreshToken = _refreshToken;
    if (expiresAt == null || refreshToken == null) return;
    if (DateTime.now().isBefore(expiresAt)) return;
    final json = await _post(
      Uri.https('securetoken.googleapis.com', '/v1/token', {'key': apiKey}),
      {'grant_type': 'refresh_token', 'refresh_token': refreshToken},
    );
    _keepSession({
      'idToken': json['id_token'],
      'localId': json['user_id'],
      'refreshToken': json['refresh_token'],
      'expiresIn': json['expires_in'],
    });
  }

  static Future<void> signUp(String email, String password) async {
    _keepSession(
      await _post(_auth('signUp'), {
        'email': email,
        'password': password,
        'returnSecureToken': true,
      }),
    );
  }

  static Future<void> signIn(String email, String password) async {
    _keepSession(
      await _post(_auth('signInWithPassword'), {
        'email': email,
        'password': password,
        'returnSecureToken': true,
      }),
    );
  }

  /// Envoie l'email de réinitialisation du mot de passe (Firebase).
  static Future<void> sendPasswordReset(String email) async {
    await _post(_auth('sendOobCode'), {
      'requestType': 'PASSWORD_RESET',
      'email': email,
    });
  }

  static void signOut() {
    idToken = null;
    uid = null;
    _refreshToken = null;
    _expiresAt = null;
  }

  // ---------------------------------------------------------------------------
  // Cloud Firestore (REST)

  /// Valeur Dart → valeur typée Firestore.
  static Map<String, Object?> encodeValue(Object? value) => switch (value) {
    null => {'nullValue': null},
    final bool b => {'booleanValue': b},
    final int i => {'integerValue': '$i'},
    final double d => {'doubleValue': d},
    final String s => {'stringValue': s},
    final List<Object?> list => {
      'arrayValue': {'values': list.map(encodeValue).toList()},
    },
    final Map<Object?, Object?> map => {
      'mapValue': {
        'fields': {
          for (final MapEntry(:key, :value) in map.entries)
            key.toString(): encodeValue(value),
        },
      },
    },
    _ => {'stringValue': value.toString()},
  };

  /// Valeur typée Firestore → valeur Dart.
  static Object? decodeValue(Object? value) {
    if (value is! Map) return null;
    if (value.containsKey('stringValue')) return value['stringValue'];
    if (value.containsKey('booleanValue')) return value['booleanValue'];
    if (value.containsKey('timestampValue')) return value['timestampValue'];
    if (value.containsKey('integerValue')) {
      return int.tryParse(value['integerValue'].toString());
    }
    if (value.containsKey('doubleValue')) {
      return (value['doubleValue'] as num?)?.toDouble();
    }
    if (value['arrayValue'] case final Map array) {
      return [
        for (final item in (array['values'] as List? ?? [])) decodeValue(item),
      ];
    }
    if (value['mapValue'] case final Map map) {
      return {
        for (final MapEntry(:key, :value)
            in ((map['fields'] as Map?) ?? {}).entries)
          key.toString(): decodeValue(value),
      };
    }
    return null;
  }

  static String get _documents =>
      '/v1/projects/$projectId/databases/(default)/documents';

  static Uri _firestore(String path) => Uri.https(
    'firestore.googleapis.com',
    '$_documents$path',
    {'key': apiKey},
  );

  /// En-têtes d'authentification, après renouvellement du jeton si besoin.
  static Future<Map<String, String>> _authHeaders() async {
    await _refreshIfNeeded();
    return {
      'Content-Type': 'application/json',
      if (idToken case final token?) 'Authorization': 'Bearer $token',
    };
  }

  static Future<http.Response> _send(
    Future<http.Response> Function(Map<String, String> headers) request,
  ) async {
    final headers = await _authHeaders();
    try {
      return await request(headers).timeout(_timeout);
    } on Exception catch (error) {
      throw FirebaseException('NETWORK', 'Firestore injoignable : $error');
    }
  }

  /// Crée ou remplace un document. Le champ `syncedAt` reçoit l'heure du
  /// serveur Firestore : les autres appareils s'en servent pour ne lire que
  /// les changements récents, sans dépendre de l'horloge des téléphones.
  /// Avec [createOnly], rien n'est écrit si le document existe déjà
  /// (retourne false).
  static Future<bool> setDocument(
    String collection,
    String id,
    Map<String, Object?> data, {
    bool createOnly = false,
  }) async {
    final response = await _send(
      (headers) => client.post(
        _firestore(':commit'),
        headers: headers,
        body: jsonEncode({
          'writes': [
            {
              'update': {
                'name':
                    '${_documents.replaceFirst('/v1/', '')}/$collection/$id',
                'fields': {
                  for (final MapEntry(:key, :value) in data.entries)
                    key: encodeValue(value),
                },
              },
              'updateTransforms': [
                {'fieldPath': 'syncedAt', 'setToServerValue': 'REQUEST_TIME'},
              ],
              if (createOnly) 'currentDocument': {'exists': false},
            },
          ],
        }),
      ),
    );
    try {
      _decode(response);
    } on FirebaseException catch (error) {
      if (createOnly &&
          (error.code == 'ALREADY_EXISTS' ||
              error.code == 'FAILED_PRECONDITION' ||
              response.statusCode == 409)) {
        return false;
      }
      rethrow;
    }
    return true;
  }

  /// Document [collection]/[id], ou null s'il n'existe pas.
  static Future<Map<String, Object?>?> getDocument(
    String collection,
    String id,
  ) async {
    final response = await _send(
      (headers) => client.get(_firestore('/$collection/$id'), headers: headers),
    );
    if (response.statusCode == 404) return null;
    return _fieldsOf(_decode(response));
  }

  /// Documents de [collection] (nom ou chemin, par exemple
  /// `users/{uid}/cart`) modifiés après [since] (heure serveur
  /// `syncedAt` d'un document déjà reçu), ou tous si [since] est null.
  /// Chaque résultat contient ses champs, `documentId` et `syncedAt`.
  static Future<List<Map<String, Object?>>> changedSince(
    String collection,
    String? since,
  ) async {
    final segments = collection.split('/');
    final parent = segments.sublist(0, segments.length - 1).join('/');
    final response = await _send(
      (headers) => client.post(
        _firestore(parent.isEmpty ? ':runQuery' : '/$parent:runQuery'),
        headers: headers,
        body: jsonEncode({
          'structuredQuery': {
            'from': [
              {'collectionId': segments.last},
            ],
            if (since != null)
              'where': {
                'fieldFilter': {
                  'field': {'fieldPath': 'syncedAt'},
                  'op': 'GREATER_THAN',
                  'value': {'timestampValue': since},
                },
              },
          },
        }),
      ),
    );
    if (response.statusCode >= 400) _decode(response);
    final results = jsonDecode(response.body);
    return [
      if (results is List)
        for (final result in results)
          if (result is Map && result['document'] is Map)
            _fieldsOf(Map<String, Object?>.from(result['document'] as Map)),
    ];
  }

  /// Champs décodés d'un document, avec son identifiant (`documentId`).
  static Map<String, Object?> _fieldsOf(Map<String, Object?> document) => {
    'documentId': document['name'].toString().split('/').last,
    for (final MapEntry(:key, :value)
        in ((document['fields'] as Map?) ?? const {}).entries)
      key.toString(): decodeValue(value),
  };

  // ---------------------------------------------------------------------------
  // Firebase Storage (REST)

  /// Envoie un fichier et retourne son URL de téléchargement publique.
  static Future<String> upload(
    String path,
    Uint8List bytes, {
    String contentType = 'image/jpeg',
  }) async {
    final uri = Uri.https(
      'firebasestorage.googleapis.com',
      '/v0/b/$storageBucket/o',
      {'name': path, 'uploadType': 'media'},
    );
    final headers = {...await _authHeaders(), 'Content-Type': contentType};
    final http.Response response;
    try {
      response = await client
          .post(uri, headers: headers, body: bytes)
          .timeout(const Duration(seconds: 30));
    } on Exception catch (error) {
      throw FirebaseException('NETWORK', 'Storage injoignable : $error');
    }
    final json = _decode(response);
    final token = json['downloadTokens']?.toString().split(',').first;
    final encoded = Uri.encodeComponent(path);
    return 'https://firebasestorage.googleapis.com/v0/b/$storageBucket/o/'
        '$encoded?alt=media${token == null ? '' : '&token=$token'}';
  }
}
