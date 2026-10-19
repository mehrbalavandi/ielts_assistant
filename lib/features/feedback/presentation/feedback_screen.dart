import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/feedback/data/feedback_api.dart';

// 🌟 FB-1: «انتقادات و پیشنهادات» در اپ — دو زبانه: «پیامِ تازه» (نوع، موضوع، کتاب، شرح، تا ۵
// تصویر) و «پیام‌های من» (وضعیت و پاسخِ پشتیبانی). همان داده‌ی صفحه‌ی /feedbackِ سایت.

class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key, this.initialBookTitle});

  /// کتابی که کاربر الان در آن است (اگر از صفحه‌ی مطالعه آمده).
  final String? initialBookTitle;

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  final GlobalKey<_MyFeedbackListState> _listKey = GlobalKey();

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('انتقادات و پیشنهادات'),
          bottom: TabBar(
            controller: _tabs,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: const [
              Tab(text: 'پیامِ تازه'),
              Tab(text: 'پیام‌های من'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabs,
          children: [
            _NewFeedbackForm(
              initialBookTitle: widget.initialBookTitle,
              onSent: () {
                _listKey.currentState?.reload();
                _tabs.animateTo(1);
              },
            ),
            _MyFeedbackList(key: _listKey),
          ],
        ),
      ),
    );
  }
}

class _NewFeedbackForm extends ConsumerStatefulWidget {
  const _NewFeedbackForm({required this.onSent, this.initialBookTitle});

  final VoidCallback onSent;
  final String? initialBookTitle;

  @override
  ConsumerState<_NewFeedbackForm> createState() => _NewFeedbackFormState();
}

class _NewFeedbackFormState extends ConsumerState<_NewFeedbackForm>
    with AutomaticKeepAliveClientMixin {
  String _kind = 'bug';
  final TextEditingController _subject = TextEditingController();
  late final TextEditingController _book = TextEditingController(
    text: widget.initialBookTitle ?? '',
  );
  final TextEditingController _message = TextEditingController();
  final List<PlatformFile> _images = [];
  bool _sending = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _subject.dispose();
    _book.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final FilePickerResult? r = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (r == null || !mounted) return;
    final List<PlatformFile> picked = [
      for (final PlatformFile f in r.files)
        if (f.path != null) f,
    ];
    final List<PlatformFile> tooBig = [
      for (final f in picked)
        if (f.size > kFeedbackMaxImageBytes) f,
    ];
    setState(() {
      for (final f in picked) {
        if (f.size > kFeedbackMaxImageBytes) continue;
        if (_images.length >= kFeedbackMaxImages) break;
        if (_images.any((e) => e.path == f.path)) continue;
        _images.add(f);
      }
      _error = tooBig.isEmpty
          ? null
          : 'هر تصویر حداکثر ۵ مگابایت؛ ${tooBig.length} تصویرِ بزرگ‌تر اضافه نشد.';
    });
  }

  Future<void> _send() async {
    if (_subject.text.trim().isEmpty || _message.text.trim().isEmpty) {
      setState(() => _error = 'موضوع و شرح را بنویسید.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final String msg = await ref
          .read(feedbackApiProvider)
          .send(
            kind: _kind,
            subject: _subject.text.trim(),
            message: _message.text.trim(),
            bookTitle: _book.text,
            imagePaths: [for (final f in _images) f.path!],
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      setState(() {
        _subject.clear();
        _message.clear();
        _images.clear();
      });
      widget.onSent();
    } on FeedbackException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    InputDecoration deco(String label, {String? hint}) => InputDecoration(
      labelText: label,
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'ایرادی در برنامه دیدید یا پیشنهادی دارید؟ بنویسید؛ اگر می‌توانید تصویرِ صفحه (اسکرین‌شات) را هم بفرستید. پاسخ در «پیام‌های من» می‌آید.',
          style: TextStyle(color: Colors.grey.shade700, height: 1.7, fontSize: 13),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final MapEntry<String, String> k in kFeedbackKinds.entries)
              ChoiceChip(
                label: Text(k.value),
                selected: _kind == k.key,
                onSelected: (_) => setState(() => _kind = k.key),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _subject,
          maxLength: 150,
          decoration: deco('موضوع', hint: 'مثلاً: پخشِ صوت در صفحه‌ی ۲۴ قطع می‌شود'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _book,
          maxLength: 150,
          decoration: deco('کتاب و صفحه (اختیاری)', hint: 'مثلاً: Mindset 01، صفحه‌ی ۲۴'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _message,
          maxLength: 5000,
          minLines: 5,
          maxLines: 10,
          decoration: deco('شرح', hint: 'چه کردید، چه انتظار داشتید و چه شد؟'),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final PlatformFile f in _images)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(f.path!),
                      width: 84,
                      height: 84,
                      fit: BoxFit.cover,
                    ),
                  ),
                  PositionedDirectional(
                    top: 2,
                    end: 2,
                    child: InkWell(
                      onTap: () => setState(() => _images.remove(f)),
                      child: const CircleAvatar(
                        radius: 11,
                        backgroundColor: Colors.black54,
                        child: Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            if (_images.length < kFeedbackMaxImages)
              OutlinedButton.icon(
                onPressed: _sending ? null : _pickImages,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text('تصویر (${_images.length}/$kFeedbackMaxImages)'),
              ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: scheme.error)),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _sending ? null : _send,
          icon: _sending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.send_rounded),
          label: const Text('ارسال'),
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
        ),
      ],
    );
  }
}

