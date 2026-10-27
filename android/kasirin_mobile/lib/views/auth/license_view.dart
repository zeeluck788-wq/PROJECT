import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers.dart';

class LicenseView extends ConsumerStatefulWidget {
  const LicenseView({super.key});

  @override
  ConsumerState<LicenseView> createState() => _LicenseViewState();
}

class _LicenseViewState extends ConsumerState<LicenseView> {
  bool _isChecking = false;
  String _serverStatus = 'Belum diperiksa';
  bool _isServerHealthy = false;

  Future<void> _checkServer() async {
    setState(() => _isChecking = true);
    try {
      final client = ref.read(billingClientProvider);
      final isHealthy = await client.checkServerHealth();
      setState(() {
        _isServerHealthy = isHealthy;
        _serverStatus = isHealthy
            ? 'Server Billing Online & Terhubung'
            : 'Server Offline / Tidak Terjangkau (Mode Offline Aktif)';
      });
    } catch (_) {
      setState(() {
        _isServerHealthy = false;
        _serverStatus = 'Tidak dapat menghubungi server billing.';
      });
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text('Lisensi & Langganan'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFFD7DEE5)),
                  ),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF18794E)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.verified_user_rounded,
                                color: Color(0xFF18794E),
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Status: Versi Uji Coba (Trial)',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF17212B),
                                    ),
                                  ),
                                  Text(
                                    'Masa berlaku trial 7 hari aktif',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF18794E),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: Color(0xFFD7DEE5)),
                        const SizedBox(height: 12),
                        const Text(
                          'Aplikasi Kasirin POS berjalan dalam mode offline-first. Transaksi kasir, produk, dan laporan lokal tersimpan aman di perangkat Anda tanpa membutuhkan koneksi internet konstan.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF586575),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFFD7DEE5)),
                  ),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Koneksi Server Billing',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF17212B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Status: $_serverStatus',
                          style: TextStyle(
                            fontSize: 13,
                            color: _isServerHealthy
                                ? const Color(0xFF18794E)
                                : const Color(0xFF586575),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _isChecking ? null : _checkServer,
                          icon: _isChecking
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.wifi_tethering),
                          label: const Text('Uji Sambungan Server'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
