import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AuthStateType { unauthenticated, authenticated }

class AuthState {
  final AuthStateType type;
  final int? userId;
  final String? username;
  final String? fullName;
  final String? role;

  const AuthState.unauthenticated()
    : type = AuthStateType.unauthenticated,
      userId = null,
      username = null,
      fullName = null,
      role = null;

  const AuthState.authenticated({
    required int userId,
    required String username,
    required String fullName,
    required String role,
  }) : type = AuthStateType.authenticated,
       userId = userId,
       username = username,
       fullName = fullName,
       role = role;

  bool get isAuthenticated => type == AuthStateType.authenticated;

  bool get isOwner => role == 'OWNER' || role == 'owner';

  bool get isCashier => role == 'CASHIER' || role == 'cashier';

  bool get canAccessManagement =>
      role == 'OWNER' || role == 'ADMIN' || role == 'SUPERVISOR';

  bool get isAdmin => role == 'ADMIN' || role == 'admin';

  bool get isSupervisor => role == 'SUPERVISOR' || role == 'supervisor';
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    return const AuthState.unauthenticated();
  }

  void setAuthenticated({
    required int userId,
    required String username,
    required String fullName,
    required String role,
  }) {
    state = AuthState.authenticated(
      userId: userId,
      username: username,
      fullName: fullName,
      role: role,
    );
  }

  Future<void> logout() async {
    state = const AuthState.unauthenticated();
  }
}
