import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/models/domain_models.dart';
import 'auth_remote_data_source.dart';

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>(
  (ref) => AuthRemoteDataSource(ref.watch(dioProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(authRemoteDataSourceProvider),
    ref.watch(tokenStorageProvider),
  ),
);

class AuthRepository {
  AuthRepository(this._remote, this._storage);

  final AuthRemoteDataSource _remote;
  final TokenStorage _storage;

  Future<MeData> login(String email, String password) async {
    final t = await _remote.login(email, password);
    await _storage.writeTokens(access: t.accessToken, refresh: t.refreshToken);
    return _remote.me();
  }

  Future<MeData> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
  }) async {
    final t = await _remote.register(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      role: role,
    );
    await _storage.writeTokens(access: t.accessToken, refresh: t.refreshToken);
    return _remote.me();
  }

  Future<MeData?> tryRestoreSession() async {
    final access = await _storage.readAccess();
    final refresh = await _storage.readRefresh();
    if (access == null || refresh == null) return null;
    try {
      return await _remote.me();
    } catch (_) {
      await _storage.clear();
      return null;
    }
  }

  Future<void> logout() => _storage.clear();
}
