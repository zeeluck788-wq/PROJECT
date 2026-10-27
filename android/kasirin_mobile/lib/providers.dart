import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'data/local_database.dart';
import 'domain/password_hasher.dart';
import 'domain/pos_repository.dart';
import 'services/billing_client.dart';
import 'services/billing_config.dart';
import 'views/auth/auth_state.dart';
import 'views/auth/login_view.dart';
import 'views/auth/license_view.dart';
import 'views/auth/setup_owner_view.dart';
import 'views/owner/dashboard_view.dart';
import 'views/cashier/cashier_view.dart';
import 'views/owner/user_management_view.dart';
import 'views/owner/master_data_view.dart';
import 'views/owner/special_prices_view.dart';
import 'views/owner/purchase_view.dart';
import 'views/reports/report_center_view.dart';
import 'views/owner/store_settings_view.dart';

// --- Riverpod providers ---

final databaseProvider = FutureProvider<KasirinDatabase>((ref) async {
  final db = await openKasirinDatabase();
  ref.onDispose(db.close);
  return db;
});

final passwordHasherProvider = Provider<PasswordHasher>(
  (ref) => PasswordHasher(),
);

final repositoryFutureProvider = FutureProvider<PosRepository>((ref) async {
  final database = await ref.watch(databaseProvider.future);
  return PosRepository(database, ref.read(passwordHasherProvider));
});

final billingConfigProvider = Provider<BillingConfig>((ref) {
  return BillingConfig(
    baseUrl: 'https://trimester-slaw-papaya.ngrok-free.dev',
    apiPrefix: '',
  );
});

final billingClientProvider = Provider<BillingClient>((ref) {
  return BillingClient(ref.watch(billingConfigProvider));
});

// --- Auth ---

final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});

// --- Theme ---

final themeProvider = Provider(
  (ref) => ThemeData(
    primarySwatch: Colors.blue,
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.white,
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
      titleLarge: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
      bodyLarge: TextStyle(fontSize: 16, color: Colors.black87),
      bodyMedium: TextStyle(fontSize: 14, color: Colors.black87),
      labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey.shade100,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.blue, width: 2),
      ),
    ),
  ),
);

// --- GoRouter ---

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authNotifierProvider);
  return GoRouter(
    initialLocation: authState.isAuthenticated ? '/' : '/login',
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      if (!authState.isAuthenticated &&
          state.matchedLocation != '/login' &&
          state.matchedLocation != '/setup') {
        return '/login';
      }
      if (authState.isAuthenticated &&
          authState.isCashier &&
          state.matchedLocation != '/cashier') {
        return '/cashier';
      }
      if (authState.isAuthenticated &&
          !authState.isCashier &&
          state.matchedLocation == '/cashier' &&
          !authState.isOwner) {
        return '/';
      }
      if (authState.isAuthenticated && state.matchedLocation == '/login') {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginView()),
      GoRoute(
        path: '/setup',
        builder: (context, state) => const SetupOwnerView(),
      ),
      GoRoute(
        path: '/license',
        builder: (context, state) => const LicenseView(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const DashboardView(),
        routes: [
          GoRoute(
            path: 'cashier',
            builder: (context, state) => const CashierView(),
          ),
          GoRoute(
            path: 'user-management',
            builder: (context, state) => const UserManagementView(),
          ),
          GoRoute(
            path: 'master-data',
            builder: (context, state) => const MasterDataView(),
          ),
          GoRoute(
            path: 'special-prices',
            builder: (context, state) => const SpecialPricesView(),
          ),
          GoRoute(
            path: 'purchase',
            builder: (context, state) => PurchaseView(
              openNewOrderOnLoad:
                  state.uri.queryParameters['newOrder'] == 'true',
              initialTab: state.uri.queryParameters['tab'] == 'supplier'
                  ? 1
                  : 0,
            ),
          ),
          GoRoute(
            path: 'report-center',
            builder: (context, state) => const ReportCenterView(),
          ),
          GoRoute(
            path: 'store-settings',
            builder: (context, state) => const StoreSettingsView(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Halaman tidak ditemukan')),
      body: Center(child: Text('Halaman tidak ditemukan: ${state.error}')),
    ),
  );
});
