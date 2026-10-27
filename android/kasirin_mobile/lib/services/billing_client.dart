import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:kasirin_mobile/domain/pos_repository.dart';

import 'billing_config.dart' as config;

class BillingClient {
  BillingClient(this._billingConfig);

  final config.BillingConfig _billingConfig;

  String get _baseUrl => _billingConfig.baseUrl.replaceAll(
        RegExp(r'/$'),
        '',
      );

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  /// Default headers for JSON API requests.
  Map<String, String> get _defaultHeaders => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  /// Helper method to handle HTTP responses uniformly.
  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    } else {
      throw Exception(
        'Server error: ${response.statusCode} - ${response.reasonPhrase}',
      );
    }
  }

  /// Check whether the server is reachable.
  Future<bool> checkServerHealth() async {
    try {
      final response = await http
          .get(_uri('/health'), headers: _defaultHeaders)
          .timeout(const Duration(seconds: 5));

      return response.statusCode >= 200 && response.statusCode < 300;
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Register a POS device with the server.
  Future<dynamic> registerDevice({
    required String installationId,
    required String deviceId,
    required String storeName,
    required int customerId,
  }) async {
    final response = await http
        .post(
          _uri('/api/pos/register'),
          headers: _defaultHeaders,
          body: jsonEncode({
            'posreq': jsonEncode({
              'installation_id': installationId,
              'device_id': deviceId,
              'store_name': storeName,
              'customer_id': customerId,
            }),
          }),
        )
        .timeout(const Duration(seconds: 10));

    return _handleResponse(response);
  }

  /// Check the license status of the current device.
  Future<dynamic> checkLicense({
    required String bearerToken,
  }) async {
    final response = await http
        .get(
          _uri('/api/pos/license'),
          headers: {
            ..._defaultHeaders,
            'Authorization': 'Bearer $bearerToken',
          },
        )
        .timeout(const Duration(seconds: 10));

    return _handleResponse(response);
  }

  /// Get device status and subscription information.
  Future<dynamic> getDeviceStatus({
    required String bearerToken,
  }) async {
    final response = await http
        .get(
          _uri('/api/pos/status'),
          headers: {
            ..._defaultHeaders,
            'Authorization': 'Bearer $bearerToken',
          },
        )
        .timeout(const Duration(seconds: 10));

    return _handleResponse(response);
  }

  /// Create a checkout order on the server.
  Future<dynamic> createCheckout({
    required String invoiceNo,
    required int cashierId,
    required int shiftId,
    required List<CartItemInput> items,
    required String paymentMethod,
    required int paymentAmount,
    required String customerEmail,
    required String customerName,
  }) async {
    final body = {
      'invoiceNo': invoiceNo,
      'cashierId': cashierId,
      'shiftId': shiftId,
      'items': items
          .map(
            (item) => {
              'productId': item.productId,
              'quantity': item.quantity,
            },
          )
          .toList(),
      'paymentMethod': paymentMethod,
      'paymentAmount': paymentAmount,
      'customerEmail': customerEmail,
      'customerName': customerName,
    };

    final response = await http
        .post(
          _uri('/api/checkout/create'),
          headers: _defaultHeaders,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));

    return _handleResponse(response);
  }

  /// Forward a payment notification payload to the server.
  Future<dynamic> mapMidtransNotification({
    required String provider,
    required dynamic payload,
  }) async {
    final safeProvider = Uri.encodeComponent(provider);
    
    final response = await http
        .post(
          _uri('/api/payment/notification/$safeProvider'),
          headers: _defaultHeaders,
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 10));

    return _handleResponse(response);
  }
}
