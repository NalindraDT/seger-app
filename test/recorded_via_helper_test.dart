import 'package:flutter_test/flutter_test.dart';
import 'package:pltuapp/helpers/recorded_via_helper.dart';

const _smartwatch = RecordedViaOption(
  id: 2,
  code: 'smartwatch',
  label: 'Smartwatch',
  icon: 'watch',
  requiresSourceLink: false,
  isActive: true,
  isLocked: false,
);

const _strava = RecordedViaOption(
  id: 1,
  code: 'strava',
  label: 'Strava',
  icon: 'strava',
  requiresSourceLink: false,
  isActive: true,
  isLocked: true,
);

void main() {
  group('RecordedViaHelper.isStrava', () {
    test('hanya kode strava yang dianggap Strava, bukan label', () {
      expect(RecordedViaHelper.isStrava('strava'), isTrue);
      expect(RecordedViaHelper.isStrava('Strava'), isFalse);
      expect(RecordedViaHelper.isStrava('smartwatch'), isFalse);
      expect(RecordedViaHelper.isStrava(null), isFalse);
    });
  });

  group('RecordedViaHelper.findByCode', () {
    test('menemukan opsi berdasarkan kode dan null bila tidak ada', () {
      expect(RecordedViaHelper.findByCode([_strava, _smartwatch], 'smartwatch')?.id, 2);
      expect(RecordedViaHelper.findByCode([_strava], 'manual'), isNull);
      expect(RecordedViaHelper.findByCode([_strava], null), isNull);
    });
  });

  group('RecordedViaHelper.withCurrentValue', () {
    test('tidak mengubah daftar bila kode sudah ada', () {
      final result = RecordedViaHelper.withCurrentValue([_strava, _smartwatch], 'smartwatch');
      expect(result.length, 2);
    });

    test('menambahkan entri nonaktif untuk nilai lama yang opsinya sudah dihapus', () {
      final result = RecordedViaHelper.withCurrentValue([_strava], 'manual');
      expect(result.length, 2);

      final legacy = result.last;
      expect(legacy.code, 'manual');
      expect(legacy.label, 'Manual (nonaktif)');
      expect(legacy.isActive, isFalse);
    });

    test('mengabaikan kode kosong', () {
      expect(RecordedViaHelper.withCurrentValue([_strava], null).length, 1);
      expect(RecordedViaHelper.withCurrentValue([_strava], '').length, 1);
    });
  });

  test('katalog ikon backend dipetakan ke Material Icons', () {
    for (final key in ['strava', 'watch', 'smartphone', 'footprints', 'bike', 'heart-pulse', 'timer', 'pen', 'tidak-dikenal']) {
      expect(RecordedViaHelper.iconFor(key), isNotNull);
    }
    expect(RecordedViaHelper.iconFor('strava'), isNot(RecordedViaHelper.iconFor('pen')));
  });
}
