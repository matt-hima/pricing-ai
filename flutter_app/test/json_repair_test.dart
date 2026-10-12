import 'package:flutter_test/flutter_test.dart';
import 'package:self_quote/json_repair.dart';

void main() {
  test('valid JSON passes through', () {
    expect(parseLooseJson('{"a":1,"b":[1,2]}'), {'a': 1, 'b': [1, 2]});
  });

  test('text around the object is ignored', () {
    expect(parseLooseJson('Sure! Here it is:\n{"a":1}\nHope that helps.'), {'a': 1});
  });

  test('trailing commas before } and ] are removed (the real failure seen in plain mode)', () {
    final r = parseLooseJson('{"modules":[{"id":"member","tasks":[{"name":"Login","kind":"fe","hours":40,},],},],"complexity":"low",}');
    expect(r?['complexity'], 'low');
    expect(((r?['modules'] as List).first as Map)['id'], 'member');
  });

  test('truncated output is closed', () {
    final r = parseLooseJson('{"complexity":"high","assumptions":["A","B"],"modules":[{"id":"cart","tasks":[{"name":"Checkout","kind":"fe","hours":30},{"name":"Orde');
    expect(r?['complexity'], 'high');
    expect(r?['assumptions'], ['A', 'B']);
    final tasks = ((r?['modules'] as List).first as Map)['tasks'] as List;
    expect((tasks.first as Map)['name'], 'Checkout');
  });

  test('dangling key and comma at the cut-off are dropped', () {
    final r = parseLooseJson('{"modules":[{"id":"cart","tasks":[{"name":"X","kind":"be","hours":');
    expect(r, isNotNull);
    expect(r!.containsKey('modules'), true);
  });

  test('mismatched closing bracket uses the expected one', () {
    final r = parseLooseJson('{"a":[1,2},"b":3}');
    expect(r?['a'], [1, 2]);
  });

  test('braces and commas inside strings are left alone', () {
    final r = parseLooseJson('{"a":"x,}","b":"{[","c":1,}');
    expect(r, {'a': 'x,}', 'b': '{[', 'c': 1});
  });

  test('no object returns null', () {
    expect(parseLooseJson('no json here'), isNull);
  });
}
