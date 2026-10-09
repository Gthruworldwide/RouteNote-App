/// A signed-in Google account, decoupled from the plugin types so the rest of
/// the app never imports `google_sign_in` directly.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
  });

  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
}

/// Thrown when Google authorization is required but not available (e.g. the
/// user is signed out or the access token expired during a background run).
class AuthRequiredException implements Exception {
  const AuthRequiredException([this.message = 'Google authorization required']);

  final String message;

  @override
  String toString() => message;
}

/// Thrown for any other Google sign-in failure.
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Contract for authenticating with Google and producing authorization
/// headers for the Drive API.
abstract class AuthService {
  /// Initializes the underlying sign-in manager. Safe to call multiple times.
  Future<void> initialize();

  AuthUser? get currentUser;

  bool get isSignedIn;

  /// Recovers a previously authenticated session without showing UI.
  Future<AuthUser?> restoreSession();

  /// Interactive sign-in plus Drive app-data authorization.
  Future<AuthUser> signIn();

  Future<void> signOut();

  /// Returns HTTP headers (`Authorization: Bearer ...`) for the Drive scope, or
  /// null when the user is not authorized. When [prompt] is true, the platform
  /// may show UI to obtain authorization.
  Future<Map<String, String>?> authorizationHeaders({bool prompt = false});
}
