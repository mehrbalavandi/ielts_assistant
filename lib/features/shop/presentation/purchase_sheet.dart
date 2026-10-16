import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/library/providers/books_provider.dart';
import 'package:ielts_assistant/features/shop/data/shop_api.dart';
import 'package:url_launcher/url_launcher.dart';

// 🌟 PAY-2، PAY-3: پنجره‌ی خرید — «پرداختِ اینترنتی» (درگاه در مرورگر؛ برگشت به اپ
// ویترین را تازه می‌کند) یا «کارت‌به‌کارت» (مشخصاتِ کارت، بعد ارسالِ رسید).

/// [onLeftForPayment]: کاربر به مرورگر رفت؛ ویترین با برگشت به اپ تازه می‌شود.
Future<void> showPurchaseSheet(
  BuildContext context,
  WidgetRef ref,
  BookModel book, {
  required VoidCallback onLeftForPayment,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => Directionality(
      textDirection: TextDirection.rtl,
      child: _PurchaseSheet(book: book, onLeftForPayment: onLeftForPayment),
    ),
  );
}

class _PurchaseSheet extends ConsumerStatefulWidget {
  const _PurchaseSheet({required this.book, required this.onLeftForPayment});

  final BookModel book;
  final VoidCallback onLeftForPayment;

  @override
  ConsumerState<_PurchaseSheet> createState() => _PurchaseSheetState();
}

class _PurchaseSheetState extends ConsumerState<_PurchaseSheet> {
  late final Future<ShopOptions> _options = ref.read(shopApiProvider).options();
  String? _busy; // gateway | card
  String? _error;

  Future<void> _start(String method) async {
    setState(() {
      _busy = method;
      _error = null;
    });
    try {
      final OrderStart s = await ref
          .read(shopApiProvider)
          .createOrder(widget.book.id, method);
      if (!mounted) return;
      final NavigatorState nav = Navigator.of(context);
      final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

      if (s.order.isPaid) {
        nav.pop();
        ref.read(booksProvider.notifier).fetchBooks();
        messenger.showSnackBar(
          SnackBar(content: Text(s.message ?? 'کتاب برای شما فعال شد.')),
        );
        return;
      }
      if (method == 'gateway' && s.payUrl != null) {
        final bool ok = await launchUrl(
          Uri.parse(s.payUrl!),
          mode: LaunchMode.externalApplication,
        );
        if (!mounted) return;
        if (!ok) {
          setState(() {
            _busy = null;
            _error = 'مرورگر باز نشد.';
          });
          return;
        }
        widget.onLeftForPayment();
        nav.pop();
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'پرداخت در مرورگر باز شد؛ بعد از پرداخت به برنامه برگردید.',
            ),
          ),
        );
        return;
      }
      if (method == 'card' && s.card != null) {
        nav.pop();
        nav.push(
          MaterialPageRoute<void>(
            builder: (_) => CardTransferScreen(order: s.order, card: s.card!),
          ),
        );
      }
    } on ShopException catch (e) {
      if (mounted) {
        setState(() {
          _busy = null;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: FutureBuilder<ShopOptions>(
          future: _options,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snap.hasError) {
              return SizedBox(
                height: 160,
                child: Center(child: Text(snap.error.toString())),
              );
            }
            final ShopOptions o = snap.data!;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'خریدِ «${widget.book.title}»',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'روشِ پرداخت را انتخاب کنید.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 16),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                if (o.gateway)
                  _MethodTile(
                    icon: Icons.credit_card_rounded,
                    title: 'پرداختِ اینترنتی',
                    subtitle:
                        'با همه‌ی کارت‌های بانکی؛ کتاب بلافاصله فعال می‌شود.',
                    busy: _busy == 'gateway',
                    enabled: _busy == null,
                    onTap: () => _start('gateway'),
                  ),
                if (o.card != null) ...[
                  const SizedBox(height: 10),
                  _MethodTile(
                    icon: Icons.swap_horiz_rounded,
                    title: 'کارت‌به‌کارت',
                    subtitle:
                        'واریز و ارسالِ رسید؛ کتاب بعد از بررسی فعال می‌شود.',
                    busy: _busy == 'card',
                    enabled: _busy == null,
                    onTap: () => _start('card'),
                  ),
                ],
                if (!o.gateway && o.card == null)
                  const Text('فعلاً هیچ روشِ پرداختی فعال نیست.'),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.busy,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Icon(icon, size: 30, color: Colors.indigo),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.chevron_left_rounded),
        enabled: enabled,
        onTap: onTap,
      ),
    );
  }
}

/// 🌟 PAY-3: مشخصاتِ کارت و فرمِ رسید.
class CardTransferScreen extends ConsumerStatefulWidget {
  const CardTransferScreen({
    super.key,
    required this.order,
    required this.card,
  });

  final OrderInfo order;
  final CardInfo card;

  @override
  ConsumerState<CardTransferScreen> createState() => _CardTransferScreenState();
}

