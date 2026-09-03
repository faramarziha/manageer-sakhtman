import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/app_store.dart';
import '../../utils/app_theme.dart';
import '../../utils/persian.dart';
import '../../widgets/common_widgets.dart';

/// مدیریت اعلانات (مدیر) - ایجاد، مشاهده و حذف
class ManagerNoticesPage extends StatelessWidget {
  const ManagerNoticesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();

    return Scaffold(
      appBar: AppBar(title: const Text('اعلانات ساختمان')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('اعلان جدید',
            style: TextStyle(fontWeight: FontWeight.w700)),
        onPressed: () => _showAddNoticeDialog(context),
      ),
      body: SafeArea(
        child: store.buildingNotices.isEmpty
            ? const EmptyState(
                icon: Icons.campaign_outlined,
                message: 'هنوز اعلانی ثبت نشده است',
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: store.buildingNotices.length,
                itemBuilder: (ctx, i) {
                  final n = store.buildingNotices[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (n.isImportant)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.dangerLight,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'مهم',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.danger,
                                    ),
                                  ),
                                ),
                              Expanded(
                                child: Text(
                                  n.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded,
                                    size: 20, color: AppColors.danger),
                                onPressed: () async {
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (dCtx) => AlertDialog(
                                      title: const Text('حذف اعلان'),
                                      content: const Text(
                                          'آیا از حذف این اعلان مطمئن هستید؟'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(dCtx, false),
                                          child: const Text('انصراف'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(dCtx, true),
                                          child: const Text('حذف',
                                              style: TextStyle(
                                                  color: AppColors.danger)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (ok == true) {
                                    await store.deleteNotice(n.id);
                                    if (context.mounted) {
                                      showSuccessSnack(
                                          context, 'اعلان حذف شد');
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            n.body,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              height: 1.7,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            Persian.timeAgo(n.date),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
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

  void _showAddNoticeDialog(BuildContext context) {
    final store = context.read<AppStore>();
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    bool important = false;

    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setD) => AlertDialog(
          title: const Text('اعلان جدید'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'عنوان اعلان',
                    hintText: 'مثلاً: جلسه مجمع عمومی',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bodyCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'متن اعلان',
                    hintText: 'متن کامل اعلان را بنویسید...',
                  ),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: important,
                  onChanged: (v) => setD(() => important = v ?? false),
                  title: const Text('اعلان مهم',
                      style: TextStyle(fontSize: 13)),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.danger,
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
                if (titleCtrl.text.trim().isEmpty ||
                    bodyCtrl.text.trim().isEmpty) {
                  return;
                }
                await store.addNotice(
                  titleCtrl.text.trim(),
                  bodyCtrl.text.trim(),
                  important,
                );
                if (dCtx.mounted) Navigator.pop(dCtx);
                if (context.mounted) {
                  showSuccessSnack(context, 'اعلان برای ساکنین ارسال شد');
                }
              },
              child: const Text('انتشار'),
            ),
          ],
        ),
      ),
    );
  }
}
