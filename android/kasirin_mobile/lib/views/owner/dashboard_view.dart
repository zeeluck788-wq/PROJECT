import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../providers.dart';
import 'owner_widgets.dart';

class DashboardView extends ConsumerStatefulWidget {
  const DashboardView({super.key});

  @override
  ConsumerState<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends ConsumerState<DashboardView> {
  final _rupiahFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  bool _isLoading = true;
  Map<String, dynamic> _stats = {
    'productCount': 0,
    'todaySales': 0,
    'todayCount': 0,
    'activeShifts': 0,
    'lowStockCount': 0,
  };
  String _storeName = 'Toko Kasirin';

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      final repository = await ref.read(repositoryFutureProvider.future);
      final stats = await repository.getDashboardStats();
      final store = await repository.getStore();

      if (mounted) {
        setState(() {
          _stats = stats;
          if (store != null) {
            _storeName = store.read<String>('name');
          }
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    final menuItems = [
      _DashboardMenuItem(
        title: 'Kasir POS',
        subtitle: 'Mulai transaksi penjualan',
        icon: Icons.point_of_sale_rounded,
        color: const Color(0xFF006EAE),
        route: '/cashier',
      ),
      _DashboardMenuItem(
        title: 'Produk & Stok',
        subtitle: 'Kelola katalog, harga, dan persediaan',
        icon: Icons.inventory_2_outlined,
        color: const Color(0xFF18794E),
        route: '/master-data',
      ),
      _DashboardMenuItem(
        title: 'Harga Spesial',
        subtitle: 'Atur harga grosir berdasarkan jumlah',
        icon: Icons.sell_rounded,
        color: const Color(0xFFD14F87),
        route: '/special-prices',
      ),
      _DashboardMenuItem(
        title: 'Laporan & Keuangan',
        subtitle: 'Pantau penjualan dan aktivitas toko',
        icon: Icons.bar_chart_rounded,
        color: const Color(0xFF6B5CE7),
        route: '/report-center',
      ),
      _DashboardMenuItem(
        title: 'Tim & Akses',
        subtitle: 'Atur karyawan dan hak akses',
        icon: Icons.groups_2_rounded,
        color: const Color(0xFFB7791F),
        route: '/user-management',
      ),
      _DashboardMenuItem(
        title: 'Pembelian',
        subtitle: 'Pesanan barang dan supplier',
        icon: Icons.local_shipping_rounded,
        color: const Color(0xFF288A75),
        route: '/purchase',
      ),
      _DashboardMenuItem(
        title: 'Profil Toko',
        subtitle: 'Atur identitas dan informasi toko',
        icon: Icons.storefront_rounded,
        color: const Color(0xFF526579),
        route: '/store-settings',
      ),
      _DashboardMenuItem(
        title: 'Lisensi & Trial',
        subtitle: 'Periksa status aktivasi aplikasi',
        icon: Icons.shield_rounded,
        color: const Color(0xFF0877B9),
        route: '/license',
      ),
    ];

    final ownerIdentity = Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: ownerBlue.withValues(alpha: .1),
          child: const Icon(Icons.person_rounded, size: 30, color: ownerBlue),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                authState.fullName ?? 'Pemilik Toko',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ownerInk,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: ownerBlue.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      authState.role ?? 'OWNER',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: ownerBlue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '@${authState.username ?? 'user'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: ownerMuted),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
    final cashierAction = FilledButton.icon(
      onPressed: () => context.go('/cashier'),
      icon: const Icon(Icons.point_of_sale_rounded, size: 18),
      label: const Text('Buka Kasir'),
    );

    return Scaffold(
      backgroundColor: ownerCanvas,
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFFE7F2F9),
                      foregroundColor: ownerBlue,
                      child: Icon(Icons.storefront_rounded),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_storeName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 16)),
                          Text(authState.fullName ?? 'Pemilik Toko',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: ownerMuted, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    for (final item in menuItems)
                      ListTile(
                        leading: Icon(item.icon, color: item.color),
                        title: Text(item.title),
                        subtitle: Text(item.subtitle),
                        onTap: () {
                          Navigator.of(context).pop();
                          context.go(item.route);
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        title: Text(
          _storeName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Segarkan',
            onPressed: _loadDashboardData,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Keluar',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Keluar dari Aplikasi?'),
                  content: const Text(
                      'Anda perlu memasukkan username & password kembali untuk masuk.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Batal'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB42318),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Keluar'),
                    ),
                  ],
                ),
              );

              if (confirmed == true && context.mounted) {
                await ref.read(authNotifierProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Greeting Card
                  OwnerSurface(
                    child: LayoutBuilder(
                      builder: (context, constraints) => constraints.maxWidth < 520
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ownerIdentity,
                                const SizedBox(height: 16),
                                cashierAction,
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(child: ownerIdentity),
                                const SizedBox(width: 20),
                                cashierAction,
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Stat Cards
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth < 560
                          ? constraints.maxWidth
                          : (constraints.maxWidth - 24) / 3;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                      SizedBox(
                        width: width,
                        child: _StatCard(
                          title: 'Penjualan Hari Ini',
                          value: _rupiahFormat
                              .format(_stats['todaySales'] ?? 0),
                          icon: Icons.payments_rounded,
                          color: const Color(0xFF18794E),
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _StatCard(
                          title: 'Total Produk',
                          value: '${_stats['productCount'] ?? 0}',
                          icon: Icons.inventory_2_rounded,
                          color: const Color(0xFF006EAE),
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _StatCard(
                          title: 'Shift Aktif',
                          value: '${_stats['activeShifts'] ?? 0}',
                          icon: Icons.timer_rounded,
                          color: const Color(0xFF9A6700),
                        ),
                      ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  const OwnerSectionHeading(
                    title: 'Menu Operasional',
                    subtitle: 'Semua kebutuhan toko, dalam satu tempat.',
                  ),
                  const SizedBox(height: 16),
                  // Menu Grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 360,
                      mainAxisExtent: 148,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                    ),
                    itemCount: menuItems.length,
                    itemBuilder: (context, index) {
                      final item = menuItems[index];

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: ownerBorder),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x080F172A),
                              blurRadius: 18,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => context.go(item.route),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 58,
                                    height: 58,
                                    decoration: BoxDecoration(
                                      color: item.color.withValues(alpha: .09),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: Icon(item.icon, color: item.color, size: 29),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            height: 1.2,
                                            fontWeight: FontWeight.w700,
                                            color: ownerInk,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          item.subtitle,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            height: 1.3,
                                            color: ownerMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 19,
                                    color: item.color.withValues(alpha: .75),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _DashboardMenuItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;

  _DashboardMenuItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
  });
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return OwnerSurface(
      padding: const EdgeInsets.all(16),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF586575),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
      ],
      ),
    );
  }
}
