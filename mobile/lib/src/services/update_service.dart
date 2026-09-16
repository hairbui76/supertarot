import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// The GitHub repository releases are published to.
const String kReleaseRepo = 'hairbui76/supertarot';

/// A semantic version, compared numerically rather than as a string so that
/// 1.10.0 sorts above 1.9.0.
@immutable
class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.major, this.minor, this.patch);

  /// Accepts `1.2.3`, `v1.2.3` and `1.2.3+45`; anything unparseable is null.
  static AppVersion? tryParse(String? raw) {
    if (raw == null) {
      return null;
    }
    final RegExpMatch? match =
        RegExp(r'(\d+)\.(\d+)\.(\d+)').firstMatch(raw.trim());
    if (match == null) {
      return null;
    }
    return AppVersion(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  final int major;
  final int minor;
  final int patch;

  @override
  int compareTo(AppVersion other) {
    if (major != other.major) {
      return major.compareTo(other.major);
    }
    if (minor != other.minor) {
      return minor.compareTo(other.minor);
    }
    return patch.compareTo(other.patch);
  }

  @override
  String toString() => '$major.$minor.$patch';

  @override
  bool operator ==(Object other) =>
      other is AppVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch);
}

/// What a check found. [asset] is null when a release exists but ships no APK
/// this device can install.
@immutable
class UpdateCheck {
  const UpdateCheck({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseNotes,
    required this.releaseUrl,
    this.asset,
  });

  final AppVersion currentVersion;
  final AppVersion latestVersion;
  final String releaseNotes;
  final String releaseUrl;
  final ReleaseAsset? asset;

  bool get isUpdateAvailable => latestVersion.compareTo(currentVersion) > 0;
}

@immutable
class ReleaseAsset {
  const ReleaseAsset({
    required this.name,
    required this.downloadUrl,
    required this.sizeBytes,
  });

  final String name;
  final String downloadUrl;
  final int sizeBytes;

  String get sizeLabel => '${(sizeBytes / 1024 / 1024).toStringAsFixed(1)} MB';
}

