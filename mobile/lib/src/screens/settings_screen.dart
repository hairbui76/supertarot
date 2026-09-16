import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/settings_store.dart';
import '../l10n/strings.dart';
import '../theme.dart';
import '../widgets/neu.dart';
import '../widgets/update_section.dart';

/// Language, provider choice, retrieval depth, and the API keys the app uses
/// to call the vendors directly.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final SettingsStore settings = AppScope.settingsOf(context);
    final Strings strings = AppScope.stringsOf(context);
    final NeuTokens neu = context.neu;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      children: <Widget>[
        if (!settings.hasAnyKey) ...<Widget>[
          NeuBox(
            color: neu.red,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.vpn_key, color: neu.onAccent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    strings.noProviderWarning,
                    style: TextStyle(
                      color: neu.onAccent,
                      fontWeight: FontWeight.w700,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
        ],
        NeuHeading(
          icon: Icons.translate,
          title: strings.language,
          color: neu.blue,
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: _SegmentButton(
                label: 'Tiếng Việt',
                selected: settings.language == 'vi',
                onTap: () => settings.setLanguage('vi'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SegmentButton(
                label: 'English',
                selected: settings.language == 'en',
                onTap: () => settings.setLanguage('en'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),
        NeuHeading(
          icon: Icons.forum,
          title: strings.qaProvider,
          color: neu.violet,
        ),
        const SizedBox(height: 12),
        _ProviderPicker(
          value: settings.qaProvider,
          settings: settings,
          onChanged: settings.setQaProvider,
        ),
        const SizedBox(height: 26),
        NeuHeading(
          icon: Icons.fact_check,
          title: strings.gradingProvider,
          color: neu.green,
        ),
        const SizedBox(height: 12),
        _ProviderPicker(
          value: settings.gradingProvider,
          settings: settings,
          onChanged: settings.setGradingProvider,
        ),
        const SizedBox(height: 30),
        NeuHeading(
          icon: Icons.vpn_key,
          title: strings.apiKeys,
          color: neu.yellow,
        ),
        const SizedBox(height: 10),
        Text(
          strings.apiKeyHint,
          style: TextStyle(
            color: neu.line,
            fontWeight: FontWeight.w600,
            fontSize: 13,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 16),
        for (final LlmProvider provider in keyedProviders)
          _ProviderCard(
            // Keyed by provider: saving a key hides the warning banner above,
            // which shifts list positions. Without a key Flutter would rebind
            // each card's State - and its text controllers - to its neighbour.
            key: ValueKey<LlmProvider>(provider),
            provider: provider,
            settings: settings,
            strings: strings,
          ),
        const SizedBox(height: 14),
        NeuHeading(
          icon: Icons.tune,
          title: strings.retrievalDepth,
          color: neu.blue,
        ),
        const SizedBox(height: 12),
        _Stepper(
          label: strings.qaTopK,
          value: settings.qaTopK,
          onChanged: settings.setQaTopK,
        ),
        const SizedBox(height: 10),
        _Stepper(
          label: strings.answerTopK,
          value: settings.answerTopK,
          onChanged: settings.setAnswerTopK,
        ),
        const SizedBox(height: 30),
        const UpdateSection(),
        const SizedBox(height: 30),
        NeuHeading(
          icon: Icons.info,
          title: strings.about,
          color: neu.violet,
        ),
        const SizedBox(height: 10),
        Text(
          strings.aboutBody,
          style: TextStyle(
            color: neu.line,
            fontWeight: FontWeight.w600,
            fontSize: 13,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final NeuTokens neu = context.neu;
    return NeuBox(
      color: selected
          ? neu.blue
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      shadow: selected,
      padding: const EdgeInsets.symmetric(vertical: 12),
      alignment: Alignment.center,
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          color: neu.line,
          fontWeight: FontWeight.w900,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _ProviderPicker extends StatelessWidget {
  const _ProviderPicker({
    required this.value,
    required this.settings,
    required this.onChanged,
  });

  final LlmProvider value;
  final SettingsStore settings;
  final ValueChanged<LlmProvider> onChanged;

  @override
  Widget build(BuildContext context) {
    final NeuTokens neu = context.neu;
    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children: <Widget>[
        for (final LlmProvider provider in LlmProvider.values)
          NeuChip(
            label: providerLabels[provider]!,
            selected: provider == value,
            color: neu.violet,
            onTap: () => onChanged(provider),
            // A provider with no key would fail at call time; show that up
            // front rather than after the request.
            icon: provider != LlmProvider.auto && !settings.hasKey(provider)
                ? Icons.key_off
                : null,
          ),
      ],
    );
  }
}

class _ProviderCard extends StatefulWidget {
  const _ProviderCard({
    super.key,
    required this.provider,
    required this.settings,
    required this.strings,
  });

  final LlmProvider provider;
  final SettingsStore settings;
  final Strings strings;

  @override
  State<_ProviderCard> createState() => _ProviderCardState();
}

class _ProviderCardState extends State<_ProviderCard> {
  late final TextEditingController _key = TextEditingController(
    text: widget.settings.apiKey(widget.provider),
  );
  late final TextEditingController _model = TextEditingController(
    text: widget.settings.model(widget.provider),
  );
  bool _obscured = true;

  @override
  void dispose() {
    _key.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String key = _key.text.trim();
    await widget.settings.setApiKey(widget.provider, key);
    await widget.settings.setModel(widget.provider, _model.text.trim());
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          key.isEmpty ? widget.strings.keyCleared : widget.strings.keySaved,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final NeuTokens neu = context.neu;
    final bool stored = widget.settings.hasKey(widget.provider);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: NeuBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  providerLabels[widget.provider]!.toUpperCase(),
                  style: TextStyle(
                    color: neu.line,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(width: 10),
                if (stored)
                  NeuBox(
                    color: neu.green,
                    shadow: false,
                    borderWidth: 2,
                    radius: 999,
                    padding: const EdgeInsets.all(3),
                    child: Icon(Icons.check, size: 12, color: neu.onAccent),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            NeuField(
              controller: _key,
              labelText: widget.strings.apiKeyLabel,
              obscureText: _obscured,
              suffix: GestureDetector(
                onTap: () => setState(() => _obscured = !_obscured),
                child: Icon(
                  _obscured ? Icons.visibility : Icons.visibility_off,
                  size: 20,
                  color: neu.line,
                ),
              ),
            ),
            const SizedBox(height: 12),
            NeuField(
              controller: _model,
              labelText: widget.strings.model,
              hintText: defaultModels[widget.provider],
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: NeuButton(
                label: widget.strings.save,
                icon: Icons.save,
                expanded: false,
                onPressed: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A stepper instead of a slider: a Material slider's thin track and round
/// thumb are the opposite of this style, and the range is only 2..16 anyway.
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  static const int _min = 2;
  static const int _max = 16;

  @override
  Widget build(BuildContext context) {
    final NeuTokens neu = context.neu;

    return NeuBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: neu.line,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
          NeuIconButton(
            icon: Icons.remove,
            size: 36,
            onPressed: value > _min ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 44,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: neu.line,
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
          ),
          NeuIconButton(
            icon: Icons.add,
            size: 36,
            onPressed: value < _max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}
