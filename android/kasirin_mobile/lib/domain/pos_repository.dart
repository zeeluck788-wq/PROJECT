import 'dart:math';

import 'package:drift/drift.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;

import '../data/local_database.dart';
import 'password_hasher.dart';

class CartItemInput {
  const CartItemInput({required this.productId, required this.quantity});

  final int productId;
  final int quantity;
}

class CheckoutResult {
  const CheckoutResult({
    required this.saleId,
    required this.invoiceNo,
    required this.total,
    required this.change,
    required this.wasExisting,
  });

  final int saleId;
  final String invoiceNo;
  final int total;
  final int change;
  final bool wasExisting;
}

class PosRepository {
  PosRepository(this.database, this.passwordHasher);

  final KasirinDatabase database;
  final PasswordHasher passwordHasher;

  Future<void> _statement(
    String sql,
    List<Variable<Object>> variables,
  ) => database.customStatement(
    sql,
    variables.map((variable) => variable.value).toList(),
  );

  Future<bool> setupRequired() async =>
      await database
          .customSelect('SELECT id FROM users LIMIT 1')
          .getSingleOrNull() ==
      null;

  Future<int> createOwner({
    required String username,
    required String fullName,
    required String password,
    String? storeName,
  }) async {
    final normalizedUsername = username.trim();
    final normalizedName = fullName.trim();
    if (normalizedUsername.isEmpty || normalizedUsername.length > 80) {
      throw StateError('Username wajib diisi dan maksimal 80 karakter.');
    }
    if (normalizedName.isEmpty || normalizedName.length > 150) {
      throw StateError('Nama lengkap wajib diisi dan maksimal 150 karakter.');
    }
    if (password.length < 8) {
      throw StateError('Password minimal 8 karakter.');
    }
    final normalizedStoreName = storeName?.trim();
    if (normalizedStoreName != null &&
        (normalizedStoreName.isEmpty || normalizedStoreName.length > 150)) {
      throw StateError('Nama toko wajib diisi dan maksimal 150 karakter.');
    }
    final hash = await passwordHasher.hash(password);
    return database.transaction(() async {
      final existing = await database
          .customSelect('SELECT id FROM users LIMIT 1')
          .getSingleOrNull();
      if (existing != null) throw StateError('Akun OWNER sudah pernah dibuat.');
      final now = _now();
      for (final role in const ['OWNER', 'ADMIN', 'SUPERVISOR', 'CASHIER']) {
        await _statement(
          'INSERT OR IGNORE INTO roles(name, description, created_at, updated_at) VALUES (?, ?, ?, ?)',
          [
            Variable.withString(role),
            Variable.withString('Role $role'),
            Variable.withString(now),
            Variable.withString(now),
          ],
        );
      }
      final roleRow = await database
          .customSelect("SELECT id FROM roles WHERE name = 'OWNER'")
          .getSingle();
      try {
        await _statement(
          'INSERT INTO users(username, full_name, password_hash, role_id, is_active, failed_login_count, must_change_password, created_at, updated_at) VALUES (?, ?, ?, ?, 1, 0, 0, ?, ?)',
          [
            Variable.withString(normalizedUsername),
            Variable.withString(normalizedName),
            Variable.withString(hash),
            Variable.withInt(roleRow.read<int>('id')),
            Variable.withString(now),
            Variable.withString(now),
          ],
        );
      } on SqliteException catch (error) {
        throw StateError(
          error.message.contains('UNIQUE')
              ? 'Username sudah digunakan.'
              : 'Akun OWNER tidak dapat dibuat.',
        );
      }
      if (normalizedStoreName != null) {
        await _statement(
          'INSERT INTO stores(code, name, created_at, updated_at) VALUES (?, ?, ?, ?)',
          [
            Variable.withString('MAIN'),
            Variable.withString(normalizedStoreName),
            Variable.withString(now),
            Variable.withString(now),
          ],
        );
      }
      final user = await database
          .customSelect(
            'SELECT id FROM users WHERE username = ?',
            variables: [Variable.withString(normalizedUsername)],
          )
          .getSingle();
      return user.read<int>('id');
    });
  }

  Future<QueryRow> login(String username, String password) async {
    final normalizedUsername = username.trim();
    final row = await database
        .customSelect(
          '''SELECT users.*, roles.name AS role_name
         FROM users JOIN roles ON roles.id = users.role_id
         WHERE users.username = ? AND users.deleted_at IS NULL''',
          variables: [Variable.withString(normalizedUsername)],
        )
        .getSingleOrNull();
    if (row == null || row.read<int>('is_active') != 1) {
      throw StateError('Username atau password salah.');
    }
    final lockedUntil = DateTime.tryParse(
      row.read<String?>('locked_until') ?? '',
    );
    if (lockedUntil != null && lockedUntil.isAfter(DateTime.now().toUtc())) {
      throw StateError('Akun sedang terkunci.');
    }
    final valid = await passwordHasher.verify(
      password,
      row.read<String>('password_hash'),
    );
    final now = _now();
    if (!valid) {
      final attempts = row.read<int>('failed_login_count') + 1;
      final lock = attempts >= 5
          ? DateTime.now()
                .toUtc()
                .add(const Duration(minutes: 15))
                .toIso8601String()
          : null;
      await _statement(
        'UPDATE users SET failed_login_count = ?, locked_until = ?, updated_at = ? WHERE id = ?',
        [
          Variable.withInt(attempts),
          Variable<String>(lock),
          Variable.withString(now),
          Variable.withInt(row.read<int>('id')),
        ],
      );
      throw StateError('Username atau password salah.');
    }
    await database.transaction(() async {
      await _statement(
        'UPDATE users SET failed_login_count = 0, locked_until = NULL, last_login_at = ?, updated_at = ? WHERE id = ?',
        [
          Variable.withString(now),
          Variable.withString(now),
          Variable.withInt(row.read<int>('id')),
        ],
      );
      await _statement(
        'INSERT INTO login_history(user_id, login_at) VALUES (?, ?)',
        [Variable.withInt(row.read<int>('id')), Variable.withString(now)],
      );
    });
    return row;
  }

