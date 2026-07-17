import 'package:chordle/src/services/settings_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('persists the Free JI mode setting in the Flutter settings map', () {
    final settings = ChordleSettings.fromMap(const <Object?, Object?>{
      'freeJiEnabled': true,
    });

    expect(settings.freeJiEnabled, isTrue);
    expect(settings.toMap()['freeJiEnabled'], isTrue);
    expect(settings.copyWith(freeJiEnabled: false).freeJiEnabled, isFalse);
  });
}
