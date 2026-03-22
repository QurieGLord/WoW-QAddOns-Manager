import 'package:flutter_test/flutter_test.dart';
import 'package:wow_qaddons_manager/data/network/wowskill_provider.dart';

void main() {
  group('Wowskill retail version gating', () {
    final provider = WowskillProvider();

    test('rejects retail candidates that only mention older branches', () {
      expect(
        provider.debugMatchesRequestedVersion(
          title: 'ElvUI 10.2.7 / 3.4.3 addon download',
          url: 'https://wowskill.ru/elvui-10-2-7/',
          gameVersion: '11.1.5',
        ),
        isFalse,
      );
    });

    test(
      'allows retail candidates with explicit same-major branch evidence',
      () {
        expect(
          provider.debugMatchesRequestedVersion(
            title: 'ElvUI addon for WoW',
            url: 'https://wowskill.ru/elvui-11-0/',
            gameVersion: '11.1.5',
          ),
          isTrue,
        );
      },
    );

    test('rejects retail candidates without any version markers', () {
      expect(
        provider.debugMatchesRequestedVersion(
          title: 'ElvUI addon download',
          url: 'https://wowskill.ru/elvui/',
          gameVersion: '11.1.5',
        ),
        isFalse,
      );
    });

    test('rejects generic retail markers without major-family evidence', () {
      expect(
        provider.debugMatchesRequestedVersion(
          title: 'ElvUI retail addon download',
          url: 'https://wowskill.ru/elvui-retail/',
          gameVersion: '11.1.5',
        ),
        isFalse,
      );
    });

    test(
      'rejects retail download entries that only mention older branches',
      () {
        expect(
          provider.debugScoreDownloadEntry(
            gameVersion: '11.1.5',
            detailTitle: 'ElvUI for WoW 10.2.7 and 3.4.3',
            detailSummary: 'Supports Dragonflight and Wrath Classic',
            url: 'https://downloads.example.com/elvui-10-2-7.zip',
            anchorText: 'Download ElvUI 10.2.7',
            contextText: 'Dragonflight release',
            versionLabel: '10.2.7',
          ),
          0,
        );
      },
    );

    test('rejects retail download entries without any branch evidence', () {
      expect(
        provider.debugScoreDownloadEntry(
          gameVersion: '11.1.5',
          detailTitle: 'ElvUI addon',
          detailSummary: 'UI replacement for retail WoW',
          url: 'https://downloads.example.com/elvui.zip',
          anchorText: 'Download',
          contextText: 'Latest archive',
        ),
        0,
      );
    });

    test('allows retail download entries with same-major branch evidence', () {
      expect(
        provider.debugScoreDownloadEntry(
          gameVersion: '11.1.5',
          detailTitle: 'ElvUI for The War Within',
          detailSummary: 'Updated for the 11.0 branch',
          url: 'https://downloads.example.com/elvui-11-0-5.zip',
          anchorText: 'Download ElvUI 11.0.5',
          contextText: 'Retail 11.0 package',
          versionLabel: '11.0.5',
        ),
        greaterThan(0),
      );
    });

    test('keeps legacy non-retail fallback available', () {
      expect(
        provider.debugScoreDownloadEntry(
          gameVersion: '3.3.5',
          detailTitle: 'Questie addon',
          detailSummary: 'Quest helper',
          url: 'https://downloads.example.com/questie.zip',
          anchorText: 'Download',
          contextText: 'Archive',
        ),
        12,
      );
    });
  });
}