class UpdateException implements Exception {
  UpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Checks GitHub Releases for a newer APK and hands it to the system
/// installer.
///
/// The app is sideloaded rather than shipped through a store, so there is no
/// update channel unless it provides one. Downloaded APKs are signed with the
/// same release key as the installed build, which is what lets Android treat
/// them as an upgrade rather than refusing the install.
class UpdateService {
  UpdateService({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final http.Client _http;

  Future<UpdateCheck> check() async {
    final PackageInfo info = await PackageInfo.fromPlatform();
    final AppVersion? current = AppVersion.tryParse(info.version);
    if (current == null) {
      throw UpdateException('Could not read the installed version.');
    }

    final http.Response response;
    try {
      response = await _http.get(
        Uri.parse('https://api.github.com/repos/$kReleaseRepo/releases/latest'),
        headers: const <String, String>{
          'Accept': 'application/vnd.github+json',
        },
      ).timeout(const Duration(seconds: 30));
    } on Exception catch (error) {
      throw UpdateException('Could not reach GitHub: $error');
    }

    if (response.statusCode == 404) {
      throw UpdateException('No published release found for $kReleaseRepo.');
    }
    if (response.statusCode >= 400) {
      throw UpdateException(
        'GitHub returned ${response.statusCode}. '
        'Unauthenticated API calls are rate limited to 60 per hour.',
      );
    }

    final Map<String, dynamic> body =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final AppVersion? latest = AppVersion.tryParse(body['tag_name'] as String?);
    if (latest == null) {
      throw UpdateException('Could not read the release tag.');
    }

    return UpdateCheck(
      currentVersion: current,
      latestVersion: latest,
      releaseNotes: (body['body'] as String? ?? '').trim(),
      releaseUrl: body['html_url'] as String? ??
          'https://github.com/$kReleaseRepo/releases',
      asset: await _pickAsset(body['assets'] as List<dynamic>? ?? const []),
    );
  }

  /// Releases carry one APK per ABI. Pick the first that this device supports,
  /// in the order the device itself prefers.
  Future<ReleaseAsset?> _pickAsset(List<dynamic> assets) async {
    final List<ReleaseAsset> apks = <ReleaseAsset>[
      for (final dynamic item in assets)
        if ((item as Map<String, dynamic>)['name']
                .toString()
                .toLowerCase()
                .endsWith('.apk') &&
            item['browser_download_url'] is String)
          ReleaseAsset(
            name: item['name'] as String,
            downloadUrl: item['browser_download_url'] as String,
            sizeBytes: (item['size'] as num?)?.toInt() ?? 0,
          ),
    ];
    if (apks.isEmpty) {
      return null;
    }

    for (final String abi in await _supportedAbis()) {
      for (final ReleaseAsset apk in apks) {
        if (apk.name.toLowerCase().contains(abi.toLowerCase())) {
          return apk;
        }
      }
    }

    // A universal APK names no ABI at all; fall back to it before giving up.
    for (final ReleaseAsset apk in apks) {
      if (!RegExp(r'(arm64-v8a|armeabi-v7a|x86_64|x86)')
          .hasMatch(apk.name.toLowerCase())) {
        return apk;
      }
    }
    return null;
  }

  Future<List<String>> _supportedAbis() async {
    if (!Platform.isAndroid) {
      return const <String>[];
    }
    try {
      final AndroidDeviceInfo android = await DeviceInfoPlugin().androidInfo;
      return android.supportedAbis;
    } on Exception catch (error) {
      debugPrint('Could not read supported ABIs: $error');
      return const <String>[];
    }
  }

  /// Downloads [asset] and opens it with the system package installer.
  ///
  /// Android will show its own confirmation screen, and will refuse the
  /// install unless the user has granted this app permission to install
  /// unknown apps.
  Future<void> downloadAndInstall(
    ReleaseAsset asset, {
    void Function(double progress)? onProgress,
  }) async {
    final Directory directory = await getTemporaryDirectory();
    final File file = File('${directory.path}/${asset.name}');

    try {
      final http.StreamedResponse response = await _http
          .send(http.Request('GET', Uri.parse(asset.downloadUrl)))
          .timeout(const Duration(minutes: 10));

      if (response.statusCode >= 400) {
        throw UpdateException('Download failed: HTTP ${response.statusCode}');
      }

      final int total = response.contentLength ?? asset.sizeBytes;
      int received = 0;
      final IOSink sink = file.openWrite();
      try {
        await for (final List<int> chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) {
            onProgress?.call(received / total);
          }
        }
      } finally {
        await sink.close();
      }
    } on UpdateException {
      rethrow;
    } on Exception catch (error) {
      throw UpdateException('Download failed: $error');
    }

    final OpenResult result = await OpenFilex.open(
      file.path,
      type: 'application/vnd.android.package-archive',
    );
    if (result.type != ResultType.done) {
      throw UpdateException(
        'Could not open the installer: ${result.message}. '
        'Allow this app to install unknown apps, then try again.',
      );
    }
  }
}

/// release-please writes the notes as Markdown with compare links and
/// commit hashes. Strip that down to plain lines: the card is a summary,
/// and the full changelog lives on the release page.
String formatReleaseNotes(String notes) {
  final RegExp link = RegExp(r'\[([^\]]+)\]\([^)]*\)');
  final RegExp heading = RegExp(r'^\s{0,3}#{1,6}\s+(.*)$');
  final RegExp commitRef = RegExp(r'\s*\(\s*[0-9a-f]{7,40}\s*\)');
  final RegExp bullet = RegExp(r'^\s*[*-]\s+');
  final RegExp versionHeading = RegExp(r'^\d+\.\d+\.\d+');

  final List<String> out = <String>[];
  for (String raw in notes.split('\n')) {
    String line = raw.trim().replaceAllMapped(
      link,
      (Match match) => match.group(1)!,
    );
    line = line.replaceAll(commitRef, '').replaceAll('**', '').trim();
    if (line.isEmpty) {
      continue;
    }

    final RegExpMatch? headingMatch = heading.firstMatch(line);
    if (headingMatch != null) {
      final String title = headingMatch.group(1)!.trim();
      // The top heading just repeats the version shown above the notes.
      if (versionHeading.hasMatch(title)) {
        continue;
      }
      out.add(title);
      continue;
    }

    out.add(line.replaceFirst(bullet, '• '));
  }

  final List<String> kept = out.take(8).toList();
  if (out.length > kept.length) {
    kept.add('…');
  }
  return kept.join('\n');
}
