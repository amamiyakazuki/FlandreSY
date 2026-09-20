import 'package:flutter_test/flutter_test.dart';
import 'package:flandresy/src/data/adapters/ble_target.dart';

void main() {
  test('MAC is authoritative even if another device has the same name', () {
    expect(
        matchesZhuliBleTarget(
            expectedName: 'XN',
            expectedMac: 'AA:BB:CC:DD:EE:FF',
            name: 'XN',
            address: '11:22:33:44:55:66'),
        isFalse);
    expect(
        matchesZhuliBleTarget(
            expectedName: 'other',
            expectedMac: 'AA:BB:CC:DD:EE:FF',
            name: 'XN',
            address: 'aa-bb-cc-dd-ee-ff'),
        isTrue);
  });
  test('name only is exact; no guessed XN fallback', () {
    expect(
        matchesZhuliBleTarget(
            expectedName: 'XN-123',
            expectedMac: '',
            name: 'XN-123',
            address: 'anything'),
        isTrue);
    expect(
        matchesZhuliBleTarget(
            expectedName: 'XN-123',
            expectedMac: '',
            name: 'XN-456',
            address: 'anything'),
        isFalse);
    expect(
        matchesZhuliBleTarget(
            expectedName: '',
            expectedMac: '',
            name: 'XN-123',
            address: 'anything'),
        isFalse);
  });
}
