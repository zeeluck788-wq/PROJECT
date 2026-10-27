
import 'package:flutter_test/flutter_test.dart';
import 'package:kasirin_mobile/views/auth/auth_state.dart';

void main() {
  group('AuthState', () {
    test('status awal adalah unauthenticated', () {
      const state = AuthState.unauthenticated();

      expect(state.isAuthenticated, isFalse);
      expect(state.userId, isNull);
      expect(state.username, isNull);
      expect(state.role, isNull);
    });

    test('OWNER memiliki akses management', () {
      const state = AuthState.authenticated(
        userId: 1,
        username: 'owner',
        fullName: 'Pemilik Toko',
        role: 'OWNER',
      );

      expect(state.isAuthenticated, isTrue);
      expect(state.isOwner, isTrue);
      expect(state.isCashier, isFalse);
      expect(state.canAccessManagement, isTrue);
    });

    test('CASHIER dikenali sebagai kasir', () {
      const state = AuthState.authenticated(
        userId: 2,
        username: 'kasir',
        fullName: 'Pegawai Toko',
        role: 'CASHIER',
      );

      expect(state.isAuthenticated, isTrue);
      expect(state.isCashier, isTrue);
      expect(state.isOwner, isFalse);
    });

    test('ADMIN memiliki akses management', () {
      const state = AuthState.authenticated(
        userId: 3,
        username: 'admin',
        fullName: 'Administrator',
        role: 'ADMIN',
      );

      expect(state.isAdmin, isTrue);
      expect(state.canAccessManagement, isTrue);
    });

    test('SUPERVISOR memiliki akses management', () {
      const state = AuthState.authenticated(
        userId: 4,
        username: 'supervisor',
        fullName: 'Supervisor',
        role: 'SUPERVISOR',
      );

      expect(state.isSupervisor, isTrue);
      expect(state.canAccessManagement, isTrue);
    });
  });
}
