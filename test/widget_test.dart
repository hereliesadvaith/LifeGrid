import 'package:flutter_test/flutter_test.dart';

import 'package:lifegrid/data/field_type.dart';

void main() {
  group('FieldType encode/decode', () {
    test('BOOL round-trips through canonical form', () {
      expect(FieldType.bool_.encode(true), '1');
      expect(FieldType.bool_.encode(false), '0');
      expect(FieldType.bool_.decode('1'), true);
      expect(FieldType.bool_.decode('0'), false);
    });

    test('empty values encode to null', () {
      expect(FieldType.str.encode(''), isNull);
      expect(FieldType.int_.encode(''), isNull);
      expect(FieldType.str.decode(null), isNull);
    });

    test('numbers decode to typed values', () {
      expect(FieldType.int_.decode('42'), 42);
      expect(FieldType.float.decode('4.5'), 4.5);
    });
  });

  group('FieldType validation', () {
    test('rejects non-numeric INT/FLOAT and bad dates', () {
      expect(FieldType.int_.validate('abc'), isNotNull);
      expect(FieldType.float.validate('1.2.3'), isNotNull);
      expect(FieldType.date.validate('not-a-date'), isNotNull);
    });

    test('accepts valid input and empty', () {
      expect(FieldType.int_.validate('10'), isNull);
      expect(FieldType.float.validate('10.5'), isNull);
      expect(FieldType.date.validate('2026-06-10'), isNull);
      expect(FieldType.str.validate(''), isNull);
    });
  });
}
