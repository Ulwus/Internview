import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/session_listenable.dart';
import '../../../core/models/domain_models.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/token_storage.dart';
import '../data/auth_repository.dart';

class AuthState {
  AuthState({
    required this.accessToken,
    required this.refreshToken,
    required this.me,
  });

  final String accessToken;
  final String refreshToken;
  final MeData me;

  /// JWT veya /me — öncelik JWT claim (UI yönlendirme).
  String get role => decodeJwtRole(accessToken) ?? me.primaryRole;

  String get userId => decodeJwtSub(accessToken) ?? me.userId;
}

final authControllerProvider = NotifierProvider<AuthController, AuthState?>(
  AuthController.new,
);

class AuthController extends Notifier<AuthState?> {
  @override
  AuthState? build() => null;

  AuthRepository get _repo => ref.read(authRepositoryProvider);
  TokenStorage get _storage => ref.read(tokenStorageProvider);

  Future<void> restore() async {
    final access = await _storage.readAccess();
    final refresh = await _storage.readRefresh();
    if (access == null || refresh == null) {
      state = null;
      return;
    }
    final me = await _repo.tryRestoreSession();
    if (me == null) {
      state = null;
      return;
    }
    state = AuthState(accessToken: access, refreshToken: refresh, me: me);
  }

  Future<void> login(String email, String password) async {
    final me = await _repo.login(email, password);
    final access = await _storage.readAccess();
    final r = await _storage.readRefresh();
    if (access == null || r == null) throw StateError('Token kaydı yok');
    state = AuthState(accessToken: access, refreshToken: r, me: me);
    sessionListenable.notifySessionChanged();
  }

  Future<void> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
  }) async {
    final me = await _repo.register(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      role: role,
    );
    final access = await _storage.readAccess();
    final r = await _storage.readRefresh();
    if (access == null || r == null) throw StateError('Token kaydı yok');
    state = AuthState(accessToken: access, refreshToken: r, me: me);
    sessionListenable.notifySessionChanged();
  }

  Future<void> logout() async {
    await _repo.logout();
    state = null;
    sessionListenable.notifySessionChanged();
  }
}
