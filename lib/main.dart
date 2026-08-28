import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'data/app_store.dart';
import 'utils/app_theme.dart';
import 'screens/role_select_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AppStore();
  await store.init();
  runApp(
    ChangeNotifierProvider.value(
      value: store,
      child: const BuildingManagerApp(),
    ),
  );
}

class BuildingManagerApp extends StatelessWidget {
  const BuildingManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مدیریت ساختمان',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // پیکربندی کامل فارسی و راست‌چین
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [
        Locale('fa', 'IR'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const RoleSelectScreen(),
    );
  }
}