  Future<int> createStore(String name) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty || normalizedName.length > 150) {
      throw StateError('Nama toko wajib diisi dan maksimal 150 karakter.');
    }
    final now = _now();
    await _statement(
      'INSERT INTO stores(code, name, created_at, updated_at) VALUES (?, ?, ?, ?)',
      [
        Variable.withString('MAIN'),
        Variable.withString(normalizedName),
        Variable.withString(now),
        Variable.withString(now),
      ],
    );
    return (await database
            .customSelect('SELECT last_insert_rowid() AS id')
            .getSingle())
        .read<int>('id');
  }

  Future<QueryRow?> openShiftFor(int cashierId) async => database
      .customSelect(
        "SELECT * FROM shifts WHERE cashier_id = ? AND status = 'OPEN' AND closed_at IS NULL ORDER BY id DESC LIMIT 1",
        variables: [Variable.withInt(cashierId)],
      )
      .getSingleOrNull();

  Future<int> unitPriceFor(int productId, int quantity) async {
    if (quantity <= 0) throw StateError('Qty harus lebih dari 0.');
    final product = await database
        .customSelect(
          'SELECT selling_price FROM products WHERE id = ? AND deleted_at IS NULL AND is_active = 1',
          variables: [Variable.withInt(productId)],
        )
        .getSingleOrNull();
    if (product == null) throw StateError('Produk tidak ditemukan.');
    return _unitPrice(product.read<int>('selling_price'), productId, quantity);
  }

  Future<List<QueryRow>> products({String search = ''}) => database
      .customSelect(
        '''SELECT products.*, categories.name AS category_name
           FROM products LEFT JOIN categories ON categories.id = products.category_id
           WHERE products.deleted_at IS NULL AND products.is_active = 1
             AND (? = '' OR products.name LIKE ? OR products.sku LIKE ? OR products.barcode LIKE ?)
           ORDER BY products.name, products.sku''',
        variables: [
          Variable.withString(search.trim()),
          Variable.withString('%${search.trim()}%'),
          Variable.withString('%${search.trim()}%'),
          Variable.withString('%${search.trim()}%'),
        ],
      )
      .get();

  Future<int> createProduct({
    required String sku,
    required String name,
    required int purchasePrice,
    required int sellingPrice,
    required int initialStock,
    required int minimumStock,
    String? barcode,
  }) async {
    if (sku.trim().isEmpty || sku.trim().length > 80) {
      throw StateError('SKU wajib diisi dan maksimal 80 karakter.');
    }
    if (name.trim().isEmpty || name.trim().length > 200) {
      throw StateError('Nama produk wajib diisi dan maksimal 200 karakter.');
    }
    if ([
      purchasePrice,
      sellingPrice,
      initialStock,
      minimumStock,
    ].any((value) => value < 0)) {
      throw StateError('Harga dan stok tidak boleh bernilai negatif.');
    }
    final now = _now();
    return database.transaction(() async {
      final result = await database
          .customSelect(
            "SELECT id FROM categories WHERE lower(name) = 'umum' AND deleted_at IS NULL",
          )
          .getSingleOrNull();
      var categoryId = result?.read<int>('id');
      if (categoryId == null) {
        await _statement(
          'INSERT INTO categories(name, created_at, updated_at) VALUES (?, ?, ?)',
          [
            Variable.withString('Umum'),
            Variable.withString(now),
            Variable.withString(now),
          ],
        );
        categoryId =
            (await database
                    .customSelect('SELECT last_insert_rowid() AS id')
                    .getSingle())
                .read<int>('id');
      }
      await _statement(
        '''INSERT INTO products(sku, barcode, name, category_id, purchase_price, selling_price, stock_qty, min_stock, is_active, created_at, updated_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?)''',
        [
          Variable.withString(sku.trim()),
          Variable<String>(
            barcode?.trim().isEmpty ?? true ? null : barcode!.trim(),
          ),
          Variable.withString(name.trim()),
          Variable.withInt(categoryId),
          Variable.withInt(purchasePrice),
          Variable.withInt(sellingPrice),
          Variable.withInt(initialStock),
          Variable.withInt(minimumStock),
          Variable.withString(now),
          Variable.withString(now),
        ],
      );
      final productId =
          (await database
                  .customSelect('SELECT last_insert_rowid() AS id')
                  .getSingle())
              .read<int>('id');
      if (initialStock > 0) {
        await _statement(
          '''INSERT INTO stock_movements(product_id, movement_type, stock_before, qty, stock_after, reference_type, reference_id, note, created_at, updated_at)
             VALUES (?, 'INITIAL_STOCK', 0, ?, ?, 'PRODUCT', ?, 'Stok awal saat membuat produk.', ?, ?)''',
          [
            Variable.withInt(productId),
            Variable.withInt(initialStock),
            Variable.withInt(initialStock),
            Variable.withInt(productId),
            Variable.withString(now),
            Variable.withString(now),
          ],
        );
      }
      return productId;
    });
  }

  Future<List<QueryRow>> getSpecialPriceRules() => database.customSelect(
    '''SELECT bulk_price_rules.*, products.name AS product_name,
              products.sku AS product_sku, products.selling_price AS regular_price
       FROM bulk_price_rules
       JOIN products ON products.id = bulk_price_rules.product_id
       WHERE products.deleted_at IS NULL AND products.is_active = 1
         AND bulk_price_rules.pricing_mode = 'PRICE'
       ORDER BY products.name, bulk_price_rules.quantity_threshold''',
  ).get();

  Future<void> saveSpecialPriceRule({
    int? ruleId,
    required int productId,
    required int quantityThreshold,
    required int specialPrice,
  }) async {
    if (quantityThreshold < 1) {
      throw StateError('Jumlah minimum harus minimal 1.');
    }
    if (specialPrice <= 0) {
      throw StateError('Harga spesial harus lebih dari 0.');
    }

    final product = await database.customSelect(
      'SELECT selling_price FROM products WHERE id = ? AND deleted_at IS NULL AND is_active = 1',
      variables: [Variable.withInt(productId)],
    ).getSingleOrNull();
    if (product == null) throw StateError('Produk tidak ditemukan.');
    if (specialPrice > product.read<int>('selling_price')) {
      throw StateError('Harga spesial tidak boleh melebihi harga normal.');
    }

    final now = _now();
    try {
      if (ruleId == null) {
        await _statement(
          '''INSERT INTO bulk_price_rules(
               product_id, quantity_threshold, discount_percent, special_price,
               pricing_mode, created_at, updated_at
             ) VALUES (?, ?, 1, ?, 'PRICE', ?, ?)''',
          [
            Variable.withInt(productId),
            Variable.withInt(quantityThreshold),
            Variable.withInt(specialPrice),
            Variable.withString(now),
            Variable.withString(now),
          ],
        );
      } else {
        await _statement(
          '''UPDATE bulk_price_rules
             SET product_id = ?, quantity_threshold = ?, special_price = ?,
                 pricing_mode = 'PRICE', updated_at = ?
             WHERE id = ?''',
          [
            Variable.withInt(productId),
            Variable.withInt(quantityThreshold),
            Variable.withInt(specialPrice),
            Variable.withString(now),
            Variable.withInt(ruleId),
          ],
        );
      }
    } on SqliteException catch (error) {
      if (error.message.contains('UNIQUE')) {
        throw StateError('Produk ini sudah memiliki aturan pada jumlah tersebut.');
      }
      rethrow;
    }
  }

  Future<void> deleteSpecialPriceRule(int ruleId) => _statement(
    'DELETE FROM bulk_price_rules WHERE id = ?',
    [Variable.withInt(ruleId)],
  );

  Future<List<QueryRow>> getSuppliers() => database.customSelect(
    'SELECT * FROM suppliers WHERE deleted_at IS NULL ORDER BY name',
  ).get();

  Future<int> createSupplier({
    required String name,
    String? phone,
    String? address,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) throw StateError('Nama supplier wajib diisi.');
    final now = _now();
    final code = 'SUP-${DateTime.now().toUtc().microsecondsSinceEpoch}';
    await _statement(
      '''INSERT INTO suppliers(code, name, phone, address, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?)''',
      [
        Variable.withString(code),
        Variable.withString(normalizedName),
        Variable<String>(phone?.trim().isEmpty ?? true ? null : phone!.trim()),
        Variable<String>(address?.trim().isEmpty ?? true ? null : address!.trim()),
        Variable.withString(now),
        Variable.withString(now),
      ],
    );
    return (await database
            .customSelect('SELECT last_insert_rowid() AS id')
            .getSingle())
        .read<int>('id');
  }

  Future<List<QueryRow>> getPurchaseOrders() => database.customSelect(
    '''SELECT purchase_orders.*, suppliers.name AS supplier_name,
              suppliers.phone AS supplier_phone, users.full_name AS creator_name,
              (SELECT group_concat(products.name || ' × ' || purchase_order_items.ordered_qty, ', ')
                 FROM purchase_order_items
                 JOIN products ON products.id = purchase_order_items.product_id
                WHERE purchase_order_items.purchase_order_id = purchase_orders.id) AS item_summary
       FROM purchase_orders
       JOIN suppliers ON suppliers.id = purchase_orders.supplier_id
       JOIN users ON users.id = purchase_orders.created_by
       ORDER BY purchase_orders.id DESC''',
  ).get();

  Future<void> _postJournalPair({
    required String now,
    required String sourceType,
    required int sourceId,
    required String memo,
    required int actorId,
    required int debitAccountId,
    required int creditAccountId,
    required int amount,
    required String debitDescription,
    required String creditDescription,
  }) async {
    if (amount <= 0) return;
    await _statement(
      '''INSERT INTO journal_entries(
           entry_date, source_type, source_id, memo, posted_by, created_at, updated_at
         ) VALUES (?, ?, ?, ?, ?, ?, ?)''',
      [
        Variable.withString(now.substring(0, 10)),
        Variable.withString(sourceType),
        Variable.withInt(sourceId),
        Variable.withString(memo),
        Variable.withInt(actorId),
        Variable.withString(now),
        Variable.withString(now),
      ],
    );
    final journalId = (await database
            .customSelect('SELECT last_insert_rowid() AS id')
            .getSingle())
        .read<int>('id');
    for (final line in [
      (accountId: debitAccountId, debit: amount, credit: 0, description: debitDescription),
      (accountId: creditAccountId, debit: 0, credit: amount, description: creditDescription),
    ]) {
      await _statement(
        '''INSERT INTO journal_lines(
             journal_entry_id, account_id, debit, credit, description, created_at, updated_at
           ) VALUES (?, ?, ?, ?, ?, ?, ?)''',
        [
          Variable.withInt(journalId),
          Variable.withInt(line.accountId),
          Variable.withInt(line.debit),
          Variable.withInt(line.credit),
          Variable.withString(line.description),
          Variable.withString(now),
          Variable.withString(now),
        ],
      );
    }
  }

  Future<int> createPurchaseOrder({
    required int supplierId,
    required int productId,
    required int quantity,
    required int unitCost,
    required int actorId,
    required String dueDate,
    String? notes,
  }) async {
    if (quantity < 1) throw StateError('Jumlah pembelian minimal 1.');
    if (unitCost <= 0) throw StateError('Harga modal harus lebih dari 0.');
    final store = await getStore();
    if (store == null) throw StateError('Lengkapi profil toko terlebih dahulu.');
    final supplier = await database.customSelect(
      'SELECT id FROM suppliers WHERE id = ? AND deleted_at IS NULL',
      variables: [Variable.withInt(supplierId)],
    ).getSingleOrNull();
    if (supplier == null) throw StateError('Supplier tidak ditemukan.');
    final product = await database.customSelect(
      'SELECT id FROM products WHERE id = ? AND deleted_at IS NULL AND is_active = 1',
      variables: [Variable.withInt(productId)],
    ).getSingleOrNull();
    if (product == null) throw StateError('Produk tidak ditemukan.');

    final now = _now();
    final total = quantity * unitCost;
    final orderNo = 'PO-${DateTime.now().toUtc().microsecondsSinceEpoch}';
    return database.transaction(() async {
      await _statement(
        '''INSERT INTO purchase_orders(
             order_no, supplier_id, store_id, created_by, status, ordered_at,
             expected_at, subtotal, payment_status, due_date, paid_amount,
             notes, created_at, updated_at
           ) VALUES (?, ?, ?, ?, 'DRAFT', ?, ?, ?, 'TEMPO', ?, 0, ?, ?, ?)''',
        [
          Variable.withString(orderNo),
          Variable.withInt(supplierId),
          Variable.withInt(store.read<int>('id')),
          Variable.withInt(actorId),
          Variable.withString(now),
          Variable.withString(dueDate),
          Variable.withInt(total),
          Variable.withString(dueDate),
          Variable<String>(notes?.trim().isEmpty ?? true ? null : notes!.trim()),
          Variable.withString(now),
          Variable.withString(now),
        ],
      );
      final orderId = (await database
              .customSelect('SELECT last_insert_rowid() AS id')
              .getSingle())
          .read<int>('id');
      await _statement(
        '''INSERT INTO purchase_order_items(
             purchase_order_id, product_id, ordered_qty, received_qty,
             unit_cost, created_at, updated_at
           ) VALUES (?, ?, ?, 0, ?, ?, ?)''',
        [
          Variable.withInt(orderId),
          Variable.withInt(productId),
          Variable.withInt(quantity),
          Variable.withInt(unitCost),
          Variable.withString(now),
          Variable.withString(now),
        ],
      );
      return orderId;
    });
  }

  Future<void> receivePurchaseOrder({
    required int orderId,
    required int actorId,
  }) async {
    await database.transaction(() async {
      final order = await database.customSelect(
        'SELECT status, subtotal FROM purchase_orders WHERE id = ?',
        variables: [Variable.withInt(orderId)],
      ).getSingleOrNull();
      if (order == null) throw StateError('Pesanan tidak ditemukan.');
      if (order.read<String>('status') != 'DRAFT') {
        throw StateError('Hanya pesanan draft yang dapat diterima.');
      }
      final items = await database.customSelect(
        '''SELECT purchase_order_items.*, products.stock_qty
           FROM purchase_order_items
           JOIN products ON products.id = purchase_order_items.product_id
           WHERE purchase_order_id = ?''',
        variables: [Variable.withInt(orderId)],
      ).get();
      if (items.isEmpty) throw StateError('Pesanan tidak memiliki produk.');

      final now = _now();
      await _ensureFinancialBaseline(actorId, now);
      for (final item in items) {
        final productId = item.read<int>('product_id');
        final qty = item.read<int>('ordered_qty');
        final before = item.read<int>('stock_qty');
        final after = before + qty;
        await _statement(
          '''UPDATE products SET stock_qty = ?, purchase_price = ?, updated_at = ?
             WHERE id = ?''',
          [
            Variable.withInt(after),
            Variable.withInt(item.read<int>('unit_cost')),
            Variable.withString(now),
            Variable.withInt(productId),
          ],
        );
        await _statement(
          '''UPDATE purchase_order_items SET received_qty = ordered_qty, updated_at = ?
             WHERE id = ?''',
          [Variable.withString(now), Variable.withInt(item.read<int>('id'))],
        );
        await _statement(
          '''INSERT INTO stock_movements(
               product_id, movement_type, stock_before, qty, stock_after,
               reference_type, reference_id, note, created_at, updated_at
             ) VALUES (?, 'PURCHASE', ?, ?, ?, 'PURCHASE_ORDER', ?, ?, ?, ?)''',
          [
            Variable.withInt(productId),
            Variable.withInt(before),
            Variable.withInt(qty),
            Variable.withInt(after),
            Variable.withInt(orderId),
            Variable.withString('Penerimaan pesanan pembelian.'),
            Variable.withString(now),
            Variable.withString(now),
          ],
        );
      }
      await _statement(
        "UPDATE purchase_orders SET status = 'RECEIVED', updated_at = ? WHERE id = ?",
        [Variable.withString(now), Variable.withInt(orderId)],
      );
      await _postJournalPair(
        now: now,
        sourceType: 'PURCHASE',
        sourceId: orderId,
        memo: 'Penerimaan pesanan pembelian $orderId',
        actorId: actorId,
        debitAccountId: await _accountId('1200'),
        creditAccountId: await _accountId('2000'),
        amount: order.read<int>('subtotal'),
        debitDescription: 'Penambahan persediaan',
        creditDescription: 'Hutang supplier',
      );
      await _statement(
        '''INSERT INTO audit_logs(user_id, action, entity_type, entity_id, detail, created_at, updated_at)
           VALUES (?, 'PURCHASE_RECEIVED', 'PurchaseOrder', ?, 'Stok diterima', ?, ?)''',
        [
          Variable.withInt(actorId),
          Variable.withInt(orderId),
          Variable.withString(now),
          Variable.withString(now),
        ],
      );
    });
  }

  Future<int> payPurchaseOrder({
    required int orderId,
    required int amount,
    required int actorId,
  }) async {
    if (amount <= 0) throw StateError('Nominal pembayaran harus lebih dari 0.');
    final now = _now();
    return database.transaction(() async {
      final order = await database.customSelect(
        'SELECT status, subtotal, paid_amount FROM purchase_orders WHERE id = ?',
        variables: [Variable.withInt(orderId)],
      ).getSingleOrNull();
      if (order == null) throw StateError('Pesanan tidak ditemukan.');
      if (order.read<String>('status') != 'RECEIVED') {
        throw StateError('Terima barang sebelum mencatat pembayaran supplier.');
      }
      final subtotal = order.read<int>('subtotal');
      final paid = order.read<int>('paid_amount');
      final newPaid = paid + amount;
      if (newPaid > subtotal) throw StateError('Pembayaran melebihi sisa tagihan.');

      await _ensureFinancialBaseline(actorId, now);
      final cashAccountId = await _accountId('1000');
      await _statement(
        '''INSERT INTO financial_payments(
             purchase_order_id, expense_id, account_id, amount, payment_method,
             paid_at, created_by, created_at, updated_at
           ) VALUES (?, NULL, ?, ?, 'CASH', ?, ?, ?, ?)''',
        [
          Variable.withInt(orderId),
          Variable.withInt(cashAccountId),
          Variable.withInt(amount),
          Variable.withString(now),
          Variable.withInt(actorId),
          Variable.withString(now),
          Variable.withString(now),
        ],
      );
      final paymentId = (await database
              .customSelect('SELECT last_insert_rowid() AS id')
              .getSingle())
          .read<int>('id');
      await _postJournalPair(
        now: now,
        sourceType: 'PURCHASE_PAYMENT',
        sourceId: paymentId,
        memo: 'Pembayaran pesanan pembelian $orderId',
        actorId: actorId,
        debitAccountId: await _accountId('2000'),
        creditAccountId: cashAccountId,
        amount: amount,
        debitDescription: 'Pembayaran hutang supplier',
        creditDescription: 'Pengeluaran kas',
      );
      final status = newPaid == subtotal ? 'PAID' : 'DP';
      await _statement(
        'UPDATE purchase_orders SET paid_amount = ?, payment_status = ?, updated_at = ? WHERE id = ?',
        [
          Variable.withInt(newPaid),
          Variable.withString(status),
          Variable.withString(now),
          Variable.withInt(orderId),
        ],
      );
      return subtotal - newPaid;
    });
  }

  Future<List<QueryRow>> getStockReport() => database.customSelect(
    '''SELECT id, sku, name, stock_qty, min_stock, purchase_price, selling_price
       FROM products WHERE deleted_at IS NULL AND is_active = 1
       ORDER BY CASE WHEN stock_qty <= min_stock THEN 0 ELSE 1 END, name''',
  ).get();

  Future<List<QueryRow>> getShiftHistory({int limit = 30}) => database.customSelect(
    '''SELECT shifts.*, users.full_name AS cashier_name,
              COALESCE(SUM(CASE WHEN sales.status = 'PAID' THEN sales.grand_total ELSE 0 END), 0) AS sales_total,
              COUNT(CASE WHEN sales.status = 'PAID' THEN sales.id END) AS sales_count
       FROM shifts
       JOIN users ON users.id = shifts.cashier_id
       LEFT JOIN sales ON sales.shift_id = shifts.id
       GROUP BY shifts.id
       ORDER BY shifts.id DESC LIMIT ?''',
    variables: [Variable.withInt(limit)],
  ).get();

  Future<Map<String, bool>> getPaymentSettings() async {
    final row = await database
        .customSelect('SELECT * FROM payment_settings ORDER BY id LIMIT 1')
        .getSingleOrNull();
    return {
      'cash': row?.read<int>('cash_enabled') != 0,
      'qrisDana': row?.read<int>('qris_dana_enabled') == 1,
      'qrisMidtrans': row?.read<int>('qris_midtrans_enabled') == 1,
      'transfer': row?.read<int>('transfer_enabled') == 1,
    };
  }

  Future<void> savePaymentSettings(Map<String, bool> settings) async {
    if (settings.values.every((enabled) => !enabled)) {
      throw StateError('Aktifkan minimal satu metode pembayaran.');
    }
    final now = _now();
    final row = await database
        .customSelect('SELECT id FROM payment_settings ORDER BY id LIMIT 1')
        .getSingleOrNull();
    final values = [
      Variable.withInt(settings['cash'] == true ? 1 : 0),
      Variable.withInt(settings['qrisDana'] == true ? 1 : 0),
      Variable.withInt(settings['qrisMidtrans'] == true ? 1 : 0),
      Variable.withInt(settings['transfer'] == true ? 1 : 0),
    ];
    if (row == null) {
      await _statement(
        '''INSERT INTO payment_settings(
             cash_enabled, qris_dana_enabled, qris_midtrans_enabled,
             transfer_enabled, created_at, updated_at
           ) VALUES (?, ?, ?, ?, ?, ?)''',
        [...values, Variable.withString(now), Variable.withString(now)],
      );
    } else {
      await _statement(
        '''UPDATE payment_settings SET cash_enabled = ?, qris_dana_enabled = ?,
             qris_midtrans_enabled = ?, transfer_enabled = ?, updated_at = ? WHERE id = ?''',
        [...values, Variable.withString(now), Variable.withInt(row.read<int>('id'))],
      );
    }
  }

  Future<int?> openShift({
    required int cashierId,
    required int openingCash,
  }) async {
    if (openingCash < 0) throw StateError('Modal awal tidak boleh negatif.');
    final existing = await database
        .customSelect(
          "SELECT id FROM shifts WHERE cashier_id = ? AND status = 'OPEN' AND closed_at IS NULL",
          variables: [Variable.withInt(cashierId)],
        )
        .getSingleOrNull();
    if (existing != null) return existing.read<int>('id');
    final store = await database
        .customSelect(
          'SELECT id FROM stores WHERE deleted_at IS NULL ORDER BY id LIMIT 1',
        )
        .getSingleOrNull();
    if (store == null) throw StateError('Data toko belum tersedia.');
    final now = _now();
    await _statement(
      '''INSERT INTO shifts(store_id, cashier_id, opened_at, opening_cash, status, created_at, updated_at)
         VALUES (?, ?, ?, ?, 'OPEN', ?, ?)''',
      [
        Variable.withInt(store.read<int>('id')),
        Variable.withInt(cashierId),
        Variable.withString(now),
        Variable.withInt(openingCash),
        Variable.withString(now),
        Variable.withString(now),
      ],
    );
    return (await database
            .customSelect('SELECT last_insert_rowid() AS id')
            .getSingle())
        .read<int>('id');
  }

  Future<CheckoutResult> checkout({
    required String invoiceNo,
    required int cashierId,
    required int shiftId,
    required List<CartItemInput> items,
    required String paymentMethod,
    required int paymentAmount,
  }) async {
    if (items.isEmpty) throw StateError('Keranjang penjualan masih kosong.');
    if (paymentAmount < 0) throw StateError('Nominal pembayaran tidak valid.');
    return database.transaction(() async {
      final prior = await database
          .customSelect(
            'SELECT id, grand_total FROM sales WHERE invoice_no = ?',
            variables: [Variable.withString(invoiceNo)],
          )
          .getSingleOrNull();
      if (prior != null) {
        final total = prior.read<int>('grand_total');
        return CheckoutResult(
          saleId: prior.read<int>('id'),
          invoiceNo: invoiceNo,
          total: total,
          change: max(0, paymentAmount - total),
          wasExisting: true,
        );
      }
      final shift = await database
          .customSelect(
            "SELECT store_id FROM shifts WHERE id = ? AND cashier_id = ? AND status = 'OPEN' AND closed_at IS NULL",
            variables: [Variable.withInt(shiftId), Variable.withInt(cashierId)],
          )
          .getSingleOrNull();
      if (shift == null) {
        throw StateError('Buka shift sebelum menyelesaikan penjualan.');
      }

      final now = _now();
      final entries =
          <({QueryRow product, int quantity, int unitPrice, int lineTotal})>[];
      var total = 0;
      for (final item in items) {
        if (item.quantity <= 0) throw StateError('Qty harus lebih dari 0.');
        final product = await database
            .customSelect(
              'SELECT * FROM products WHERE id = ? AND deleted_at IS NULL AND is_active = 1',
              variables: [Variable.withInt(item.productId)],
            )
            .getSingleOrNull();
        if (product == null) throw StateError('Produk tidak ditemukan.');
        final stock = product.read<int>('stock_qty');
        if (stock < item.quantity) {
          throw StateError(
            'Stok ${product.read<String>('name')} tidak mencukupi.',
          );
        }
        final unitPrice = await _unitPrice(
          product.read<int>('selling_price'),
          item.productId,
          item.quantity,
        );
        final lineTotal = item.quantity * unitPrice;
        total += lineTotal;
        entries.add((
          product: product,
          quantity: item.quantity,
          unitPrice: unitPrice,
          lineTotal: lineTotal,
        ));
      }
      if (paymentAmount < total) throw StateError('Pembayaran belum lunas.');

      await _ensureFinancialBaseline(cashierId, now);
      await _statement(
        '''INSERT INTO sales(invoice_no, store_id, shift_id, cashier_id, subtotal, discount, tax, grand_total, status, created_at, updated_at)
           VALUES (?, ?, ?, ?, ?, 0, 0, ?, 'PAID', ?, ?)''',
        [
          Variable.withString(invoiceNo),
          Variable.withInt(shift.read<int>('store_id')),
          Variable.withInt(shiftId),
          Variable.withInt(cashierId),
          Variable.withInt(total),
          Variable.withInt(total),
          Variable.withString(now),
          Variable.withString(now),
        ],
      );
      final saleId =
          (await database
                  .customSelect('SELECT last_insert_rowid() AS id')
                  .getSingle())
              .read<int>('id');
      final lines =
          <({int accountId, int debit, int credit, String description})>[];
      var remainingPayment = total;
      final accountCode = paymentMethod == 'CASH' ? '1000' : '1010';
      final paymentAccount = await _accountId(accountCode);
      lines.add((
        accountId: paymentAccount,
        debit: total,
        credit: 0,
        description: 'Penerimaan penjualan',
      ));
      final salesAccount = await _accountId('4000');
      lines.add((
        accountId: salesAccount,
        debit: 0,
        credit: total,
        description: 'Penjualan',
      ));
      var costTotal = 0;

      for (final entry in entries) {
        final product = entry.product;
        final productId = product.read<int>('id');
        final stockBefore = product.read<int>('stock_qty');
        final purchasePrice = product.read<int>('purchase_price');
        final int? unitCost = purchasePrice > 0 ? purchasePrice : null;
        final stockAfter = stockBefore - entry.quantity;
        final cost = (unitCost ?? 0) * entry.quantity;
        costTotal += cost;
        await _statement(
          '''INSERT INTO sale_items(sale_id, product_id, qty, unit_price, unit_cost, discount, line_total, created_at, updated_at)
             VALUES (?, ?, ?, ?, ?, 0, ?, ?, ?)''',
          [
            Variable.withInt(saleId),
            Variable.withInt(productId),
            Variable.withInt(entry.quantity),
            Variable.withInt(entry.unitPrice),
            Variable<int>(unitCost),
            Variable.withInt(entry.lineTotal),
            Variable.withString(now),
            Variable.withString(now),
          ],
        );
        await _statement(
          'UPDATE products SET stock_qty = ?, updated_at = ? WHERE id = ?',
          [
            Variable.withInt(stockAfter),
            Variable.withString(now),
            Variable.withInt(productId),
          ],
        );
        await _statement(
          '''INSERT INTO stock_movements(product_id, movement_type, stock_before, qty, stock_after, reference_type, reference_id, created_at, updated_at)
             VALUES (?, 'SALE', ?, ?, ?, 'SALE', ?, ?, ?)''',
          [
            Variable.withInt(productId),
            Variable.withInt(stockBefore),
            Variable.withInt(-entry.quantity),
            Variable.withInt(stockAfter),
            Variable.withInt(saleId),
            Variable.withString(now),
            Variable.withString(now),
          ],
        );
      }
      await _statement(
        'INSERT INTO payments(sale_id, method, amount, created_at, updated_at) VALUES (?, ?, ?, ?, ?)',
        [
          Variable.withInt(saleId),
          Variable.withString(paymentMethod),
          Variable.withInt(paymentAmount),
          Variable.withString(now),
          Variable.withString(now),
        ],
      );
      if (costTotal > 0) {
        final cogs = await _accountId('5000');
        final inventory = await _accountId('1200');
        lines.add((
          accountId: cogs,
          debit: costTotal,
          credit: 0,
          description: 'Harga pokok penjualan',
        ));
        lines.add((
          accountId: inventory,
          debit: 0,
          credit: costTotal,
          description: 'Pengurangan persediaan',
        ));
      }
      remainingPayment -= total;
      if (remainingPayment != 0) {
        throw StateError('Nilai pembayaran tidak menutup total penjualan.');
      }
      final debit = lines.fold<int>(0, (sum, line) => sum + line.debit);
      final credit = lines.fold<int>(0, (sum, line) => sum + line.credit);
      if (debit != credit) throw StateError('Jurnal penjualan tidak seimbang.');
      await _statement(
        '''INSERT INTO journal_entries(entry_date, source_type, source_id, memo, posted_by, created_at, updated_at)
           VALUES (?, 'SALE', ?, ?, ?, ?, ?)''',
        [
          Variable.withString(now.substring(0, 10)),
          Variable.withInt(saleId),
          Variable.withString('Penjualan $invoiceNo'),
          Variable.withInt(cashierId),
          Variable.withString(now),
          Variable.withString(now),
        ],
      );
      final journalId =
          (await database
                  .customSelect('SELECT last_insert_rowid() AS id')
                  .getSingle())
              .read<int>('id');
      for (final line in lines) {
        await _statement(
          '''INSERT INTO journal_lines(journal_entry_id, account_id, debit, credit, description, created_at, updated_at)
             VALUES (?, ?, ?, ?, ?, ?, ?)''',
          [
            Variable.withInt(journalId),
            Variable.withInt(line.accountId),
            Variable.withInt(line.debit),
            Variable.withInt(line.credit),
            Variable.withString(line.description),
            Variable.withString(now),
            Variable.withString(now),
          ],
        );
      }
      await _statement(
        '''INSERT INTO audit_logs(user_id, action, entity_type, entity_id, detail, created_at, updated_at)
           VALUES (?, 'SALE_COMPLETED', 'Sale', ?, ?, ?, ?)''',
        [
          Variable.withInt(cashierId),
          Variable.withInt(saleId),
          Variable.withString('Invoice $invoiceNo; total $total'),
          Variable.withString(now),
          Variable.withString(now),
        ],
      );
      return CheckoutResult(
        saleId: saleId,
        invoiceNo: invoiceNo,
        total: total,
        change: paymentAmount - total,
        wasExisting: false,
      );
    });
  }

  Future<void> _ensureFinancialBaseline(int actorId, String now) async {
    final settings = await database
        .customSelect(
          'SELECT effective_from FROM financial_settings WHERE id = 1',
        )
        .getSingleOrNull();
    if (settings?.read<String?>('effective_from') == null) {
      await _statement(
        '''INSERT OR REPLACE INTO financial_settings(id, effective_from, initialized_by, initialized_at, created_at, updated_at)
           VALUES (1, ?, ?, ?, ?, ?)''',
        [
          Variable.withString(now.substring(0, 10)),
          Variable.withInt(actorId),
          Variable.withString(now),
          Variable.withString(now),
          Variable.withString(now),
        ],
      );
    }
    const accounts = <(String, String, String)>[
      ('1000', 'Kas', 'ASSET'),
      ('1010', 'Bank', 'ASSET'),
      ('1200', 'Persediaan', 'ASSET'),
      ('2000', 'Hutang Usaha', 'LIABILITY'),
      ('3000', 'Modal Pemilik', 'EQUITY'),
      ('3100', 'Saldo Awal', 'EQUITY'),
      ('4000', 'Penjualan', 'REVENUE'),
      ('5000', 'Harga Pokok Penjualan', 'EXPENSE'),
    ];
    for (final account in accounts) {
      await _statement(
        '''INSERT OR IGNORE INTO accounts(code, name, account_type, is_active, is_system, created_at, updated_at)
           VALUES (?, ?, ?, 1, 1, ?, ?)''',
        [
          Variable.withString(account.$1),
          Variable.withString(account.$2),
          Variable.withString(account.$3),
          Variable.withString(now),
          Variable.withString(now),
        ],
      );
    }
  }

  Future<int> _accountId(String code) async =>
      (await database
              .customSelect(
                'SELECT id FROM accounts WHERE code = ?',
                variables: [Variable.withString(code)],
              )
              .getSingle())
          .read<int>('id');

  Future<int> _unitPrice(int basePrice, int productId, int quantity) async {
    final rules = await database
        .customSelect(
          '''SELECT quantity_threshold, discount_percent, special_price, pricing_mode
         FROM bulk_price_rules WHERE product_id = ? AND quantity_threshold <= ?
         ORDER BY quantity_threshold DESC LIMIT 1''',
          variables: [Variable.withInt(productId), Variable.withInt(quantity)],
        )
        .getSingleOrNull();
    if (rules == null) return basePrice;
    if (rules.read<String>('pricing_mode') == 'PRICE') {
      return rules.read<int>('special_price');
    }
    final percent = rules.read<num>('discount_percent');
    return (basePrice * (100 - percent) / 100).round();
  }

  static String _now() => DateTime.now().toUtc().toIso8601String();

  Future<void> closeShift({
    required int shiftId,
    required int cashierId,
    required int closingCash,
  }) async {
    if (closingCash < 0) throw StateError('Kas akhir tidak boleh negatif.');
    final now = _now();
    await _statement(
      '''UPDATE shifts SET status = 'CLOSED', closed_at = ?, closing_cash = ?, updated_at = ?
         WHERE id = ? AND cashier_id = ? AND status = 'OPEN' ''',
      [
        Variable.withString(now),
        Variable.withInt(closingCash),
        Variable.withString(now),
        Variable.withInt(shiftId),
        Variable.withInt(cashierId),
      ],
    );
  }

  Future<List<QueryRow>> getUsers() => database.customSelect(
    '''SELECT users.*, roles.name AS role_name
       FROM users JOIN roles ON roles.id = users.role_id
       WHERE users.deleted_at IS NULL ORDER BY users.id''',
  ).get();

  Future<int> addUser({
    required String username,
    required String fullName,
    required String password,
    required String role,
    String? whatsapp,
  }) async {
    final normalizedUsername = username.trim();
    final normalizedName = fullName.trim();
    if (normalizedUsername.isEmpty || normalizedUsername.length > 80) {
      throw StateError('Username wajib diisi dan maksimal 80 karakter.');
    }
    if (normalizedName.isEmpty || normalizedName.length > 150) {
      throw StateError('Nama lengkap wajib diisi dan maksimal 150 karakter.');
    }
    if (password.length < 6) {
      throw StateError('Password minimal 6 karakter.');
    }
    final roleRow = await database
        .customSelect("SELECT id FROM roles WHERE name = ?", variables: [Variable.withString(role)])
        .getSingleOrNull();
    if (roleRow == null) throw StateError('Role $role tidak valid.');
    final hash = await passwordHasher.hash(password);
    final now = _now();
    try {
      await _statement(
        '''INSERT INTO users(username, full_name, whatsapp, password_hash, role_id, is_active, failed_login_count, must_change_password, created_at, updated_at)
           VALUES (?, ?, ?, ?, ?, 1, 0, 0, ?, ?)''',
        [
          Variable.withString(normalizedUsername),
          Variable.withString(normalizedName),
          Variable<String>(whatsapp?.trim().isEmpty ?? true ? null : whatsapp!.trim()),
          Variable.withString(hash),
          Variable.withInt(roleRow.read<int>('id')),
          Variable.withString(now),
          Variable.withString(now),
        ],
      );
      final idRow = await database.customSelect('SELECT last_insert_rowid() AS id').getSingle();
      return idRow.read<int>('id');
    } on SqliteException catch (error) {
      throw StateError(
        error.message.contains('UNIQUE')
            ? 'Username sudah digunakan.'
            : 'Gagal menambahkan pengguna.',
      );
    }
  }

  Future<QueryRow?> getStore() => database.customSelect(
    'SELECT * FROM stores WHERE deleted_at IS NULL ORDER BY id LIMIT 1',
  ).getSingleOrNull();

  Future<void> updateStore({
    required String name,
    String? slogan,
    String? address,
    String? whatsapp,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) throw StateError('Nama toko wajib diisi.');
    final store = await getStore();
    final now = _now();
    if (store != null) {
      await _statement(
        '''UPDATE stores SET name = ?, slogan = ?, address = ?, whatsapp = ?, updated_at = ?
           WHERE id = ?''',
        [
          Variable.withString(normalizedName),
          Variable<String>(slogan?.trim().isEmpty ?? true ? null : slogan!.trim()),
          Variable<String>(address?.trim().isEmpty ?? true ? null : address!.trim()),
          Variable<String>(whatsapp?.trim().isEmpty ?? true ? null : whatsapp!.trim()),
          Variable.withString(now),
          Variable.withInt(store.read<int>('id')),
        ],
      );
    } else {
      await _statement(
        '''INSERT INTO stores(code, name, slogan, address, whatsapp, created_at, updated_at)
           VALUES ('MAIN', ?, ?, ?, ?, ?, ?)''',
        [
          Variable.withString(normalizedName),
          Variable<String>(slogan?.trim().isEmpty ?? true ? null : slogan!.trim()),
          Variable<String>(address?.trim().isEmpty ?? true ? null : address!.trim()),
          Variable<String>(whatsapp?.trim().isEmpty ?? true ? null : whatsapp!.trim()),
          Variable.withString(now),
          Variable.withString(now),
        ],
      );
    }
  }

  Future<Map<String, dynamic>> getDashboardStats() async {
    final productCountRow = await database.customSelect(
      'SELECT COUNT(*) AS c FROM products WHERE deleted_at IS NULL AND is_active = 1',
    ).getSingle();
    final productCount = productCountRow.read<int>('c');

    final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    final todaySalesRow = await database.customSelect(
      "SELECT COALESCE(SUM(grand_total), 0) AS total, COUNT(*) AS count FROM sales WHERE substr(created_at, 1, 10) = ? AND status = 'PAID'",
      variables: [Variable.withString(today)],
    ).getSingle();
    final todaySales = todaySalesRow.read<int>('total');
    final todayCount = todaySalesRow.read<int>('count');

    final activeShiftRow = await database.customSelect(
      "SELECT COUNT(*) AS c FROM shifts WHERE status = 'OPEN' AND closed_at IS NULL",
    ).getSingle();
    final activeShifts = activeShiftRow.read<int>('c');

    final lowStockRow = await database.customSelect(
      'SELECT COUNT(*) AS c FROM products WHERE deleted_at IS NULL AND is_active = 1 AND stock_qty <= min_stock',
    ).getSingle();
    final lowStockCount = lowStockRow.read<int>('c');

    return {
      'productCount': productCount,
      'todaySales': todaySales,
      'todayCount': todayCount,
      'activeShifts': activeShifts,
      'lowStockCount': lowStockCount,
    };
  }

  Future<List<QueryRow>> getRecentSales({int limit = 10}) => database.customSelect(
    '''SELECT sales.*, users.full_name AS cashier_name
       FROM sales LEFT JOIN users ON users.id = sales.cashier_id
       WHERE sales.status = 'PAID'
       ORDER BY sales.id DESC LIMIT ?''',
    variables: [Variable.withInt(limit)],
  ).get();

  Future<void> deleteProduct(int productId) async {
    final now = _now();
    await _statement(
      'UPDATE products SET deleted_at = ?, is_active = 0, updated_at = ? WHERE id = ?',
      [Variable.withString(now), Variable.withString(now), Variable.withInt(productId)],
    );
  }
}
