import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Supported LLM vendors. `auto` picks the first one that has a key, in the
/// same order as `resolve_llm_provider()` in `app/llm.py`.
enum LlmProvider { auto, openai, anthropic, google }

extension LlmProviderId on LlmProvider {
  String get id => name;

  static LlmProvider parse(String? value) {
    return LlmProvider.values.firstWhere(
      (LlmProvider provider) => provider.name == value,
      orElse: () => LlmProvider.auto,
    );
  }
}

const List<LlmProvider> keyedProviders = <LlmProvider>[
  LlmProvider.openai,
  LlmProvider.anthropic,
  LlmProvider.google,
];

const Map<LlmProvider, String> defaultModels = <LlmProvider, String>{
  LlmProvider.openai: 'gpt-4.1-mini',
  LlmProvider.anthropic: 'claude-haiku-4-5-20251001',
  LlmProvider.google: 'gemini-2.5-flash',
};

const Map<LlmProvider, String> providerLabels = <LlmProvider, String>{
  LlmProvider.auto: 'Auto',
  LlmProvider.openai: 'OpenAI',
  LlmProvider.anthropic: 'Anthropic',
  LlmProvider.google: 'Google Gemini',
};

/// App preferences plus the user-entered API keys.
///
/// Keys go to `flutter_secure_storage` (Android Keystore-backed encrypted
/// preferences); everything else is ordinary shared preferences.
class SettingsStore extends ChangeNotifier {
  SettingsStore._(this._prefs, this._secure, this._apiKeys);

  static const String _languageKey = 'language';
  static const String _qaProviderKey = 'qa_provider';
  static const String _gradingProviderKey = 'grading_provider';
  static const String _modelPrefix = 'model_';
  static const String _qaTopKKey = 'qa_top_k';
  static const String _answerTopKKey = 'answer_top_k';
  static const String _apiKeyPrefix = 'api_key_';
  static const String _gridColumnsKey = 'grid_columns';

  /// How many cards the browse grid shows per row. Pinch-to-zoom moves
  /// within this range.
  static const int minGridColumns = 1;
  static const int maxGridColumns = 5;

  static Future<SettingsStore> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    const FlutterSecureStorage secure = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );

    final Map<LlmProvider, String> keys = <LlmProvider, String>{};
    for (final LlmProvider provider in keyedProviders) {
      try {
        keys[provider] =
            await secure.read(key: '$_apiKeyPrefix${provider.id}') ?? '';
      } on Exception catch (error) {
        // A corrupted keystore entry must not block app start; the user can
        // simply re-enter the key.
        debugPrint('Could not read stored key for ${provider.id}: $error');
        keys[provider] = '';
      }
    }

    return SettingsStore._(prefs, secure, keys);
  }

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;
  final Map<LlmProvider, String> _apiKeys;

  int get gridColumns =>
      (_prefs.getInt(_gridColumnsKey) ?? 2)
          .clamp(minGridColumns, maxGridColumns);

  Future<void> setGridColumns(int value) async {
    final int next = value.clamp(minGridColumns, maxGridColumns);
    if (next == gridColumns) {
      return;
    }
    await _prefs.setInt(_gridColumnsKey, next);
    notifyListeners();
  }

  String get language => _prefs.getString(_languageKey) ?? 'vi';

  Future<void> setLanguage(String value) async {
    await _prefs.setString(_languageKey, value);
    notifyListeners();
  }

  LlmProvider get qaProvider =>
      LlmProviderId.parse(_prefs.getString(_qaProviderKey));

  Future<void> setQaProvider(LlmProvider value) async {
    await _prefs.setString(_qaProviderKey, value.id);
    notifyListeners();
  }

  LlmProvider get gradingProvider =>
      LlmProviderId.parse(_prefs.getString(_gradingProviderKey));

  Future<void> setGradingProvider(LlmProvider value) async {
    await _prefs.setString(_gradingProviderKey, value.id);
    notifyListeners();
  }

  String model(LlmProvider provider) {
    final String stored = _prefs.getString('$_modelPrefix${provider.id}') ?? '';
    return stored.isNotEmpty ? stored : defaultModels[provider] ?? '';
  }

  Future<void> setModel(LlmProvider provider, String value) async {
    await _prefs.setString('$_modelPrefix${provider.id}', value.trim());
    notifyListeners();
  }

  int get qaTopK => _prefs.getInt(_qaTopKKey) ?? 8;

  Future<void> setQaTopK(int value) async {
    await _prefs.setInt(_qaTopKKey, value.clamp(1, 20));
    notifyListeners();
  }

  int get answerTopK => _prefs.getInt(_answerTopKKey) ?? 6;

  Future<void> setAnswerTopK(int value) async {
    await _prefs.setInt(_answerTopKKey, value.clamp(1, 20));
    notifyListeners();
  }

  String apiKey(LlmProvider provider) => _apiKeys[provider] ?? '';

  bool hasKey(LlmProvider provider) => apiKey(provider).isNotEmpty;

  bool get hasAnyKey => keyedProviders.any(hasKey);

  Future<void> setApiKey(LlmProvider provider, String value) async {
    final String trimmed = value.trim();
    _apiKeys[provider] = trimmed;
    final String storageKey = '$_apiKeyPrefix${provider.id}';
    if (trimmed.isEmpty) {
      await _secure.delete(key: storageKey);
    } else {
      await _secure.write(key: storageKey, value: trimmed);
    }
    notifyListeners();
  }

  /// Resolves `auto` to the first provider holding a key, mirroring
  /// `resolve_llm_provider()`. Returns null when nothing is configured.
  LlmProvider? resolveProvider(LlmProvider requested) {
    if (requested != LlmProvider.auto) {
      return hasKey(requested) ? requested : null;
    }
    for (final LlmProvider provider in keyedProviders) {
      if (hasKey(provider)) {
        return provider;
      }
    }
    return null;
  }
}
