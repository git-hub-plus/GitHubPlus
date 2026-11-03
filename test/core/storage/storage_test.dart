import 'dart:convert';
import 'dart:io';

import 'package:github_plus/core/models/app_models.dart';
import 'package:github_plus/core/storage/json_file.dart';
import 'package:test/test.dart';

void main() {
  test('quick successive writes all land, the last one wins', () async {
    final dir = await Directory.systemTemp.createTemp('ghp-json-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/settings.json');
    await Future.wait([for (var i = 0; i < 20; i++) writeJsonFile(file, {'n': i})]);
    expect(jsonDecode(await file.readAsString()), {'n': 19});
    expect(dir.listSync().map((e) => e.path.split(Platform.pathSeparator).last), ['settings.json']);
  });

  test('wrong types in stored JSON read as missing instead of crashing', () {
    final settings = AppSettings.fromJson({'defaultRepositoryDirectory': 42, 'pushGoal': 'x'});
    expect(settings.defaultRepositoryDirectory, isNull);
    expect(settings.pushGoal, 10);
    final repo = RepositoryInfo.fromJson({'id': 'a', 'path': 'C:/r', 'name': 'r', 'alias': 1, 'remoteUrl': false});
    expect(repo?.alias, isNull);
    expect(repo?.remoteUrl, isNull);
  });
}
