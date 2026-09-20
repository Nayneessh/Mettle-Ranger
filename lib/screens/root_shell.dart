import 'package:flutter/material.dart';

import 'body/body_screen.dart';
import 'footage/footage_screen.dart';
import 'history/history_screen.dart';
import 'progress/progress_screen.dart';
import 'today/today_screen.dart';

/// The five-tab shell: Today, Footage, Progress, History, Body. Setup,
/// Player, Recap, Clip review, Programme, Movements and Settings are all
/// pushed on top of this, outside the tab bar — they never become a
/// destination here.
///
/// Today replaces the original Train tab (redesigned per the Winter Arc
/// reference); Progress is history-scoped now, not the plain original;
/// History and Body are new. Footage stays a tab even though the reference
/// app has no equivalent — on-camera footage review is this app's own
/// differentiator (spec §2), not something the redesign asked to remove.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  static const _screens = [
    TodayScreen(),
    FootageScreen(),
    ProgressScreen(),
    HistoryScreen(),
    BodyScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.bolt_outlined),
            selectedIcon: Icon(Icons.bolt),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.video_library_outlined),
            selectedIcon: Icon(Icons.video_library),
            label: 'Footage',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Progress',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.accessibility_new_outlined),
            selectedIcon: Icon(Icons.accessibility_new),
            label: 'Body',
          ),
        ],
      ),
    );
  }
}
