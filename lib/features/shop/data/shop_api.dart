import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/core/network/dio_provider.dart';

// 🌟 PAY-2، PAY-3: خرید از داخلِ اپ — درگاه (لینکِ امضاشده در مرورگر) یا کارت‌به‌کارت
// (مشخصاتِ کارت + ارسالِ رسید، تأییدِ دستیِ ادمین).

@immutable
class CardInfo {
  final String number;
  final String? holder;
  final String? bank;
  final String? sheba;
  final String? hint;

  const CardInfo({
    required this.number,
    this.holder,
    this.bank,
    this.sheba,
    this.hint,
  });

  static CardInfo? fromJson(Object? j) {
    if (j is! Map || j['number'] == null) return null;
    return CardInfo(
      number: j['number'].toString(),
      holder: j['holder'] as String?,
      bank: j['bank'] as String?,
      sheba: j['sheba'] as String?,
      hint: j['hint'] as String?,
    );
  }

  /// ۶۰۳۷-۹۹۱۱-… برای نمایش (کپی بدونِ خط‌تیره).
  String get grouped => [
    for (int i = 0; i < number.length; i += 4)
      number.substring(i, min(i + 4, number.length)),
  ].join('  ');
}

@immutable
class ShopOptions {
  final bool gateway;
  final CardInfo? card;

  const ShopOptions({required this.gateway, this.card});
}

@immutable
class OrderInfo {
  final int id;
  final String bookTitle;
  final int amount;
  final String method; // gateway | card
  final String status;
  final String statusLabel;
  final String? adminNote;
  final String? trackingCode;
  final DateTime? createdAt;

  const OrderInfo({
    required this.id,
    required this.bookTitle,
    required this.amount,
    required this.method,
    required this.status,
    required this.statusLabel,
    this.adminNote,
    this.trackingCode,
    this.createdAt,
  });

  factory OrderInfo.fromJson(Map<String, dynamic> j) => OrderInfo(
    id: (j['id'] as num).toInt(),
    bookTitle: (j['book_title'] as String?) ?? '',
    amount: (j['amount'] as num?)?.toInt() ?? 0,
    method: (j['method'] as String?) ?? 'gateway',
    status: (j['status'] as String?) ?? '',
    statusLabel: (j['status_label'] as String?) ?? '',
    adminNote: j['admin_note'] as String?,
    trackingCode: j['card_tracking_code'] as String?,
    createdAt: DateTime.tryParse((j['created_at'] as String?) ?? ''),
  );

  bool get isPaid => status == 'paid';
  bool get canSendReceipt =>
      method == 'card' &&
      (status == 'pending' || status == 'awaiting_review' || status == 'rejected');
}

/// پاسخِ ساختنِ سفارش.
@immutable
class OrderStart {
  final OrderInfo order;
  final String? payUrl;
  final CardInfo? card;
  final String? message;

  const OrderStart({required this.order, this.payUrl, this.card, this.message});
}

class ShopException implements Exception {
  ShopException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// «۱۸۰٬۰۰۰ تومان»
String formatToman(int amount) {
  final String s = amount.toString();
  final StringBuffer b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('٬');
    b.write(s[i]);
  }
  return '$b تومان';
}

class ShopApi {
  ShopApi(this._dio);
  final Dio _dio;

  ShopException _err(DioException e, String fallback) {
    final Object? d = e.response?.data;
    if (d is Map && d['message'] is String) return ShopException(d['message']);
    return ShopException(
      e.response == null ? 'اتصال به سرور برقرار نشد.' : fallback,
    );
  }

  Future<ShopOptions> options() async {
    try {
      final res = await _dio.get('/api/shop/options');
      return ShopOptions(
        gateway: res.data['gateway'] == true,
        card: CardInfo.fromJson(res.data['card']),
      );
    } on DioException catch (e) {
      throw _err(e, 'روش‌های پرداخت دریافت نشد.');
    }
  }

  Future<OrderStart> createOrder(String bookId, String method) async {
    try {
      final res = await _dio.post(
        '/api/orders',
        data: {'book_id': int.tryParse(bookId) ?? bookId, 'method': method},
      );
      final Map<String, dynamic> d = Map<String, dynamic>.from(res.data);
      return OrderStart(
        order: OrderInfo.fromJson(Map<String, dynamic>.from(d['order'])),
        payUrl: d['pay_url'] as String?,
        card: CardInfo.fromJson(d['card']),
        message: d['message'] as String?,
      );
    } on DioException catch (e) {
      throw _err(e, 'ساختنِ سفارش ممکن نشد.');
    }
  }

  Future<List<OrderInfo>> myOrders() async {
    try {
      final res = await _dio.get('/api/orders');
      return [
        for (final Object? o in (res.data['orders'] as List? ?? const []))
          if (o is Map) OrderInfo.fromJson(Map<String, dynamic>.from(o)),
      ];
    } on DioException catch (e) {
      throw _err(e, 'فهرستِ سفارش‌ها دریافت نشد.');
    }
  }

  /// رسیدِ کارت‌به‌کارت. [receiptPath] تصویرِ رسید (اختیاری).
  Future<(OrderInfo, String)> sendReceipt(
    int orderId, {
    required String trackingCode,
    String? cardLast4,
    String? paidAt,
    String? receiptPath,
  }) async {
    try {
      final FormData form = FormData.fromMap({
        'tracking_code': trackingCode,
        if (cardLast4 != null && cardLast4.isNotEmpty) 'card_last4': cardLast4,
        if (paidAt != null && paidAt.isNotEmpty) 'paid_at': paidAt,
        if (receiptPath != null)
          'receipt': await MultipartFile.fromFile(receiptPath),
      });
      final res = await _dio.post(
        '/api/orders/$orderId/receipt',
        data: form,
        options: Options(headers: {'Accept': 'application/json'}),
      );
      return (
        OrderInfo.fromJson(Map<String, dynamic>.from(res.data['order'])),
        (res.data['message'] as String?) ?? '',
      );
    } on DioException catch (e) {
      throw _err(e, 'ارسالِ رسید ممکن نشد.');
    }
  }
}

final shopApiProvider = Provider<ShopApi>(
  (ref) => ShopApi(ref.watch(dioProvider)),
);
