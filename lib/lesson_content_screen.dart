import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/models/data_models.dart';
import 'dart:convert';
import 'dart:io';

import 'player_display_state.dart';
import 'mini_player_widget.dart'; // ویجت پلیر کوچک

// Provider برای نگه داشتن متن درس لود شده
final lessonContentProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, jsonPath) async {
      final file = File(jsonPath);
      if (!await file.exists()) {
        throw Exception('فایل JSON درس یافت نشد.');
      }
      final contents = await file.readAsString();
      return jsonDecode(contents) as Map<String, dynamic>;
    });

class LessonContentScreen extends ConsumerWidget {
  final Topic topic;
  const LessonContentScreen({required this.topic, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // مشاهده وضعیت نمایش پلیر برای تنظیم Padding
    final displayMode = ref.watch(playerDisplayProvider);
    final isMinimized = displayMode == PlayerDisplayMode.minimized;

    // لود محتوای JSON
    final contentAsyncValue = ref.watch(
      lessonContentProvider(topic.jsonFilePath),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(topic.name),
        backgroundColor: Colors.indigo.shade700,
      ),
      // بدنه اصلی که متن درس را نمایش می‌دهد
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          // افزودن PaddingBottom به اندازه پلیر کوچک
          padding: EdgeInsets.only(
            top: 16.0,
            bottom: isMinimized ? 70.0 : 16.0,
          ),
          child: contentAsyncValue.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) =>
                Center(child: Text('خطا در بارگذاری محتوای درس: $e')),
            data: (data) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // فرض می‌کنیم کلیدهای 'title' و 'content' در JSON وجود دارند
                    Text(
                      data['title'] ?? 'عنوان نامشخص',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const Divider(height: 32),
                    Text(
                      data['content'] ?? 'متن درس نامشخص',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),

      // پلیر کوچک در پایین صفحه (Mini Player in the Bottom)
      bottomSheet: isMinimized ? MiniPlayerWidget(topic: topic) : null,
    );
  }
}
