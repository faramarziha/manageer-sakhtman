import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../utils/app_theme.dart';
import '../../utils/persian.dart';
import '../../widgets/common_widgets.dart';

/// درخواست‌های تعمیرات ساکن + ثبت درخواست جدید
class ResidentRequestsPage extends StatelessWidget {
  const ResidentRequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final unit = store.currentUnit!;
    final list = store.buildingRequests.where((r) => r.unitId == unit.id).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(title: const Text('درخواست‌های من')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('درخواست جدید',
            style: TextStyle(fontWeight: FontWeight.w700)),
        onPressed: () => _showAddDialog(context),
      ),
      body: SafeArea(
        child: list.isEmpty
            ? const EmptyState(
                icon: Icons.build_outlined,
                message: 'هنوز درخواستی ثبت نکرده‌اید',
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                itemBuilder: (ctx, i) {
                  final r = list[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  r.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              StatusChip(
                                label: r.status.label,
                                color: _color(r.status),
                                bgColor: _bg(r.status),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            r.description,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.category_outlined,
                                  size: 14, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                r.category,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary),
                              ),
                              const Spacer(),
                              Text(
                                Persian.timeAgo(r.date),
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Color _color(RequestStatus s) => switch (s) {
        RequestStatus.pending => AppColors.warning,
        RequestStatus.inProgress => AppColors.primary,
        RequestStatus.done => AppColors.success,
      };

  Color _bg(RequestStatus s) => switch (s) {
        RequestStatus.pending => AppColors.warningLight,
        RequestStatus.inProgress => AppColors.primaryLight,
        RequestStatus.done => AppColors.successLight,
      };

  void _showAddDialog(BuildContext context) {
    final store = context.read<AppStore>();
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String category = AppStore.requestCategories.first;

    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setD) => AlertDialog(
          title: const Text('ثبت درخواست جدید'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'دسته‌بندی'),
                  items: AppStore.requestCategories
                      .map((c) =>
                          DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setD(() => category = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'عنوان درخواست',
                    hintText: 'مثلاً: نشتی آب در آشپزخانه',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'شرح مشکل',
                    hintText: 'توضیحات کامل را بنویسید...',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: const Text('انصراف'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) return;
                await store.addRequest(
                  unitId: store.currentUnit!.id,
                  title: titleCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                  category: category,
                );
                if (dCtx.mounted) Navigator.pop(dCtx);
                if (context.mounted) {
                  showSuccessSnack(
                      context, 'درخواست شما برای مدیر ساختمان ارسال شد');
                }
              },
              child: const Text('ثبت درخواست'),
            ),
          ],
        ),
      ),
    );
  }
}
