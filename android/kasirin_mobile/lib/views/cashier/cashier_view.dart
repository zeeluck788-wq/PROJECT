import 'dart:math';
import 'package:drift/drift.dart' show QueryRow;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../domain/pos_repository.dart';
import '../../providers.dart';

class CashierCartItem {
  final QueryRow product;
  int quantity;
  int unitPrice;

  CashierCartItem({
    required this.product,
    required this.quantity,
    required this.unitPrice,
  });

  int get lineTotal => quantity * unitPrice;
  int get productId => product.read<int>('id');
  String get name => product.read<String>('name');
  String get sku => product.read<String>('sku');
  int get stock => product.read<int>('stock_qty');
}

class CashierView extends ConsumerStatefulWidget {
  const CashierView({super.key});

  @override
  ConsumerState<CashierView> createState() => _CashierViewState();
}

class _CashierViewState extends ConsumerState<CashierView> {
  final _searchController = TextEditingController();
  final _rupiahFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  List<QueryRow> _products = [];
  final List<CashierCartItem> _cartItems = [];

  bool _isLoadingProducts = true;
  int? _activeShiftId;
  int _openingCash = 0;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final authState = ref.read(authNotifierProvider);
    final userId = authState.userId ?? 1;

    try {
      final repository = await ref.read(repositoryFutureProvider.future);
      // Check active shift
      final activeShift = await repository.openShiftFor(userId);
      if (activeShift != null && mounted) {
        setState(() {
          _activeShiftId = activeShift.read<int>('id');
          _openingCash = activeShift.read<int>('opening_cash');
        });
      }

      await _refreshProducts();
    } catch (_) {
      // Ignored
    } finally {
      if (mounted) {
        setState(() => _isLoadingProducts = false);
      }
    }
  }

  Future<void> _refreshProducts() async {
    try {
      final repository = await ref.read(repositoryFutureProvider.future);
      final list = await repository.products(search: _searchQuery);
      if (mounted) {
        setState(() => _products = list);
      }
    } catch (_) {}
  }

  Future<void> _addToCart(QueryRow product) async {
    final productId = product.read<int>('id');
    final stock = product.read<int>('stock_qty');

    final existingIndex =
        _cartItems.indexWhere((item) => item.productId == productId);
    final currentQtyInCart =
        existingIndex >= 0 ? _cartItems[existingIndex].quantity : 0;

    if (currentQtyInCart + 1 > stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Stok ${product.read<String>('name')} tidak mencukupi.'),
          backgroundColor: const Color(0xFFB42318),
        ),
      );
      return;
    }

    final repository = await ref.read(repositoryFutureProvider.future);
    final newQty = currentQtyInCart + 1;
    final unitPrice = await repository.unitPriceFor(productId, newQty);

    setState(() {
      if (existingIndex >= 0) {
        _cartItems[existingIndex].quantity = newQty;
        _cartItems[existingIndex].unitPrice = unitPrice;
      } else {
        _cartItems.add(
          CashierCartItem(
            product: product,
            quantity: 1,
            unitPrice: unitPrice,
          ),
        );
      }
    });
  }

  Future<void> _updateQuantity(int index, int newQty) async {
    if (newQty <= 0) {
      setState(() => _cartItems.removeAt(index));
      return;
    }

    final item = _cartItems[index];
    if (newQty > item.stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Stok ${item.name} hanya tersisa ${item.stock}.'),
          backgroundColor: const Color(0xFFB42318),
        ),
      );
      return;
    }

    final repository = await ref.read(repositoryFutureProvider.future);
    final unitPrice = await repository.unitPriceFor(item.productId, newQty);

    setState(() {
      item.quantity = newQty;
      item.unitPrice = unitPrice;
    });
  }

  int get _cartTotal =>
      _cartItems.fold(0, (sum, item) => sum + item.lineTotal);

  Future<void> _handleOpenShift() async {
    final amountController = TextEditingController(text: '50000');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Buka Shift Kasir'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan modal kas awal di laci kasir:',
              style: TextStyle(fontSize: 14, color: Color(0xFF586575)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Modal Awal (Rp)',
                prefixText: 'Rp ',
              ),
            ),
          ],
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
            child: const Text('Buka Shift'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final amount = int.tryParse(amountController.text.replaceAll('.', '')) ?? 0;
      final authState = ref.read(authNotifierProvider);
      final userId = authState.userId ?? 1;

      try {
        final repository = await ref.read(repositoryFutureProvider.future);
        final shiftId = await repository.openShift(
          cashierId: userId,
          openingCash: amount,
        );

        if (mounted) {
          setState(() {
            _activeShiftId = shiftId;
            _openingCash = amount;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Shift kasir berhasil dibuka.'),
              backgroundColor: Color(0xFF18794E),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal membuka shift: $e'),
              backgroundColor: const Color(0xFFB42318),
            ),
          );
        }
      }
    }
  }

  Future<void> _handleCloseShift() async {
    if (_activeShiftId == null) return;

    final cashController = TextEditingController(text: '$_openingCash');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Tutup Shift Kasir'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hitung total uang fisik kas di laci:',
              style: TextStyle(fontSize: 14, color: Color(0xFF586575)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: cashController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Total Kas Akhir (Rp)',
                prefixText: 'Rp ',
              ),
            ),
          ],
        ),
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
            child: const Text('Tutup Shift'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final cash = int.tryParse(cashController.text.replaceAll('.', '')) ?? 0;
      final authState = ref.read(authNotifierProvider);
      final userId = authState.userId ?? 1;

      try {
        final repository = await ref.read(repositoryFutureProvider.future);
        await repository.closeShift(
          shiftId: _activeShiftId!,
          cashierId: userId,
          closingCash: cash,
        );

        if (mounted) {
          setState(() {
            _activeShiftId = null;
            _openingCash = 0;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Shift kasir telah ditutup.'),
              backgroundColor: Color(0xFF18794E),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menutup shift: $e'),
              backgroundColor: const Color(0xFFB42318),
            ),
          );
        }
      }
    }
  }

  Future<void> _handleCheckout() async {
    if (_activeShiftId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan Buka Shift terlebih dahulu sebelum checkout.'),
          backgroundColor: Color(0xFF9A6700),
        ),
      );
      return;
    }

    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Keranjang masih kosong.'),
          backgroundColor: Color(0xFF9A6700),
        ),
      );
      return;
    }

    late final Map<String, bool> settings;
    try {
      settings = await (await ref.read(repositoryFutureProvider.future))
          .getPaymentSettings();
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tidak dapat memuat metode pembayaran: $error')),
      );
      return;
    }
    final paymentMethods = <(String, String)>[
      if (settings['cash'] == true) ('CASH', 'Tunai'),
      if (settings['transfer'] == true) ('BANK', 'Transfer bank'),
      if (settings['qrisDana'] == true) ('QRIS_DANA', 'QRIS DANA'),
      if (settings['qrisMidtrans'] == true) ('QRIS_MIDTRANS', 'QRIS Midtrans'),
    ];
    if (paymentMethods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada metode pembayaran yang aktif.')),
      );
      return;
    }

    final total = _cartTotal;
    final cashController = TextEditingController(text: '$total');
    var selectedPaymentMethod = paymentMethods.first.$1;

    final checkoutSuccess = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final enteredCash =
                int.tryParse(cashController.text.replaceAll('.', '')) ?? 0;
            final isCash = selectedPaymentMethod == 'CASH';
            final change = isCash ? max(0, enteredCash - total) : 0;
            final isEnough = !isCash || enteredCash >= total;
            final methodLabel = paymentMethods
                .firstWhere((method) => method.$1 == selectedPaymentMethod)
                .$2;

            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pembayaran $methodLabel',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF17212B),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context, false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F6F8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Belanja:',
                          style: TextStyle(fontSize: 16, color: Color(0xFF586575)),
                        ),
                        Text(
                          _rupiahFormat.format(total),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF006EAE),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedPaymentMethod,
                    decoration: const InputDecoration(labelText: 'Metode pembayaran'),
                    items: paymentMethods
                        .map((method) => DropdownMenuItem(
                              value: method.$1,
                              child: Text(method.$2),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setModalState(() {
                          selectedPaymentMethod = value;
                          if (value != 'CASH') cashController.text = '$total';
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: cashController,
                    enabled: isCash,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Nominal diterima (Rp)',
                      prefixText: 'Rp ',
                      helperText: 'Untuk non-tunai, nominal mengikuti total belanja.',
                    ),
                    onChanged: (_) => setModalState(() {}),
                  ),
                  if (isCash) ...[
                    const SizedBox(height: 12),
                    Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        label: const Text('Uang Pas'),
                        onPressed: () {
                          cashController.text = '$total';
                          setModalState(() {});
                        },
                      ),
                      for (final denom in [10000, 20000, 50000, 100000, 200000])
                        if (denom >= total || denom == 50000 || denom == 100000)
                          ActionChip(
                            label: Text(_rupiahFormat.format(denom)),
                            onPressed: () {
                              cashController.text = '$denom';
                              setModalState(() {});
                            },
                          ),
                    ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Kembalian:',
                        style: TextStyle(fontSize: 16, color: Color(0xFF586575)),
                      ),
                      Text(
                        _rupiahFormat.format(change),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isEnough
                              ? const Color(0xFF18794E)
                              : const Color(0xFFB42318),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: isEnough
                          ? () async {
                              if (!isCash) {
                                final paymentConfirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    title: const Text('Konfirmasi pembayaran'),
                                    content: Text(
                                      'Pastikan pembayaran ${methodLabel.toLowerCase()} sebesar ${_rupiahFormat.format(total)} sudah diterima dan terverifikasi.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(dialogContext, false),
                                        child: const Text('Periksa lagi'),
                                      ),
                                      FilledButton(
                                        onPressed: () => Navigator.pop(dialogContext, true),
                                        child: const Text('Sudah diterima'),
                                      ),
                                    ],
                                  ),
                                );
                                if (paymentConfirmed != true || !context.mounted) return;
                              }
                              final authState = ref.read(authNotifierProvider);
                              final userId = authState.userId ?? 1;
                              final invoiceNo =
                                  'INV-${DateTime.now().toUtc().microsecondsSinceEpoch}';

                              final itemsInput = _cartItems
                                  .map(
                                    (e) => CartItemInput(
                                      productId: e.productId,
                                      quantity: e.quantity,
                                    ),
                                  )
                                  .toList();

                              try {
                                final repository = await ref.read(
                                    repositoryFutureProvider.future);
                                final result = await repository.checkout(
                                  invoiceNo: invoiceNo,
                                  cashierId: userId,
                                  shiftId: _activeShiftId!,
                                  items: itemsInput,
                                  paymentMethod: selectedPaymentMethod,
                                  paymentAmount: isCash ? enteredCash : total,
                                );

                                if (context.mounted) {
                                  Navigator.pop(context, true);
                                  _showReceiptDialog(result, isCash ? enteredCash : total);
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Checkout gagal: $e'),
                                      backgroundColor:
                                          const Color(0xFFB42318),
                                    ),
                                  );
                                }
                              }
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF18794E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Selesaikan Pembayaran',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    cashController.dispose();
    if (checkoutSuccess == true) {
      setState(() => _cartItems.clear());
      await _refreshProducts();
    }
  }

  void _showReceiptDialog(CheckoutResult result, int paidAmount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.check_circle_rounded, color: Color(0xFF18794E), size: 28),
            SizedBox(width: 8),
            Text('Transaksi Berhasil!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No. Faktur: ${result.invoiceNo}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total:'),
                Text(
                  _rupiahFormat.format(result.total),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Dibayar:'),
                Text(_rupiahFormat.format(paidAmount)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Kembalian:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  _rupiahFormat.format(result.change),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF18794E),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006EAE),
              foregroundColor: Colors.white,
            ),
            child: const Text('Transaksi Baru'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authNotifierProvider);
    final isShiftOpen = _activeShiftId != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Kembali ke Dashboard',
          onPressed: () => context.go('/'),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kasir POS',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Kasir: ${authState.fullName ?? "Kasir"} (${authState.role ?? "CASHIER"})',
              style: const TextStyle(fontSize: 12, color: Color(0xFF586575)),
            ),
          ],
        ),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: isShiftOpen
                  ? const Color(0xFF18794E).withValues(alpha: 0.1)
                  : const Color(0xFF9A6700).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isShiftOpen
                    ? const Color(0xFF18794E)
                    : const Color(0xFF9A6700),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isShiftOpen ? Icons.fiber_manual_record : Icons.lock_clock,
                  size: 12,
                  color: isShiftOpen
                      ? const Color(0xFF18794E)
                      : const Color(0xFF9A6700),
                ),
                const SizedBox(width: 6),
                Text(
                  isShiftOpen ? 'Shift Aktif' : 'Shift Tertutup',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isShiftOpen
                        ? const Color(0xFF18794E)
                        : const Color(0xFF9A6700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!isShiftOpen)
            IconButton(
              icon: const Icon(Icons.lock_open),
              tooltip: 'Buka Shift',
              onPressed: _handleOpenShift,
            )
          else
            IconButton(
              icon: const Icon(Icons.lock_outline),
              tooltip: 'Tutup Shift',
              onPressed: _handleCloseShift,
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Keluar',
            onPressed: () async {
              await ref.read(authNotifierProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 720;

          if (isWide) {
            return Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _buildProductCatalog(theme),
                ),
                const VerticalDivider(width: 1, color: Color(0xFFD7DEE5)),
                Expanded(
                  flex: 2,
                  child: _buildCartSection(theme),
                ),
              ],
            );
          }

          // Compact layout
          return Column(
            children: [
              Expanded(child: _buildProductCatalog(theme)),
              _buildCompactCartBar(theme),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProductCatalog(ThemeData theme) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari nama, SKU, atau scan barcode...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                        _refreshProducts();
                      },
                    )
                  : null,
            ),
            onChanged: (val) {
              setState(() => _searchQuery = val);
              _refreshProducts();
            },
          ),
        ),
        Expanded(
          child: _isLoadingProducts
              ? const Center(child: CircularProgressIndicator())
              : _products.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 64,
                            color: Color(0xFFD7DEE5),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Tidak ada produk ditemukan',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF586575),
                            ),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 220,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.95,
                      ),
                      itemCount: _products.length,
                      itemBuilder: (context, index) {
                        final product = _products[index];
                        final name = product.read<String>('name');
                        final sku = product.read<String>('sku');
                        final price = product.read<int>('selling_price');
                        final stock = product.read<int>('stock_qty');

                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Color(0xFFD7DEE5)),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _addToCart(product),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: stock > 0
                                              ? const Color(0xFF18794E)
                                                  .withValues(alpha: 0.1)
                                              : const Color(0xFFB42318)
                                                  .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          stock > 0
                                              ? 'Stok: $stock'
                                              : 'Habis',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: stock > 0
                                                ? const Color(0xFF18794E)
                                                : const Color(0xFFB42318),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  Text(
                                    name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Color(0xFF17212B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    sku,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF586575),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _rupiahFormat.format(price),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Color(0xFF006EAE),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildCartSection(ThemeData theme) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFD7DEE5))),
            ),
            child: Row(
              children: [
                const Icon(Icons.shopping_cart_outlined,
                    color: Color(0xFF006EAE)),
                const SizedBox(width: 8),
                Text(
                  'Keranjang (${_cartItems.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_cartItems.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => setState(() => _cartItems.clear()),
                    icon: const Icon(Icons.delete_sweep_outlined,
                        size: 16, color: Color(0xFFB42318)),
                    label: const Text(
                      'Kosongkan',
                      style: TextStyle(color: Color(0xFFB42318), fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _cartItems.isEmpty
                ? const Center(
                    child: Text(
                      'Pilih produk untuk menambah ke keranjang',
                      style: TextStyle(color: Color(0xFF586575), fontSize: 13),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _cartItems.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _cartItems[index];

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    _rupiahFormat.format(item.unitPrice),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF586575),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  iconSize: 22,
                                  color: const Color(0xFF586575),
                                  onPressed: () => _updateQuantity(
                                      index, item.quantity - 1),
                                ),
                                Text(
                                  '${item.quantity}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  iconSize: 22,
                                  color: const Color(0xFF006EAE),
                                  onPressed: () => _updateQuantity(
                                      index, item.quantity + 1),
                                ),
                              ],
                            ),
                            SizedBox(
                              width: 80,
                              child: Text(
                                _rupiahFormat.format(item.lineTotal),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF4F6F8),
              border: Border(top: BorderSide(color: Color(0xFFD7DEE5))),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Tagihan:',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF586575),
                      ),
                    ),
                    Text(
                      _rupiahFormat.format(_cartTotal),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF006EAE),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _cartItems.isNotEmpty ? _handleCheckout : null,
                    icon: const Icon(Icons.payment_rounded),
                    label: const Text(
                      'Bayar Sekarang',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF006EAE),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactCartBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFD7DEE5))),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_cartItems.length} Produk',
                style: const TextStyle(fontSize: 12, color: Color(0xFF586575)),
              ),
              Text(
                _rupiahFormat.format(_cartTotal),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF006EAE),
                ),
              ),
            ],
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _cartItems.isNotEmpty ? _handleCheckout : null,
            icon: const Icon(Icons.payment),
            label: const Text('Bayar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006EAE),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
