import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/core/network/dio_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

// 🌟 FB-1: انتقادات و پیشنهادات / گزارشِ ایراد — همان بخشِ سایت (/feedback)، با تصویر.

const Map<String, String> kFeedbackKinds = {
  'bug': 'گزارشِ ایراد',
  'suggestion': 'پیشنهاد',
  'criticism': 'انتقاد',
  'other': 'سایر',
};

/// سقف‌ها همان سرور (Feedback::MAX_IMAGES، MAX_IMAGE_KB).
const int kFeedbackMaxImages = 5;
const int kFeedbackMaxImageBytes = 5 * 1024 * 1024;

@immutable
class FeedbackItem {
  final int id;
  final String kind;
  final String kindLabel;
  final String subject;
  final String message;
  final String status;
  final String statusLabel;
  final String? adminReply;
  final DateTime? repliedAt;
  final bool unseenReply;
  final int attachments;
  final DateTime? createdAt;

  const FeedbackItem({
    required this.id,
    required this.kind,
    required this.kindLabel,
    required this.subject,
    required this.message,
    required this.status,
    required this.statusLabel,
    this.adminReply,
    this.repliedAt,
    this.unseenReply = false,
    this.attachments = 0,
    this.createdAt,
  });

  factory FeedbackItem.fromJson(Map<String, dynamic> j) => FeedbackItem(
    id: (j['id'] as num).toInt(),
    kind: j['kind']?.toString() ?? 'other',
    kindLabel: j['kind_label']?.toString() ?? '',
    subject: j['subject']?.toString() ?? '',
    message: j['message']?.toString() ?? '',
    status: j['status']?.toString() ?? 'new',
    statusLabel: j['status_label']?.toString() ?? '',
    adminReply: j['admin_reply'] as String?,
    repliedAt: DateTime.tryParse(j['replied_at']?.toString() ?? '')?.toLocal(),
    unseenReply: j['unseen_reply'] == true,
    attachments: (j['attachments'] as num?)?.toInt() ?? 0,
    createdAt: DateTime.tryParse(j['created_at']?.toString() ?? '')?.toLocal(),
  );
}

class FeedbackException implements Exception {
  FeedbackException(this.message);
  final String message;
  @override
  String toString() => message;
}

class FeedbackApi {
  FeedbackApi(this._dio);
  final Dio _dio;

  FeedbackException _err(DioException e, String fallback) {
    final Object? d = e.response?.data;
    if (d is Map && d['message'] is String) return FeedbackException(d['message']);
    return FeedbackException(
      e.response == null ? 'اتصال به سرور برقرار نشد.' : fallback,
    );
  }

  Future<(List<FeedbackItem>, int)> mine() async {
    try {
      final res = await _dio.get('/api/feedback');
      final List<FeedbackItem> items = [
        for (final Object? o in (res.data['items'] as List? ?? const []))
          if (o is Map) FeedbackItem.fromJson(Map<String, dynamic>.from(o)),
      ];
      return (items, (res.data['unseen'] as num?)?.toInt() ?? 0);
    } on DioException catch (e) {
      throw _err(e, 'فهرستِ پیام‌ها دریافت نشد.');
    }
  }

  Future<void> markSeen() async {
    try {
      await _dio.post('/api/feedback/seen');
    } catch (_) {}
  }

  /// پیامِ تازه؛ [imagePaths] تصویرهای روی دستگاه.
  Future<String> send({
    required String kind,
    required String subject,
    required String message,
    String? bookTitle,
    List<String> imagePaths = const [],
  }) async {
    String? version;
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      version = '${info.version}+${info.buildNumber}';
    } catch (_) {}
    String platform = '';
    if (!kIsWeb) {
      final String os = '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
      platform = os.length > 120 ? os.substring(0, 120) : os;
    }
    try {
      final FormData form = FormData.fromMap({
        'kind': kind,
        'subject': subject,
        'message': message,
        if (bookTitle != null && bookTitle.trim().isNotEmpty) 'book_title': bookTitle.trim(),
        'app_version': ?version,
        if (platform.isNotEmpty) 'platform': platform,
      });
      // لاراول: images[] تکراری ← آرایه
      for (final String p in imagePaths) {
        form.files.add(MapEntry('images[]', await MultipartFile.fromFile(p)));
      }
      final res = await _dio.post(
        '/api/feedback',
        data: form,
        options: Options(headers: {'Accept': 'application/json'}),
      );
      return (res.data['message'] as String?) ?? 'پیامتان ثبت شد.';
    } on DioException catch (e) {
      throw _err(e, 'ارسالِ پیام ممکن نشد.');
    }
  }
}

final feedbackApiProvider = Provider<FeedbackApi>(
  (ref) => FeedbackApi(ref.watch(dioProvider)),
);
