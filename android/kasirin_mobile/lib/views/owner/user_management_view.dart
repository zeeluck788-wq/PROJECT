import 'package:drift/drift.dart' show QueryRow;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../providers.dart';
import 'owner_widgets.dart';

class UserManagementView extends ConsumerStatefulWidget {
  const UserManagementView({super.key});

  @override
  ConsumerState<UserManagementView> createState() => _UserManagementViewState();
}

class _UserManagementViewState extends ConsumerState<UserManagementView> {
  List<QueryRow> _users = [];
  List<QueryRow> _shifts = [];
  bool _isLoading = true;
  int _tab = 0;
  final _currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final repository = await ref.read(repositoryFutureProvider.future);
      final list = await repository.getUsers();
      final shifts = await repository.getShiftHistory();
      if (mounted) {
        setState(() {
          _users = list;
          _shifts = shifts;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showAddUserDialog() async {
    final usernameController = TextEditingController();
    final fullNameController = TextEditingController();
    final whatsappController = TextEditingController();
    final passwordController = TextEditingController();
    String selectedRole = 'CASHIER';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Tambah Karyawan Baru'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(labelText: 'Username *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: fullNameController,
                  decoration: const InputDecoration(labelText: 'Nama Lengkap *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: whatsappController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'WhatsApp (Opsional)',
                    hintText: '081234567890',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  decoration: const InputDecoration(labelText: 'Role / Hak Akses'),
                  items: const [
                    DropdownMenuItem(value: 'CASHIER', child: Text('CASHIER (Kasir)')),
                    DropdownMenuItem(value: 'SUPERVISOR', child: Text('SUPERVISOR (Pengawas)')),
                    DropdownMenuItem(value: 'ADMIN', child: Text('ADMIN (Administrator)')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedRole = val);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password *',
                    hintText: 'Minimal 6 karakter',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF006EAE),
                foregroundColor: Colors.white,
              ),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    if (result == true && mounted) {
      final username = usernameController.text.trim();
      final fullName = fullNameController.text.trim();
      final whatsapp = whatsappController.text.trim();
      final password = passwordController.text;

      if (username.isEmpty || fullName.isEmpty || password.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Semua field bertanda * wajib diisi.'),
            backgroundColor: Color(0xFFB42318),
          ),
        );
        return;
      }

      try {
        final repository = await ref.read(repositoryFutureProvider.future);
        await repository.addUser(
          username: username,
          fullName: fullName,
          password: password,
          role: selectedRole,
          whatsapp: whatsapp.isEmpty ? null : whatsapp,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Karyawan berhasil didaftarkan.'),
              backgroundColor: Color(0xFF18794E),
            ),
          );
          _loadUsers();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$e'),
              backgroundColor: const Color(0xFFB42318),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return OwnerScaffold(
      title: 'Tim & Akses',
      onBack: () => context.go('/'),
      actions: [
        if (_tab == 0)
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: 'Tambah Karyawan',
            onPressed: _showAddUserDialog,
          ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Anggota tim')),
                ButtonSegment(value: 1, label: Text('Riwayat shift')),
              ],
              selected: {_tab},
              onSelectionChanged: (value) => setState(() => _tab = value.first),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _tab == 0
                    ? _buildUsersList()
                    : _buildShiftList(),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersList() {
    return _users.isEmpty
        ? const OwnerEmptyState(
            icon: Icons.group_outlined,
            title: 'Belum ada anggota tim',
            message: 'Tambahkan kasir atau pengawas untuk mengelola akses toko.',
          )
        : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  itemCount: _users.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    final username = user.read<String>('username');
                    final fullName = user.read<String>('full_name');
                    final role = user.read<String>('role_name');
                    final whatsapp = user.read<String?>('whatsapp') ?? '-';
                    final isActive = user.read<int>('is_active') == 1;

                    return OwnerSurface(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: role == 'OWNER'
                                  ? const Color(0xFF006EAE)
                                  : const Color(0xFF586575),
                              foregroundColor: Colors.white,
                              child: Text(
                                fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fullName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Color(0xFF17212B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '@$username  •  WA: $whatsapp',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF586575),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: role == 'OWNER'
                                        ? const Color(0xFF006EAE)
                                            .withValues(alpha: 0.1)
                                        : const Color(0xFF18794E)
                                            .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    role,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: role == 'OWNER'
                                          ? const Color(0xFF006EAE)
                                          : const Color(0xFF18794E),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  isActive ? 'Aktif' : 'Nonaktif',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isActive
                                        ? const Color(0xFF18794E)
                                        : const Color(0xFFB42318),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                    );
                  },
                );
  }

  Widget _buildShiftList() {
    if (_shifts.isEmpty) {
      return const OwnerEmptyState(
        icon: Icons.schedule_rounded,
        title: 'Belum ada riwayat shift',
        message: 'Shift kasir akan tercatat setelah kasir membuka operasional.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      itemCount: _shifts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final shift = _shifts[index];
        final isOpen = shift.read<String>('status') == 'OPEN' &&
            shift.read<String?>('closed_at') == null;
        final openedAt = shift.read<String>('opened_at');
        final closedAt = shift.read<String?>('closed_at');
        return OwnerSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      shift.read<String>('cashier_name'),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                  _StatusChip(
                    label: isOpen ? 'Sedang berjalan' : 'Selesai',
                    active: isOpen,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text('Buka: ${_formatDate(openedAt)}', style: const TextStyle(color: ownerMuted, fontSize: 12)),
              Text(
                closedAt == null ? 'Belum ditutup' : 'Tutup: ${_formatDate(closedAt)}',
                style: const TextStyle(color: ownerMuted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 20,
                runSpacing: 8,
                children: [
                  _ShiftValue(label: 'Penjualan', value: _currency.format(shift.read<int>('sales_total'))),
                  _ShiftValue(label: 'Transaksi', value: '${shift.read<int>('sales_count')}'),
                  _ShiftValue(label: 'Modal awal', value: _currency.format(shift.read<int>('opening_cash'))),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    return date == null ? value : DateFormat('dd MMM yyyy, HH:mm').format(date);
  }
}

class _ShiftValue extends StatelessWidget {
  const _ShiftValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: ownerMuted, fontSize: 11)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(color: ownerInk, fontWeight: FontWeight.w700)),
        ],
      );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF18794E) : ownerMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: .09), borderRadius: BorderRadius.circular(30)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}
