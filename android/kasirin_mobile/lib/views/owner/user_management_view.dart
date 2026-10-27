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
  final _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

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

  Future<void> _showUserDialog({QueryRow? user}) async {
    final editing = user != null;
    final formKey = GlobalKey<FormState>();
    final usernameController = TextEditingController(
      text: user?.read<String>('username') ?? '',
    );
    final fullNameController = TextEditingController(
      text: user?.read<String>('full_name') ?? '',
    );
    final whatsappController = TextEditingController(
      text: user?.read<String?>('whatsapp') ?? '',
    );
    final passwordController = TextEditingController();
    String selectedRole = user?.read<String>('role_name') ?? 'CASHIER';

    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              editing ? 'Ubah Akun Pengguna' : 'Tambah Akun Pengguna',
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 420,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: fullNameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Nama lengkap *',
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Nama lengkap wajib diisi.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: usernameController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Username untuk login *',
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Username wajib diisi.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: whatsappController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Nomor WhatsApp (opsional)',
                          hintText: '081234567890',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedRole,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Jabatan / hak akses',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'CASHIER',
                            child: Text('Kasir'),
                          ),
                          DropdownMenuItem(
                            value: 'ADMIN',
                            child: Text('Manajer'),
                          ),
                          DropdownMenuItem(
                            value: 'SUPERVISOR',
                            child: Text('Supervisor Umum'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => selectedRole = value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: editing
                              ? 'Kata sandi baru (opsional)'
                              : 'Kata sandi *',
                          helperText: editing
                              ? 'Kosongkan jika tidak ingin mengubah kata sandi.'
                              : 'Minimal 8 karakter.',
                        ),
                        validator: (value) {
                          if (!editing && (value == null || value.length < 8)) {
                            return 'Kata sandi minimal 8 karakter.';
                          }
                          if (editing &&
                              value != null &&
                              value.isNotEmpty &&
                              value.length < 8) {
                            return 'Kata sandi minimal 8 karakter.';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(dialogContext, true);
                  }
                },
                child: Text(editing ? 'Simpan perubahan' : 'Buat akun'),
              ),
            ],
          ),
        ),
      );
      if (result != true || !mounted) return;

      final repository = await ref.read(repositoryFutureProvider.future);
      if (editing) {
        await repository.updateUser(
          userId: user.read<int>('id'),
          username: usernameController.text,
          fullName: fullNameController.text,
          role: selectedRole,
          whatsapp: whatsappController.text,
          newPassword: passwordController.text,
        );
      } else {
        await repository.addUser(
          username: usernameController.text,
          fullName: fullNameController.text,
          password: passwordController.text,
          role: selectedRole,
          whatsapp: whatsappController.text,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              editing
                  ? 'Perubahan akun berhasil disimpan.'
                  : 'Akun pengguna berhasil dibuat.',
            ),
            backgroundColor: const Color(0xFF18794E),
          ),
        );
        await _loadUsers();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('StateError: ', '')),
            backgroundColor: const Color(0xFFB42318),
          ),
        );
      }
    } finally {
      usernameController.dispose();
      fullNameController.dispose();
      whatsappController.dispose();
      passwordController.dispose();
    }
  }

  Future<void> _setUserActive(QueryRow user, bool active) async {
    final auth = ref.read(authNotifierProvider);
    final userId = user.read<int>('id');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(active ? 'Aktifkan akun?' : 'Nonaktifkan akun?'),
        content: Text(
          active
              ? 'Pengguna ${user.read<String>('full_name')} dapat login kembali.'
              : 'Pengguna ${user.read<String>('full_name')} tidak dapat login sampai akun diaktifkan kembali.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(active ? 'Aktifkan' : 'Nonaktifkan'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      if (auth.userId == null) throw StateError('Sesi pemilik sudah berakhir.');
      final repository = await ref.read(repositoryFutureProvider.future);
      await repository.setUserActive(
        userId: userId,
        actorId: auth.userId!,
        active: active,
      );
      await _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              active
                  ? 'Akun berhasil diaktifkan.'
                  : 'Akun berhasil dinonaktifkan.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('StateError: ', '')),
          ),
        );
      }
    }
  }

  Future<void> _deleteUser(QueryRow user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus akun pengguna?'),
        content: Text(
          'Akun ${user.read<String>('full_name')} akan dihapus dari daftar dan tidak dapat login. Riwayat transaksi tetap disimpan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB42318),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus akun'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final actorId = ref.read(authNotifierProvider).userId;
      if (actorId == null) throw StateError('Sesi pemilik sudah berakhir.');
      final repository = await ref.read(repositoryFutureProvider.future);
      await repository.deleteUser(
        userId: user.read<int>('id'),
        actorId: actorId,
      );
      await _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Akun berhasil dihapus. Riwayat transaksi tetap tersimpan.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('StateError: ', '')),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return OwnerScaffold(
      title: 'Tim & Akses',
      onBack: () => context.go('/'),
      onAdd: _tab == 0 ? () => _showUserDialog() : null,
      addLabel: 'Tambah akun',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: OwnerTabBar<int>(
              tabs: const [(0, 'Anggota tim'), (1, 'Riwayat shift')],
              selected: _tab,
              onSelected: (value) => setState(() => _tab = value),
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
            message:
                'Tambahkan kasir atau pengawas untuk mengelola akses toko.',
          )
        : SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 100),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  const Color(0xFFEAF1F6),
                ),
                columns: const [
                  DataColumn(label: Text('Nama')),
                  DataColumn(label: Text('Username')),
                  DataColumn(label: Text('Peran')),
                  DataColumn(label: Text('WhatsApp')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Kelola akun')),
                ],
                rows: _users.map((user) {
                  final active = user.read<int>('is_active') == 1;
                  final isOwner = user.read<String>('role_name') == 'OWNER';
                  return DataRow(
                    cells: [
                      DataCell(Text(user.read<String>('full_name'))),
                      DataCell(Text('@${user.read<String>('username')}')),
                      DataCell(
                        Text(_roleLabel(user.read<String>('role_name'))),
                      ),
                      DataCell(Text(user.read<String?>('whatsapp') ?? '-')),
                      DataCell(
                        Text(
                          active ? 'Aktif' : 'Nonaktif',
                          style: TextStyle(
                            color: active
                                ? const Color(0xFF18794E)
                                : const Color(0xFFB42318),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      DataCell(
                        isOwner
                            ? const Text('Pemilik')
                            : Wrap(
                                spacing: 2,
                                children: [
                                  IconButton(
                                    tooltip: 'Ubah akun',
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () =>
                                        _showUserDialog(user: user),
                                  ),
                                  IconButton(
                                    tooltip: active
                                        ? 'Nonaktifkan akun'
                                        : 'Aktifkan akun',
                                    color: active
                                        ? const Color(0xFFB42318)
                                        : const Color(0xFF18794E),
                                    icon: Icon(
                                      active
                                          ? Icons.person_off_outlined
                                          : Icons.person_outline_rounded,
                                    ),
                                    onPressed: () =>
                                        _setUserActive(user, !active),
                                  ),
                                  IconButton(
                                    tooltip: 'Hapus akun',
                                    color: const Color(0xFFB42318),
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => _deleteUser(user),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 32),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFEAF1F6)),
          columns: const [
            DataColumn(label: Text('Kasir')),
            DataColumn(label: Text('Dibuka')),
            DataColumn(label: Text('Ditutup')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Modal awal'), numeric: true),
            DataColumn(label: Text('Transaksi'), numeric: true),
            DataColumn(label: Text('Penjualan'), numeric: true),
          ],
          rows: _shifts.map((shift) {
            final open =
                shift.read<String>('status') == 'OPEN' &&
                shift.read<String?>('closed_at') == null;
            final closed = shift.read<String?>('closed_at');
            return DataRow(
              cells: [
                DataCell(Text(shift.read<String>('cashier_name'))),
                DataCell(Text(_formatDate(shift.read<String>('opened_at')))),
                DataCell(Text(closed == null ? '-' : _formatDate(closed))),
                DataCell(
                  Text(
                    open ? 'Berjalan' : 'Selesai',
                    style: TextStyle(
                      color: open ? const Color(0xFF18794E) : ownerMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                DataCell(
                  Text(_currency.format(shift.read<int>('opening_cash'))),
                ),
                DataCell(Text('${shift.read<int>('sales_count')}')),
                DataCell(
                  Text(_currency.format(shift.read<int>('sales_total'))),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  String _formatDate(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    return date == null ? value : DateFormat('dd MMM yyyy, HH:mm').format(date);
  }

  String _roleLabel(String role) => switch (role) {
    'CASHIER' => 'Kasir',
    'ADMIN' => 'Manajer',
    'SUPERVISOR' => 'Supervisor Umum',
    'OWNER' => 'Pemilik',
    _ => role,
  };
}
