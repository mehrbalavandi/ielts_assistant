import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/library/providers/books_provider.dart';
import 'package:ielts_assistant/features/shop/data/shop_api.dart';
import 'package:ielts_assistant/features/shop/presentation/purchase_sheet.dart';

// 🌟 PAY-3: «سفارش‌های من» — وضعیتِ هر خرید؛ برای کارت‌به‌کارتِ بی‌رسید یا ردشده،
// دکمه‌ی «ارسالِ رسید». دلیلِ ردِ ادمین هم این‌جا دیده می‌شود.

class MyOrdersScreen extends ConsumerStatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  ConsumerState<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends ConsumerState<MyOrdersScreen> {
  late Future<List<OrderInfo>> _orders = ref.read(shopApiProvider).myOrders();

  Future<void> _refresh() async {
    final Future<List<OrderInfo>> f = ref.read(shopApiProvider).myOrders();
    setState(() => _orders = f);
    await f.catchError((_) => <OrderInfo>[]);
    // خریدِ تأییدشده در ویترین هم دیده شود.
    ref.read(booksProvider.notifier).fetchBooks();
  }

  Future<void> _sendReceipt(OrderInfo o) async {
    try {
      final ShopOptions opts = await ref.read(shopApiProvider).options();
      if (!mounted || opts.card == null) return;
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => CardTransferScreen(order: o, card: opts.card!),
        ),
      );
      if (mounted) _refresh();
    } on ShopException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Color _statusColor(String s) => switch (s) {
    'paid' => Colors.green,
    'awaiting_review' => Colors.orange,
    'failed' || 'rejected' => Colors.red,
    _ => Colors.grey,
  };

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('سفارش‌های من')),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<List<OrderInfo>>(
            future: _orders,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return ListView(
                  children: [
                    const SizedBox(height: 120),
                    Center(child: Text(snap.error.toString())),
                  ],
                );
              }
              final List<OrderInfo> orders = (snap.data ?? const [])
                  .where((o) => o.status != 'canceled')
                  .toList();
              if (orders.isEmpty) {
                return ListView(
                  children: const [
                    SizedBox(height: 120),
                    Center(child: Text('هنوز سفارشی ندارید.')),
                  ],
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: orders.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final OrderInfo o = orders[i];
                  final Color c = _statusColor(o.status);
                  return Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  o.bookTitle,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: c.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  o.statusLabel,
                                  style: TextStyle(color: c, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${formatToman(o.amount)} · ${o.method == 'card' ? 'کارت‌به‌کارت' : 'پرداختِ اینترنتی'} · سفارشِ ${o.id}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                          if (o.status == 'rejected' &&
                              (o.adminNote ?? '').isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              'دلیل: ${o.adminNote}',
                              style: const TextStyle(color: Colors.red),
                            ),
                          ],
                          if (o.canSendReceipt && o.status != 'awaiting_review')
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: TextButton.icon(
                                onPressed: () => _sendReceipt(o),
                                icon: const Icon(Icons.receipt_long_rounded),
                                label: const Text('ارسالِ رسید'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
