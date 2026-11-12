import 'package:flutter_test/flutter_test.dart';
import 'package:pocketpos_offline/domain/money.dart';

void main() {
  group('Money.changeBreakdown (USD)', () {
    test('breaks 712 cents into bills and coins', () {
      final result = Money.changeBreakdown(712, 'USD');
      expect(result, {500: 1, 100: 2, 10: 1, 1: 2});
      final sum = result.entries.fold<int>(0, (s, e) => s + e.key * e.value);
      expect(sum, 712);
    });

    test('exact bill needs no smaller denominations', () {
      expect(Money.changeBreakdown(2000, 'USD'), {2000: 1});
    });

    test('zero or negative change gives an empty breakdown', () {
      expect(Money.changeBreakdown(0, 'USD'), isEmpty);
      expect(Money.changeBreakdown(-150, 'USD'), isEmpty);
    });

    test('large change uses the biggest bills first', () {
      final result = Money.changeBreakdown(18741, 'USD');
      expect(result[10000], 1);
      expect(result[5000], 1);
      expect(result[2000], 1);
      expect(result[1000], 1);
      expect(result[500], 1);
      expect(result[100], 2);
      expect(result[25], 1);
      expect(result[10], 1);
      expect(result[5], 1);
      expect(result[1], 1);
      final sum = result.entries.fold<int>(0, (s, e) => s + e.key * e.value);
      expect(sum, 18741);
    });
  });

  group('Money formatting & parsing', () {
    test('formats cents as currency', () {
      expect(Money.format(1234, 'USD'), '\$12.34');
      expect(Money.format(0, 'USD'), '\$0.00');
      expect(Money.format(5, 'USD'), '\$0.05');
    });

    test('parses typed amounts to cents', () {
      expect(Money.tryParseToCents('12.50'), 1250);
      expect(Money.tryParseToCents('0.99'), 99);
      expect(Money.tryParseToCents(' 7 '), 700);
      expect(Money.tryParseToCents('abc'), isNull);
      expect(Money.tryParseToCents(''), isNull);
      expect(Money.tryParseToCents('-5'), isNull);
    });

    test('centsToEditText round-trips', () {
      expect(Money.centsToEditText(1250), '12.50');
      expect(Money.tryParseToCents(Money.centsToEditText(99)), 99);
    });
  });
}
