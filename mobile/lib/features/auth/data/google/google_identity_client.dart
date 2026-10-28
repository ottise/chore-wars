import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleIdentityClient {
  static const webClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: kIsWeb
        ? '940096350136-2k6sarq4ii63t5pm5uicgoenmdb6qvpa.apps.googleusercontent.com'
        : '',
  );
  static const iosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
  static Future<void>? _initialization;
  static bool get enabled =>
      webClientId.isNotEmpty &&
      (kIsWeb ||
          defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS &&
              iosClientId.isNotEmpty);

  static Future<void> initialize() =>
      _initialization ??= GoogleSignIn.instance.initialize(
        clientId: kIsWeb
            ? webClientId
            : defaultTargetPlatform == TargetPlatform.iOS
            ? iosClientId
            : null,
        serverClientId: kIsWeb ? null : webClientId,
      );

  static String token(GoogleSignInAccount account) {
    final token = account.authentication.idToken;
    if (token == null || token.isEmpty) {
      throw StateError('Google did not provide an identity token.');
    }
    return token;
  }
}
