import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../app_scope.dart';
import '../l10n/strings.dart';
import '../services/update_service.dart';
import '../theme.dart';
import 'neu.dart';

/// Installed version, a check button, and the download/install flow.
///
/// The app is sideloaded from GitHub Releases rather than a store, so this is
/// the only update path it has.
class UpdateSection extends StatefulWidget {
  const UpdateSection({super.key});

  @override
  State<UpdateSection> createState() => _UpdateSectionState();
}

class _UpdateSectionState extends State<UpdateSection> {
  String _installedVersion = '';
  UpdateCheck? _result;
  bool _checking = false;
  bool _downloading = false;
  double _progress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInstalledVersion();
  }

  Future<void> _loadInstalledVersion() async {
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _installedVersion = info.version);
      }
    } on Exception catch (error) {
      // A missing plugin (widget tests, desktop) must not break the screen.
      debugPrint('Could not read package info: $error');
    }
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _error = null;
      _result = null;
    });

    try {
      final UpdateCheck check = await AppScope.of(context).updates.check();
      if (mounted) {
        setState(() {
          _result = check;
          _checking = false;
        });
      }
    } on UpdateException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _checking = false;
        });
      }
    }
  }

  Future<void> _install(ReleaseAsset asset) async {
    setState(() {
      _downloading = true;
      _progress = 0;
      _error = null;
    });

    try {
      await AppScope.of(context).updates.downloadAndInstall(
        asset,
        onProgress: (double value) {
          if (mounted) {
            setState(() => _progress = value);
          }
        },
      );
    } on UpdateException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _downloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Strings strings = AppScope.stringsOf(context);
    final NeuTokens neu = context.neu;
    final UpdateCheck? result = _result;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        NeuHeading(
          icon: Icons.system_update,
          title: strings.updates,
          color: neu.green,
        ),
        const SizedBox(height: 12),
        if (_installedVersion.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: NeuChip(
              label: '${strings.currentVersion}: $_installedVersion',
              icon: Icons.verified,
            ),
          ),
        const SizedBox(height: 12),
        NeuButton(
          label: _checking ? strings.checking : strings.checkForUpdates,
          icon: Icons.refresh,
          color: neu.green,
          busy: _checking,
          onPressed: _checking || _downloading ? null : _check,
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: 12),
          _Banner(icon: Icons.error_outline, text: _error!, color: neu.red),
        ],
        if (result != null) ...<Widget>[
          const SizedBox(height: 12),
          if (!result.isUpdateAvailable)
            _Banner(
              icon: Icons.check_circle,
              text: strings.upToDate,
              color: neu.green,
            )
          else
            _UpdateCard(
              result: result,
              strings: strings,
              downloading: _downloading,
              progress: _progress,
              onInstall: _install,
            ),
        ],
      ],
    );
  }
}

class _UpdateCard extends StatelessWidget {
  const _UpdateCard({
    required this.result,
    required this.strings,
    required this.downloading,
    required this.progress,
    required this.onInstall,
  });

  final UpdateCheck result;
  final Strings strings;
  final bool downloading;
  final double progress;
  final ValueChanged<ReleaseAsset> onInstall;

  @override
  Widget build(BuildContext context) {
    final NeuTokens neu = context.neu;
    final ReleaseAsset? asset = result.asset;

    return NeuBox(
      color: neu.yellow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.new_releases, color: neu.onAccent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  strings.versionAvailable(result.latestVersion.toString()),
                  style: TextStyle(
                    color: neu.onAccent,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          if (result.releaseNotes.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            Text(
              strings.releaseNotes.toUpperCase(),
              style: TextStyle(
                color: neu.onAccent,
                fontWeight: FontWeight.w900,
                fontSize: 11,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              formatReleaseNotes(result.releaseNotes),
              style: TextStyle(
                color: neu.onAccent,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (asset == null)
            Text(
              strings.updateNoAsset,
              style: TextStyle(
                color: neu.onAccent,
                fontWeight: FontWeight.w700,
              ),
            )
          else ...<Widget>[
            if (downloading) ...<Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: neu.line, width: 2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: LinearProgressIndicator(
                    value: progress == 0 ? null : progress,
                    minHeight: 12,
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    color: neu.green,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            NeuButton(
              label: downloading
                  ? '${strings.downloading} ${(progress * 100).round()}%'
                  : '${strings.downloadAndInstall} · ${asset.sizeLabel}',
              icon: Icons.download,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              busy: downloading,
              onPressed: downloading ? null : () => onInstall(asset),
            ),
            const SizedBox(height: 10),
            Text(
              strings.installHint,
              style: TextStyle(
                color: neu.onAccent,
                fontWeight: FontWeight.w600,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final NeuTokens neu = context.neu;
    return NeuBox(
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: neu.onAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: neu.onAccent,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
