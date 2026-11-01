import 'package:flutter_test/flutter_test.dart';
import 'package:site_builder/model.dart';
import 'package:site_builder/platform/zip_export.dart';

void main() {
  test('site survives a JSON round trip', () {
    final a = Site.create('ja')
      ..project = '{"pages":[]}'
      ..mailto = 'me@example.com'
      ..deployProject = 'my-project';
    final b = Site.decode(a.encode());
    expect(b.slug, a.slug);
    expect(b.lang, 'ja');
    expect(b.project, '{"pages":[]}');
    expect(b.mailto, 'me@example.com');
    expect(b.deployProject, 'my-project');
    expect(slugRe.hasMatch(b.slug), isTrue);
  });

  test('html options carry the booking settings to the editor', () {
    final s = Site.create('en')..endpoint = 'https://formspree.io/f/abc';
    expect(s.htmlOptions['endpoint'], 'https://formspree.io/f/abc');
    expect(s.htmlOptions['lang'], 'en');
  });

  test('zip is built from the editor html and firebase.json targets the site', () {
    expect(buildZip('<!DOCTYPE html><html></html>').length, greaterThan(300));
    expect(firebaseJson(site: 'my-salon'), contains('"site": "my-salon"'));
    expect(firebaseJson(), isNot(contains('"site"')));
  });
}
