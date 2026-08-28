import 'package:flutter/material.dart';
import 'resident_home.dart';
import 'resident_payments.dart';
import 'resident_requests.dart';
import 'resident_notices.dart';
import 'resident_booking.dart';

/// شل اصلی پنل ساکن با ناوبری پایین
class ResidentShell extends StatefulWidget {
  const ResidentShell({super.key});

  @override
  State<ResidentShell> createState() => _ResidentShellState();
}

class _ResidentShellState extends State<ResidentShell> {
  int _index = 0;

  final _pages = const [
    ResidentHome(),
    ResidentPaymentsPage(),
    ResidentRequestsPage(),
    ResidentBookingPage(),
    ResidentNoticesPage(),
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
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'خانه',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.payments_outlined),
            activeIcon: Icon(Icons.payments_rounded),
            label: 'پرداخت‌ها',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.build_outlined),
            activeIcon: Icon(Icons.build_rounded),
            label: 'درخواست‌ها',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_available_outlined),
            activeIcon: Icon(Icons.event_available_rounded),
            label: 'رزرو',
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
