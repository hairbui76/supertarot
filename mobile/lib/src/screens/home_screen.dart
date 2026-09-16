import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../l10n/strings.dart';
import 'ask_screen.dart';
import 'browse_screen.dart';
import 'settings_screen.dart';
import 'study_screen.dart';

/// Four-tab shell. Each tab keeps its own state while switching, so a
/// half-typed answer or a Q&A thread survives a trip to Settings.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final Strings strings = AppScope.stringsOf(context);
    final List<String> titles = <String>[
      strings.tabBrowse,
      strings.tabStudy,
      strings.tabAsk,
      strings.tabSettings,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: <Widget>[
            Text(strings.appTitle),
            const SizedBox(width: 10),
            Text(
              '· ${titles[_index]}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: _index,
        children: const <Widget>[
          BrowseScreen(),
          StudyScreen(),
          AskScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int next) => setState(() => _index = next),
        destinations: <NavigationDestination>[
          NavigationDestination(
            icon: const Icon(Icons.auto_stories_outlined),
            selectedIcon: const Icon(Icons.auto_stories),
            label: strings.tabBrowse,
          ),
          NavigationDestination(
            icon: const Icon(Icons.school_outlined),
            selectedIcon: const Icon(Icons.school),
            label: strings.tabStudy,
          ),
          NavigationDestination(
            icon: const Icon(Icons.chat_bubble_outline),
            selectedIcon: const Icon(Icons.chat_bubble),
            label: strings.tabAsk,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: strings.tabSettings,
          ),
        ],
      ),
    );
  }
}
