import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/transaction_provider.dart';
import 'database/db_factory.dart';
import 'screens/home/home_screen.dart';
import 'screens/transaction/transaction_list_screen.dart';
import 'screens/statistics/statistics_screen.dart';
import 'screens/asset/asset_screen.dart';
import 'screens/profile/profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initDatabaseFactory();
  final provider = TransactionProvider();
  await provider.init();

  runApp(
    ChangeNotifierProvider.value(
      value: provider,
      child: const BookkeepingApp(),
    ),
  );
}

class BookkeepingApp extends StatelessWidget {
  const BookkeepingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '记账',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF5C6BC0),
        brightness: Brightness.light,
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF5C6BC0),
        brightness: Brightness.dark,
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  late final _screens = [
    HomeScreen(onTabChange: (i) => setState(() => _currentIndex = i)),
    const TransactionListScreen(),
    const StatisticsScreen(),
    const AssetScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '首页'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: '账单'),
          NavigationDestination(icon: Icon(Icons.pie_chart_outline), selectedIcon: Icon(Icons.pie_chart), label: '统计'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: '资产'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '我的'),
        ],
      ),
    );
  }
}
