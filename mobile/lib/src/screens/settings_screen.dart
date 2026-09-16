import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/settings_store.dart';
import '../l10n/strings.dart';

/// Language, provider choice, retrieval depth, and the API keys the app uses
/// to call the vendors directly.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final SettingsStore settings = AppScope.settingsOf(context);
    final Strings strings = AppScope.stringsOf(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      children: <Widget>[
        if (!settings.hasAnyKey)
          Card(
            color: Theme.of(context).colorScheme.tertiaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('🔑', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      strings.noProviderWarning,
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onTertiaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 20),
        _SettingsHeading(strings.language),
        SegmentedButton<String>(
          segments: const <ButtonSegment<String>>[
            ButtonSegment<String>(value: 'vi', label: Text('Tiếng Việt')),
            ButtonSegment<String>(value: 'en', label: Text('English')),
          ],
          selected: <String>{settings.language},
          onSelectionChanged: (Set<String> value) =>
              settings.setLanguage(value.first),
        ),
        const SizedBox(height: 28),
        _SettingsHeading(strings.qaProvider),
        _ProviderPicker(
          value: settings.qaProvider,
          settings: settings,
          onChanged: settings.setQaProvider,
        ),
        const SizedBox(height: 24),
        _SettingsHeading(strings.gradingProvider),
        _ProviderPicker(
          value: settings.gradingProvider,
          settings: settings,
          onChanged: settings.setGradingProvider,
        ),
        const SizedBox(height: 28),
        _SettingsHeading(strings.apiKeys),
        Text(
          strings.apiKeyHint,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
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
        const SizedBox(height: 20),
        _SettingsHeading(strings.retrievalDepth),
        _TopKSlider(
          label: strings.qaTopK,
          value: settings.qaTopK,
          onChanged: settings.setQaTopK,
        ),
        _TopKSlider(
          label: strings.answerTopK,
          value: settings.answerTopK,
          onChanged: settings.setAnswerTopK,
        ),
        const SizedBox(height: 28),
        _SettingsHeading(strings.about),
        Text(
          strings.aboutBody,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _SettingsHeading extends StatelessWidget {
  const _SettingsHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary,
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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final LlmProvider provider in LlmProvider.values)
          ChoiceChip(
            label: Text(providerLabels[provider]!),
            selected: provider == value,
            onSelected: (_) => onChanged(provider),
            // A provider with no key would fail at call time; show that up
            // front rather than after the request.
            avatar: provider != LlmProvider.auto && !settings.hasKey(provider)
                ? const Icon(Icons.key_off_outlined, size: 16)
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
    final bool stored = widget.settings.hasKey(widget.provider);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    providerLabels[widget.provider]!,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 8),
                  if (stored)
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _key,
                obscureText: _obscured,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: widget.strings.apiKeyLabel,
                  suffixIcon: IconButton(
                    icon: Icon(_obscured
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscured = !_obscured),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _model,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: widget.strings.model,
                  hintText: defaultModels[widget.provider],
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  onPressed: _save,
                  child: Text(widget.strings.save),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopKSlider extends StatelessWidget {
  const _TopKSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(width: 90, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: 2,
            max: 16,
            divisions: 14,
            label: '$value',
            onChanged: (double next) => onChanged(next.round()),
          ),
        ),
        SizedBox(width: 28, child: Text('$value')),
      ],
    );
  }
}