class _MyFeedbackList extends ConsumerStatefulWidget {
  const _MyFeedbackList({super.key});

  @override
  ConsumerState<_MyFeedbackList> createState() => _MyFeedbackListState();
}

class _MyFeedbackListState extends ConsumerState<_MyFeedbackList>
    with AutomaticKeepAliveClientMixin {
  late Future<(List<FeedbackItem>, int)> _future = _load();

  @override
  bool get wantKeepAlive => true;

  Future<(List<FeedbackItem>, int)> _load() async {
    final r = await ref.read(feedbackApiProvider).mine();
    // دیدنِ فهرست = دیدنِ پاسخ‌ها (نشانِ «تازه» همین یک‌بار دیده می‌شود)
    if (r.$2 > 0) ref.read(feedbackApiProvider).markSeen();
    return r;
  }

  void reload() => setState(() => _future = _load());

  Color _statusColor(String s) => switch (s) {
    'resolved' => Colors.green,
    'in_progress' => Colors.blue,
    'closed' => Colors.grey,
    _ => Colors.orange,
  };

  String _date(DateTime? d) => d == null
      ? ''
      : '${d.year}/${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: () async {
        reload();
        await _future.catchError((_) => (<FeedbackItem>[], 0));
      },
      child: FutureBuilder<(List<FeedbackItem>, int)>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return ListView(
              children: [
                const SizedBox(height: 80),
                Center(child: Text(snap.error.toString())),
              ],
            );
          }
          final List<FeedbackItem> items = snap.data!.$1;
          if (items.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 80),
                Center(child: Text('هنوز پیامی نفرستاده‌اید.')),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final FeedbackItem f = items[i];
              final Color c = _statusColor(f.status);
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              f.subject,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (f.unseenReply)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(end: 6),
                              child: Chip(
                                label: const Text('پاسخِ تازه'),
                                visualDensity: VisualDensity.compact,
                                backgroundColor: Colors.blue.shade50,
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: c.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(f.statusLabel, style: TextStyle(color: c, fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          f.kindLabel,
                          _date(f.createdAt),
                          if (f.attachments > 0) '${f.attachments} تصویر',
                        ].join(' · '),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 8),
                      Text(f.message, style: const TextStyle(height: 1.6)),
                      if (f.adminReply != null && f.adminReply!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'پاسخِ پشتیبانی · ${_date(f.repliedAt)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(f.adminReply!, style: const TextStyle(height: 1.6)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
