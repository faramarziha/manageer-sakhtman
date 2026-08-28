import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../utils/app_theme.dart';
import '../../utils/persian.dart';

import 'manager_dashboard.dart';
import 'manager_units.dart';
import 'manager_charges.dart';
import 'manager_notices.dart';
import 'manager_requests.dart';

/// شل اصلی پنل مدیر ساختمان با ناوبری پایین
class ManagerShell extends StatefulWidget {
  const ManagerShell({super.key});

  @override
  State<ManagerShell> createState() => _ManagerShellState();
}

class _ManagerShellState extends State<ManagerShell> {
  int _index = 0;

  final _pages = const [
    ManagerDashboard(),
    ManagerUnitsPage(),
    ManagerChargesPage(),
    ManagerRequestsPage(),
    ManagerNoticesPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard_rounded),
            label: 'داشبورد',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.apartment_outlined),
            activeIcon: Icon(Icons.apartment_rounded),
            label: 'واحدها',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.payments_outlined),
            activeIcon: Icon(Icons.payments_rounded),
            label: 'شارژ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.build_outlined),
            activeIcon: Icon(Icons.build_rounded),
            label: 'درخواست‌ها',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.campaign_outlined),
            activeIcon: Icon(Icons.campaign_rounded),
            label: 'اعلانات',
          ),
        ],
      ),
    );
  }
}

/// دیالوگ جزئیات واحد برای مدیر
void showUnitDetailDialog(BuildContext context, Unit unit) {
  final store = context.read<AppStore>();
  final charge = store.currentChargeOfUnit(unit.id);
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('واحد ${Persian.digits(unit.number)}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detailRow(Icons.person, 'مالک', unit.ownerName),
          _detailRow(Icons.phone, 'تماس', Persian.digits(unit.phone)),
          _detailRow(Icons.straighten, 'متراژ', '${Persian.digits(unit.area)} متر مربع'),
          _detailRow(Icons.people, 'ساکنین', '${Persian.digits(unit.residents)} نفر'),
          _detailRow(
            unit.isOccupied ? Icons.home : Icons.home_outlined,
            'وضعیت سکونت',
            unit.isOccupied ? 'مسکونی' : 'خالی',
          ),
          if (charge != null)
            _detailRow(
              Icons.payments,
              'شارژ ${charge.month}',
              '${Persian.toman(charge.amount)} • ${charge.status.label}',
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('بستن'),
        ),
      ],
    ),
  );
}

Widget _detailRow(IconData icon, String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    ),
  );
}
