import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'providers/transaction_provider.dart';
import 'database/db_factory.dart';
import 'services/auto_bookkeeping_service.dart';
import 'services/push_service.dart';
import 'screens/home/home_screen.dart';
import 'screens/transaction/transaction_list_screen.dart';
import 'screens/statistics/statistics_screen.dart';
import 'screens/asset/asset_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/search/search_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initDatabaseFactory();

  // Window management for desktop (skip on web/mobile)
  if (!kIsWeb) {
    try {
      await windowManager.ensureInitialized();
      await windowManager.setMinimumSize(const Size(800, 600));
      await windowManager.setSize(const Size(1280, 800));
      await windowManager.setTitle('记账');
      await windowManager.center();
      await windowManager.show();
      await windowManager.focus();
    } catch (_) {
      // window_manager not supported on this platform
    }
  }

  final provider = TransactionProvider();
  await provider.init();
  AutoBookkeepingService().initialize();
  PushService().initialize(provider);

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

class _MainScreenState extends State<MainScreen> with WindowListener {
  int _currentIndex = 0;
  final _homeKey = GlobalKey<HomeScreenState>();

  bool get _isDesktop {
    try {
      return !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.windows ||
           defaultTargetPlatform == TargetPlatform.macOS ||
           defaultTargetPlatform == TargetPlatform.linux);
    } catch (_) {
      return false;
    }
  }

  late final _screens = [
    HomeScreen(key: _homeKey, onTabChange: (i) => setState(() => _currentIndex = i)),
    const TransactionListScreen(),
    const StatisticsScreen(),
    const AssetScreen(),
    const ProfileScreen(),
  ];

  static const _destinations = <NavigationDestination>[
    NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '首页'),
    NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: '账单'),
    NavigationDestination(icon: Icon(Icons.pie_chart_outline), selectedIcon: Icon(Icons.pie_chart), label: '统计'),
    NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: '资产'),
    NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '我的'),
  ];

  static const _railDestinations = <NavigationRailDestination>[
    NavigationRailDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: Text('首页')),
    NavigationRailDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: Text('账单')),
    NavigationRailDestination(icon: Icon(Icons.pie_chart_outline), selectedIcon: Icon(Icons.pie_chart), label: Text('统计')),
    NavigationRailDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: Text('资产')),
    NavigationRailDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: Text('我的')),
  ];

  @override
  void initState() {
    super.initState();
    if (_isDesktop) {
      windowManager.addListener(this);
    }
  }

  @override
  void dispose() {
    if (_isDesktop) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void onWindowClose() async {
    if (_isDesktop) {
      await windowManager.destroy();
    }
  }

  void _openSearch() {
    final provider = context.read<TransactionProvider>();
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider.value(
        value: provider,
        child: const SearchScreen(),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 600;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.digit1, control: true): () => setState(() => _currentIndex = 0),
        const SingleActivator(LogicalKeyboardKey.digit2, control: true): () => setState(() => _currentIndex = 1),
        const SingleActivator(LogicalKeyboardKey.digit3, control: true): () => setState(() => _currentIndex = 2),
        const SingleActivator(LogicalKeyboardKey.digit4, control: true): () => setState(() => _currentIndex = 3),
        const SingleActivator(LogicalKeyboardKey.digit5, control: true): () => setState(() => _currentIndex = 4),
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): _openSearch,
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () => _homeKey.currentState?.openAddTransaction(),
      },
      child: Scaffold(
        body: isWide
            ? Row(
                children: [
                  NavigationRail(
                    selectedIndex: _currentIndex,
                    onDestinationSelected: (i) => setState(() => _currentIndex = i),
                    labelType: NavigationRailLabelType.all,
                    destinations: _railDestinations,
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: IndexedStack(index: _currentIndex, children: _screens)),
                ],
              )
            : IndexedStack(index: _currentIndex, children: _screens),
        bottomNavigationBar: isWide
            ? null
            : NavigationBar(
                selectedIndex: _currentIndex,
                onDestinationSelected: (i) => setState(() => _currentIndex = i),
                destinations: _destinations,
              ),
      ),
    );
  }
}
