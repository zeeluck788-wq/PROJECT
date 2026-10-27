import 'package:flutter_test/flutter_test.dart';

import 'package:kasirin_mobile/data/local_database.dart';
import 'package:kasirin_mobile/domain/password_hasher.dart';
import 'package:kasirin_mobile/domain/pos_repository.dart';

class _TestPasswordHasher extends PasswordHasher {
  @override
  Future<String> hash(String password) async => 'test-hash:$password';

  @override
  Future<bool> verify(String password, String encoded) async =>
      encoded == 'test-hash:$password';
}

void main() {
  late KasirinDatabase database;
  late PosRepository repository;

  setUp(() async {
    database = KasirinDatabase.memory();
    await database.customSelect('SELECT 1').get();
    repository = PosRepository(database, _TestPasswordHasher());
  });

  tearDown(() async => database.close());

  test('fresh setup creates roles and owner without demo data', () async {
    expect(await repository.setupRequired(), isTrue);
    final ownerId = await repository.createOwner(
      username: '  pemilik  ',
      fullName: '  Pemilik Toko  ',
      password: 'password-rahasia',
    );

    expect(await repository.setupRequired(), isFalse);
    expect(
      (await database.customSelect('SELECT name FROM roles').get())
          .map((row) => row.read<String>('name'))
          .toSet(),
      {'OWNER', 'ADMIN', 'SUPERVISOR', 'CASHIER'},
    );
    expect(
      (await database.customSelect('SELECT id FROM products').get()),
      isEmpty,
    );
    expect(
      (await database.customSelect('SELECT id FROM stores').get()),
      isEmpty,
    );
    final owner = await repository.login('pemilik', 'password-rahasia');
    expect(owner.read<int>('id'), ownerId);
    expect(owner.read<String>('role_name'), 'OWNER');
    expect(
      (await database.customSelect('SELECT id FROM login_history').get()),
      hasLength(1),
    );
  });

  test('checkout persists payment, stock, journal, and audit once', () async {
    final ownerId = await repository.createOwner(
      username: 'owner',
      fullName: 'Owner',
      password: 'password-rahasia',
    );
    await repository.createStore('Toko Utama');
    final productId = await repository.createProduct(
      sku: 'SKU-001',
      name: 'Beras',
      purchasePrice: 100,
      sellingPrice: 200,
      initialStock: 10,
      minimumStock: 2,
    );
    final shiftId = await repository.openShift(
      cashierId: ownerId,
      openingCash: 50000,
    );

    final result = await repository.checkout(
      invoiceNo: 'POS-TEST-001',
      cashierId: ownerId,
      shiftId: shiftId!,
      items: [CartItemInput(productId: productId, quantity: 2)],
      paymentMethod: 'CASH',
      paymentAmount: 500,
    );

    expect(result.total, 400);
    expect(result.change, 100);
    expect(result.wasExisting, isFalse);
    final retry = await repository.checkout(
      invoiceNo: 'POS-TEST-001',
      cashierId: ownerId,
      shiftId: shiftId,
      items: [CartItemInput(productId: productId, quantity: 2)],
      paymentMethod: 'CASH',
      paymentAmount: 500,
    );
    expect(retry.wasExisting, isTrue);
    expect(
      (await database
              .customSelect('SELECT stock_qty FROM products')
              .getSingle())
          .read<int>('stock_qty'),
      8,
    );
    expect(
      (await database.customSelect('SELECT id FROM sales').get()),
      hasLength(1),
    );
    expect(
      (await database.customSelect('SELECT id FROM sale_items').get()),
      hasLength(1),
    );
    expect(
      (await database.customSelect('SELECT id FROM payments').get()),
      hasLength(1),
    );
    expect(
      (await database
          .customSelect(
            "SELECT id FROM stock_movements WHERE movement_type = 'SALE'",
          )
          .get()),
      hasLength(1),
    );
    expect(
      (await database.customSelect('SELECT id FROM journal_entries').get()),
      hasLength(1),
    );
    expect(
      (await database.customSelect('SELECT id FROM audit_logs').get()),
      hasLength(1),
    );
    final totals = await database
        .customSelect(
          'SELECT SUM(debit) AS debit, SUM(credit) AS credit FROM journal_lines',
        )
        .getSingle();
    expect(totals.read<int>('debit'), totals.read<int>('credit'));
  });

  test('failed checkout rolls back every write', () async {
    final ownerId = await repository.createOwner(
      username: 'owner',
      fullName: 'Owner',
      password: 'password-rahasia',
    );
    await repository.createStore('Toko Utama');
    final productId = await repository.createProduct(
      sku: 'SKU-002',
      name: 'Minyak',
      purchasePrice: 150,
      sellingPrice: 250,
      initialStock: 2,
      minimumStock: 1,
    );
    final shiftId = await repository.openShift(
      cashierId: ownerId,
      openingCash: 0,
    );

    await expectLater(
      repository.checkout(
        invoiceNo: 'POS-TEST-002',
        cashierId: ownerId,
        shiftId: shiftId!,
        items: [CartItemInput(productId: productId, quantity: 3)],
        paymentMethod: 'CASH',
        paymentAmount: 1000,
      ),
      throwsA(isA<StateError>()),
    );

    for (final table in [
      'sales',
      'sale_items',
      'payments',
      'journal_entries',
      'journal_lines',
      'audit_logs',
    ]) {
      expect(
        await database.customSelect('SELECT id FROM $table').get(),
        isEmpty,
        reason: '$table must roll back',
      );
    }
    expect(
      (await database
              .customSelect('SELECT stock_qty FROM products')
              .getSingle())
          .read<int>('stock_qty'),
      2,
    );
    expect(
      await database
          .customSelect(
            "SELECT id FROM stock_movements WHERE movement_type = 'SALE'",
          )
          .get(),
      isEmpty,
    );
  });

  test(
    'checkout accepts an unknown purchase cost without inventing COGS',
    () async {
      final ownerId = await repository.createOwner(
        username: 'owner',
        fullName: 'Owner',
        password: 'password-rahasia',
      );
      await repository.createStore('Toko Utama');
      final productId = await repository.createProduct(
        sku: 'SKU-NO-COST',
        name: 'Barang titipan',
        purchasePrice: 0,
        sellingPrice: 500,
        initialStock: 1,
        minimumStock: 0,
      );
      final shiftId = await repository.openShift(
        cashierId: ownerId,
        openingCash: 0,
      );

      final result = await repository.checkout(
        invoiceNo: 'POS-NO-COST',
        cashierId: ownerId,
        shiftId: shiftId!,
        items: [CartItemInput(productId: productId, quantity: 1)],
        paymentMethod: 'CASH',
        paymentAmount: 500,
      );

      expect(result.total, 500);
      expect(
        (await database
                .customSelect('SELECT unit_cost FROM sale_items')
                .getSingle())
            .read<int?>('unit_cost'),
        isNull,
      );
    },
  );

  test('checkout uses the highest eligible tier at commit time', () async {
    final ownerId = await repository.createOwner(
      username: 'owner',
      fullName: 'Owner',
      password: 'password-rahasia',
    );
    await repository.createStore('Toko Utama');
    final productId = await repository.createProduct(
      sku: 'SKU-003',
      name: 'Teh',
      purchasePrice: 50,
      sellingPrice: 100,
      initialStock: 20,
      minimumStock: 1,
    );
    final now = DateTime.now().toUtc().toIso8601String();
    await database.customStatement(
      '''INSERT INTO bulk_price_rules(product_id, quantity_threshold, discount_percent, special_price, pricing_mode, created_at, updated_at)
         VALUES (?, 5, 10, 90, 'PRICE', ?, ?)''',
      [productId, now, now],
    );
    final shiftId = await repository.openShift(
      cashierId: ownerId,
      openingCash: 0,
    );

    expect(await repository.unitPriceFor(productId, 4), 100);
    expect(await repository.unitPriceFor(productId, 5), 90);
    expect((await repository.openShiftFor(ownerId))?.read<int>('id'), shiftId);

    final result = await repository.checkout(
      invoiceNo: 'POS-TEST-003',
      cashierId: ownerId,
      shiftId: shiftId!,
      items: [CartItemInput(productId: productId, quantity: 5)],
      paymentMethod: 'CASH',
      paymentAmount: 450,
    );

    expect(result.total, 450);
    expect(
      (await database
              .customSelect('SELECT unit_price FROM sale_items')
              .getSingle())
          .read<int>('unit_price'),
      90,
    );
  });

  test('shift closing, user management, and dashboard stats work', () async {
    final ownerId = await repository.createOwner(
      username: 'owner2',
      fullName: 'Owner Two',
      password: 'password-rahasia',
    );
    await repository.createStore('Toko Dua');
    final shiftId = await repository.openShift(
      cashierId: ownerId,
      openingCash: 50000,
    );
    expect(shiftId, isNotNull);

    await repository.closeShift(
      shiftId: shiftId!,
      cashierId: ownerId,
      closingCash: 75000,
    );
    expect(await repository.openShiftFor(ownerId), isNull);

    final cashierId = await repository.addUser(
      username: 'kasir1',
      fullName: 'Kasir Satu',
      password: 'password-kasir',
      role: 'CASHIER',
    );
    expect(cashierId, isPositive);

    final users = await repository.getUsers();
    expect(users.length, 2);

    final stats = await repository.getDashboardStats();
    expect(stats['productCount'], 0);
    expect(stats['activeShifts'], 0);
  });
}
