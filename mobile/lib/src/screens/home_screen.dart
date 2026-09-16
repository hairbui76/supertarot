import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../l10n/strings.dart';
import '../theme.dart';
import '../widgets/neu.dart';
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
    final NeuTokens neu = context.neu;

    final List<_Destination> destinations = <_Destination>[
      _Destination(Icons.auto_stories, strings.tabBrowse, neu.violet),
      _Destination(Icons.school, strings.tabStudy, neu.red),
      _Destination(Icons.forum, strings.tabAsk, neu.blue),
      _Destination(Icons.settings, strings.tabSettings, neu.green),
    ];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: <Widget>[
            // The launcher icon, reused as the wordmark logo. cacheWidth keeps
            // the 1254px source from being decoded at full size for a 26px tile.
            NeuBox(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              shadow: false,
              borderWidth: 2,
              radius: 6,
              padding: const EdgeInsets.all(3),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.asset(
                  'icon/app_icon.png',
                  width: 28,
                  height: 28,
                  cacheWidth: 112,
                  errorBuilder: (_, __, ___) => const SizedBox(width: 28),
                ),
              ),
            ),
            const SizedBox(width: 8),
            NeuBox(
              color: neu.yellow,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Text(
                'SUPERTAROT',
                style: TextStyle(
                  color: neu.onAccent,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                destinations[_index].label.toUpperCase(),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: neu.line,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ],
        ),
        // The hard rule under the bar replaces Material's blurred scroll
        // shadow, which the style does not allow.
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Container(height: 3, color: neu.line),
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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(top: BorderSide(color: neu.line, width: 3)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: <Widget>[
                for (int i = 0; i < destinations.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _NavItem(
                      destination: destinations[i],
                      selected: _index == i,
                      onTap: () => setState(() => _index = i),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Destination {
  const _Destination(this.icon, this.label, this.accent);

  final IconData icon;
  final String label;
  final Color accent;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final NeuTokens neu = context.neu;

    return NeuBox(
      color: selected
          ? destination.accent
          : Theme.of(context).colorScheme.surface,
      shadow: selected,
      borderWidth: selected ? 3 : 2,
      padding: const EdgeInsets.symmetric(vertical: 8),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(destination.icon, size: 20, color: neu.line),
          const SizedBox(height: 3),
          Text(
            destination.label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: neu.line,
              fontWeight: FontWeight.w900,
              fontSize: 9.5,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
