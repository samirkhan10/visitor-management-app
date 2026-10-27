import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/visitor_provider.dart';

import 'dashboard/dashboard_screen.dart';
import 'scanner/scanner_screen.dart';
import 'visitors/visitor_list_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentTab = 0;

  void _openTab(int index) {
    if (index == _currentTab) return;
    setState(() => _currentTab = index);
  }

  @override
  Widget build(BuildContext context) {
    // Tabs are built on demand so the camera only runs while the Scan tab is open.
    final Widget page = switch (_currentTab) {
      1 => VisitorListScreen(onOpenScanner: () => _openTab(2)),
      2 => const ScannerScreen(),
      _ => DashboardScreen(onOpenTab: _openTab),
    };

    final checkedInCount = context.select<VisitorProvider, int>((p) => p.currentlyCheckedIn);

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOut,
        child: KeyedSubtree(key: ValueKey(_currentTab), child: page),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab,
        onDestinationSelected: _openTab,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            // Badge shows how many visitors are inside right now.
            icon: Badge(
              isLabelVisible: checkedInCount > 0,
              label: Text('$checkedInCount'),
              child: const Icon(Icons.people_alt_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: checkedInCount > 0,
              label: Text('$checkedInCount'),
              child: const Icon(Icons.people_alt_rounded),
            ),
            label: 'Visitors',
          ),
          const NavigationDestination(icon: Icon(Icons.qr_code_scanner_rounded), label: 'Scan'),
        ],
      ),
    );
  }
}