class _CardTransferScreenState extends ConsumerState<CardTransferScreen> {
  final TextEditingController _tracking = TextEditingController();
  final TextEditingController _last4 = TextEditingController();
  final TextEditingController _paidAt = TextEditingController();
  String? _receiptPath;
  String? _receiptName;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _tracking.dispose();
    _last4.dispose();
    _paidAt.dispose();
    super.dispose();
  }

  void _copy(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label کپی شد.')));
  }

  Future<void> _pickReceipt() async {
    final FilePickerResult? r = await FilePicker.pickFiles(
      type: FileType.image,
    );
    final String? path = r?.files.single.path;
    if (path == null || !mounted) return;
    setState(() {
      _receiptPath = path;
      _receiptName = r!.files.single.name;
    });
  }

  Future<void> _submit() async {
    if (_tracking.text.trim().isEmpty) {
      setState(() => _error = 'کدِ پیگیری (یا شماره‌ی مرجعِ) واریز را وارد کنید.');
      return;
    }
    if (_last4.text.trim().isNotEmpty &&
        !RegExp(r'^\d{4}$').hasMatch(_last4.text.trim())) {
      setState(() => _error = 'چهار رقمِ آخرِ کارت باید چهار رقم باشد.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final (OrderInfo _, String message) = await ref
          .read(shopApiProvider)
          .sendReceipt(
            widget.order.id,
            trackingCode: _tracking.text.trim(),
            cardLast4: _last4.text.trim(),
            paidAt: _paidAt.text.trim(),
            receiptPath: _receiptPath,
          );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            icon: const Icon(
              Icons.hourglass_top_rounded,
              color: Colors.orange,
              size: 40,
            ),
            title: const Text('رسید ثبت شد'),
            content: Text(
              '$message\nوضعیت را در «سفارش‌های من» می‌بینید؛ پس از تأیید، کتاب در ویترین فعال می‌شود.',
              style: const TextStyle(height: 1.8),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('باشه'),
              ),
            ],
          ),
        ),
      );
      if (mounted) Navigator.pop(context);
    } on ShopException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final CardInfo c = widget.card;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('کارت‌به‌کارت')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'مبلغِ ${formatToman(widget.order.amount)} را به کارتِ زیر واریز کنید، بعد مشخصاتِ واریز را بفرستید.',
              style: const TextStyle(height: 1.8),
            ),
            // 🌟 PAY-5: مبلغ «تومانِ شناسه» دارد؛ باید دقیقاً همان واریز شود.
            if ((widget.order.amountSuffix ?? 0) > 0)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, color: Colors.amber.shade900, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'لطفاً دقیقاً همین مبلغ را واریز کنید، نه عددِ رُند. '
                        '${widget.order.amountSuffix} تومانِ آخر شناسه‌ی سفارشِ شماست و '
                        'باعث می‌شود واریزتان زودتر تأیید شود.',
                        style: const TextStyle(fontSize: 13, height: 1.7),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3949AB), Color(0xFF5C6BC0)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: DefaultTextStyle(
                style: const TextStyle(color: Colors.white),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.bank ?? 'شماره‌ی کارت',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.grouped,
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(
                              fontSize: 20,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'کپیِ شماره‌ی کارت',
                          color: Colors.white,
                          onPressed: () => _copy(c.number, 'شماره‌ی کارت'),
                          icon: const Icon(Icons.copy_rounded),
                        ),
                      ],
                    ),
                    if (c.holder != null) Text('به نامِ ${c.holder}'),
                  ],
                ),
              ),
            ),
            if (c.sheba != null && c.sheba!.isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('شبا'),
                subtitle: Text(c.sheba!, textDirection: TextDirection.ltr),
                trailing: IconButton(
                  icon: const Icon(Icons.copy_rounded),
                  onPressed: () => _copy(c.sheba!, 'شبا'),
                ),
              ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('مبلغِ دقیق'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatToman(widget.order.amount),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    tooltip: 'کپیِ مبلغ',
                    onPressed: () => _copy('${widget.order.amount}', 'مبلغ'),
                    icon: const Icon(Icons.copy_rounded, size: 20),
                  ),
                ],
              ),
              subtitle: Text('سفارشِ شماره‌ی ${widget.order.id}'),
            ),
            const Divider(height: 32),
            Text(
              'مشخصاتِ واریز',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            TextField(
              controller: _tracking,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'کدِ پیگیری / شماره‌ی مرجع *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _last4,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: '۴ رقمِ آخرِ کارتِ شما',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _paidAt,
                    decoration: const InputDecoration(
                      labelText: 'تاریخ و ساعتِ واریز',
                      hintText: '۱۴۰۵/۰۷/۲۴ ۱۰:۳۰',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : _pickReceipt,
              icon: Icon(
                _receiptPath == null
                    ? Icons.add_photo_alternate_outlined
                    : Icons.check_circle_rounded,
                color: _receiptPath == null ? null : Colors.green,
              ),
              label: Text(
                _receiptName ?? 'تصویرِ رسید (اختیاری، بررسی را سریع‌تر می‌کند)',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (c.hint != null) ...[
              const SizedBox(height: 12),
              Text(
                c.hint!,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('ثبتِ رسید', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
