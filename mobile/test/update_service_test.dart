import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supertarot_mobile/src/services/update_service.dart';

/// The in-app updater is the only update path for a sideloaded app, so a bad
/// version comparison would silently strand users on an old build.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppVersion', () {
    test('parses bare, tagged and build-suffixed versions', () {
      expect(AppVersion.tryParse('1.2.3').toString(), '1.2.3');
      expect(AppVersion.tryParse('v1.2.3').toString(), '1.2.3');
      expect(AppVersion.tryParse('1.2.3+45').toString(), '1.2.3');
      expect(AppVersion.tryParse('  v0.0.1 ').toString(), '0.0.1');
    });

    test('returns null for unparseable input', () {
      expect(AppVersion.tryParse(null), isNull);
      expect(AppVersion.tryParse(''), isNull);
      expect(AppVersion.tryParse('latest'), isNull);
    });

    test('compares numerically, not as strings', () {
      // The trap: '1.10.0'.compareTo('1.9.0') is negative as a string.
      expect(
        AppVersion.tryParse('1.10.0')!.compareTo(AppVersion.tryParse('1.9.0')!),
        greaterThan(0),
      );
      expect(
        AppVersion.tryParse('2.0.0')!
            .compareTo(AppVersion.tryParse('1.99.99')!),
        greaterThan(0),
      );
      expect(
        AppVersion.tryParse('1.0.10')!.compareTo(AppVersion.tryParse('1.0.9')!),
        greaterThan(0),
      );
      expect(AppVersion.tryParse('1.2.3'), AppVersion.tryParse('v1.2.3'));
    });
  });

  group('UpdateService.check', () {
    setUp(() {
      PackageInfo.setMockInitialValues(
        appName: 'SuperTarot',
        packageName: 'co.astravision.supertarot',
        version: '1.0.0',
        buildNumber: '100000000',
        buildSignature: '',
      );
    });

    UpdateService serviceReturning(
      Map<String, dynamic> body, {
      int status = 200,
    }) {
      return UpdateService(
        httpClient: MockClient(
          (http.Request request) async => http.Response.bytes(
            utf8.encode(jsonEncode(body)),
            status,
            headers: <String, String>{
              'content-type': 'application/json; charset=utf-8',
            },
          ),
        ),
      );
    }

    test('reports an update when the release tag is newer', () async {
      final UpdateCheck result = await serviceReturning(<String, dynamic>{
        'tag_name': 'v1.1.0',
        'body': 'Features',
        'html_url': 'https://example.invalid/v1.1.0',
        'assets': <dynamic>[],
      }).check();

      expect(result.currentVersion.toString(), '1.0.0');
      expect(result.latestVersion.toString(), '1.1.0');
      expect(result.isUpdateAvailable, isTrue);
      expect(result.releaseNotes, 'Features');
    });

    test('reports no update when the tag matches the installed build',
        () async {
      final UpdateCheck result = await serviceReturning(<String, dynamic>{
        'tag_name': 'v1.0.0',
        'assets': <dynamic>[],
      }).check();

      expect(result.isUpdateAvailable, isFalse);
    });

    test('never offers a downgrade', () async {
      final UpdateCheck result = await serviceReturning(<String, dynamic>{
        'tag_name': 'v0.9.0',
        'assets': <dynamic>[],
      }).check();

      expect(result.isUpdateAvailable, isFalse);
    });

    test('does not offer an APK built for another architecture', () async {
      final UpdateCheck result = await serviceReturning(<String, dynamic>{
        'tag_name': 'v1.1.0',
        'assets': <dynamic>[
          <String, dynamic>{
            'name': 'supertarot-1.1.0-arm64-v8a.apk',
            'browser_download_url': 'https://example.invalid/arm64.apk',
            'size': 26835690,
          },
        ],
      }).check();

      // Tests run off-device, so no ABI matches and the ABI-named APK is
      // correctly rejected rather than handed to the wrong architecture.
      expect(result.asset, isNull);
    });

    test('falls back to a universal APK that names no ABI', () async {
      final UpdateCheck result = await serviceReturning(<String, dynamic>{
        'tag_name': 'v1.1.0',
        'assets': <dynamic>[
          <String, dynamic>{
            'name': 'supertarot-1.1.0.apk',
            'browser_download_url': 'https://example.invalid/universal.apk',
            'size': 59753844,
          },
        ],
      }).check();

      expect(result.asset?.name, 'supertarot-1.1.0.apk');
      expect(result.asset?.sizeLabel, '57.0 MB');
    });

    test('ignores non-APK assets', () async {
      final UpdateCheck result = await serviceReturning(<String, dynamic>{
        'tag_name': 'v1.1.0',
        'assets': <dynamic>[
          <String, dynamic>{
            'name': 'checksums.txt',
            'browser_download_url': 'https://example.invalid/checksums.txt',
            'size': 120,
          },
        ],
      }).check();

      expect(result.asset, isNull);
    });

    test('surfaces a rate limit as a readable message', () async {
      await expectLater(
        serviceReturning(
          <String, dynamic>{'message': 'rate limited'},
          status: 403,
        ).check(),
        throwsA(
          isA<UpdateException>().having(
            (UpdateException e) => e.message,
            'message',
            contains('rate limited'),
          ),
        ),
      );
    });

    test('explains a repository with no releases', () async {
      await expectLater(
        serviceReturning(<String, dynamic>{}, status: 404).check(),
        throwsA(
          isA<UpdateException>().having(
            (UpdateException e) => e.message,
            'message',
            contains('No published release'),
          ),
        ),
      );
    });

    test('rejects a release whose tag is not a version', () async {
      await expectLater(
        serviceReturning(<String, dynamic>{'tag_name': 'nightly'}).check(),
        throwsA(isA<UpdateException>()),
      );
    });
  });

  group('formatReleaseNotes', () {
    test('strips the Markdown release-please generates', () {
      final String raw = <String>[
        '## [1.1.0](https://github.com/a/b/compare/v1.0.0...v1.1.0) '
            '(2026-09-16)',
        '',
        '',
        '### Features',
        '',
        '* **mobile:** zoom grid and neubrutalist UI '
            '([7e7b9ab](https://github.com/a/b/commit/7e7b9ab))',
      ].join('\n');

      expect(
        formatReleaseNotes(raw),
        <String>[
          'Features',
          '• mobile: zoom grid and neubrutalist UI',
        ].join('\n'),
      );
    });

    test('caps long changelogs with an ellipsis', () {
      final String raw =
          List<String>.generate(20, (int i) => '* item $i').join('\n');
      final List<String> lines = formatReleaseNotes(raw).split('\n');

      expect(lines, hasLength(9));
      expect(lines.first, '• item 0');
      expect(lines.last, '…');
    });

    test('returns nothing for empty notes', () {
      expect(formatReleaseNotes(''), '');
      expect(formatReleaseNotes('\n\n  \n'), '');
    });
  });
}
