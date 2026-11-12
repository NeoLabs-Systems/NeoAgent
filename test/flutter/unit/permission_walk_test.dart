import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/main.dart';

void main() {
  test('asks for each missing permission in order, numbering the steps', () {
    final walk = PermissionWalk();
    expect(walk.start(<String>['overlay', 'battery']), 'overlay');
    expect((walk.step, walk.total), (1, 2));
    expect(walk.afterReturn(<String>{'overlay'}), 'battery');
    expect(walk.step, 2);
    expect(walk.afterReturn(<String>{'overlay', 'battery'}), isNull);
    expect(walk.active, isFalse);
  });

  test('a screen left without allowing ends the walk', () {
    final walk = PermissionWalk();
    walk.start(<String>['overlay', 'battery']);
    expect(walk.afterReturn(<String>{}), isNull);
    expect(walk.active, isFalse);
    expect(walk.afterReturn(<String>{'overlay'}), isNull);
  });

  test('nothing missing starts no walk, and a new walk starts over', () {
    final walk = PermissionWalk();
    expect(walk.start(<String>[]), isNull);
    expect(walk.active, isFalse);
    walk.start(<String>['a', 'b']);
    walk.stop();
    expect(walk.start(<String>['c']), 'c');
    expect((walk.step, walk.total), (1, 1));
  });
}
