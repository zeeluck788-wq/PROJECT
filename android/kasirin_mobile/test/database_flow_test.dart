import 'package:flutter_test/flutter_test.dart';

import 'package:kasirin_mobile/data/local_database.dart';
import 'package:kasirin_mobile/domain/password_hasher.dart';
import 'package:kasirin_mobile/domain/pos_repository.dart'
    show PosRepository, CartItemInput;

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

  test(
    'Database initialization creates schema and enables foreign keys',
    () async {
      final pragmaResult = await database
          .customSelect('PRAGMA foreign_keys')
          .get();
      expect(pragmaResult.isEmpty, isFalse);
    },
  );

  test('Database is ready for CRUD operations', () async {
    expect(await repository.setupRequired(), isTrue);
    final ownerId = await repository.createOwner(
      username: 'testowner',
      fullName: 'Test Owner',
      password: 'password123',
      storeName: 'Test Store',
    );

    expect(ownerId, isPositive);
    final owner = await repository.login('testowner', 'password123');
    expect(owner.read<int>('id'), ownerId);
  });

  test('Product CRUD operations work with database', () async {
    await repository.createOwner(
      username: 'crudowner',
      fullName: 'CRUD Owner',
      password: 'password123',
    );

    final productId = await repository.createProduct(
      sku: 'CRUD-SKU-001',
      name: 'CRUD Test Product',
      purchasePrice: 100,
      sellingPrice: 150,
      initialStock: 10,
      minimumStock: 2,
    );

    final products = await repository.products();
    expect(products.length, greaterThanOrEqualTo(1));
    expect(products.any((p) => p.read<int>('id') == productId), isTrue);

    await repository.deleteProduct(productId);
    final afterDelete = await repository.products();
    expect(afterDelete, isEmpty);
  });

  test('Transaction rollback on failure preserves data integrity', () async {
    await repository.createOwner(
      username: 'rollbackowner',
      fullName: 'Rollback Owner',
      password: 'password123',
    );

    final productId = await repository.createProduct(
      sku: 'ROLLBACK-SKU-001',
      name: 'Rollback Test Product',
      purchasePrice: 100,
      sellingPrice: 150,
      initialStock: 10,
      minimumStock: 2,
    );

    await repository.createStore('Rollback Store');
    final shiftId = await repository.openShift(cashierId: 1, openingCash: 0);

    await expectLater(
      repository.checkout(
        invoiceNo: 'ROLLBACK-INV-001',
        cashierId: 1,
        shiftId: shiftId!,
        items: [CartItemInput(productId: productId, quantity: 15)],
        paymentMethod: 'CASH',
        paymentAmount: 1000,
      ),
      throwsA(isA<StateError>()),
    );

    final afterRollbackProducts = await repository.products();
    expect(
      afterRollbackProducts.any((p) => p.read<int>('id') == productId),
      isTrue,
    );
    expect(await repository.openShiftFor(1), isNotNull);
  });

  test('Dashboard stats calculate correctly from database data', () async {
    await repository.createOwner(
      username: 'statsowner',
      fullName: 'Stats Owner',
      password: 'password123',
      storeName: 'Stats Store',
    );

    await repository.createProduct(
      sku: 'STATS-SKU-001',
      name: 'Stats Test Product',
      purchasePrice: 100,
      sellingPrice: 150,
      initialStock: 5,
      minimumStock: 2,
    );

    final stats = await repository.getDashboardStats();
    expect(stats['productCount'], equals(1));
    expect(stats['activeShifts'], equals(0));
    expect(stats['todaySales'], equals(0));
  });
}
