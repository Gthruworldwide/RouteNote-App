import 'package:google_sign_in/google_sign_in.dart';

import '../../core/config/app_config.dart';
import 'auth_service.dart';

/// [AuthService] backed by the official `google_sign_in` plugin (v7 API).
class GoogleAuthService implements AuthService {
  GoogleAuthService();

  bool _initialized = false;
  GoogleSignInAccount? _account;
  AuthUser? _user;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(
      clientId: AppConfig.googleIosClientId.isEmpty
          ? null
          : AppConfig.googleIosClientId,
      serverClientId: AppConfig.googleServerClientId.isEmpty
          ? null
          : AppConfig.googleServerClientId,
    );
    _initialized = true;
  }

  @override
  AuthUser? get currentUser => _user;

  @override
  bool get isSignedIn => _account != null;

  @override
  Future<AuthUser?> restoreSession() async {
    await initialize();
    try {
      final Future<GoogleSignInAccount?>? attempt = GoogleSignIn.instance
          .attemptLightweightAuthentication();
      if (attempt == null) return null;
      final GoogleSignInAccount? account = await attempt;
      if (account == null) return null;
      _account = account;
      _user = _toUser(account);
      return _user;
    } on GoogleSignInException {
      // Silent restore failed; the user can sign in explicitly.
      return null;
    }
  }

  @override
  Future<AuthUser> signIn() async {
    await initialize();
    try {
      final GoogleSignInAccount account = await GoogleSignIn.instance
          .authenticate(scopeHint: AppConfig.driveScopes);
      _account = account;
      _user = _toUser(account);
      await _ensureAuthorized(account);
      return _user!;
    } on GoogleSignInException catch (e) {
      throw AuthException(e.description ?? e.code.name);
    }
  }

  Future<void> _ensureAuthorized(GoogleSignInAccount account) async {
    final GoogleSignInAuthorizationClient client = account.authorizationClient;
    final GoogleSignInClientAuthorization? existing = await client
        .authorizationForScopes(AppConfig.driveScopes);
    if (existing == null) {
      await client.authorizeScopes(AppConfig.driveScopes);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } on GoogleSignInException {
      // Ignore: we clear local state regardless.
    } finally {
      _account = null;
      _user = null;
    }
  }

  @override
  Future<Map<String, String>?> authorizationHeaders({
    bool prompt = false,
  }) async {
    final GoogleSignInAccount? account = _account;
    if (account == null) return null;
    try {
      return await account.authorizationClient.authorizationHeaders(
        AppConfig.driveScopes,
        promptIfNecessary: prompt,
      );
    } on GoogleSignInException {
      return null;
    }
  }

  AuthUser _toUser(GoogleSignInAccount account) {
    return AuthUser(
      id: account.id,
      email: account.email,
      displayName: account.displayName,
      photoUrl: account.photoUrl,
    );
  }
}
