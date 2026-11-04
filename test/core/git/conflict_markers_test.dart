import 'package:flutter_test/flutter_test.dart';
import 'package:github_plus/core/git/conflict_markers.dart';
import 'package:github_plus/core/models/advanced.dart';

void main() {
  const block = '<<<<<<< ours\nours\n=======\ntheirs\n>>>>>>> theirs';
  test('multiple blocks, labels, line numbers, and independent choices', () {
    const text = 'before\n$block\nbetween\n$block\nafter\n';
    final regions = parseConflictMarkers(text);
    expect(regions, hasLength(2));
    expect(regions[0].index, 0);
    expect(regions[0].startLine, 1);
    expect(regions[0].endLine, 5);
    expect(regions[1].startLine, 7);
    expect(regions[0].oursLabel, 'ours');
    expect(regions[0].theirsLabel, 'theirs');
    expect(regions[0].base, isNull);
    expect(
      applyConflictChoices(text, {0: ConflictChoice.ours, 1: ConflictChoice.theirs}),
      'before\nours\nbetween\ntheirs\nafter\n',
    );
    expect(applyConflictChoices(text, {0: ConflictChoice.both}), 'before\nours\ntheirs\nbetween\n$block\nafter\n');
    expect(applyConflictChoices(text, {}), text);
  });
  test('diff3 base, size 10, and CRLF survive selection', () {
    const text =
        'start\r\n<<<<<<<<<< ours\r\nours\r\n|||||||||| base\r\nbase\r\n==========\r\ntheirs\r\n>>>>>>>>>> theirs\r\nend';
    final region = parseConflictMarkers(text, markerSize: 10).single;
    expect(region.ours, ['ours\r']);
    expect(region.base, ['base\r']);
    expect(region.theirs, ['theirs\r']);
    expect(applyConflictChoices(text, {0: ConflictChoice.both}, markerSize: 10), 'start\r\nours\r\ntheirs\r\nend');
    expect(parseConflictMarkers(text), isEmpty);
  });
  test('preserves final newline presence and empty sides', () {
    expect(applyConflictChoices(block, {0: ConflictChoice.ours}), 'ours');
    final crlf = block.replaceAll('\n', '\r\n');
    expect(applyConflictChoices(crlf, {0: ConflictChoice.both}), 'ours\r\ntheirs');
    expect(applyConflictChoices('$crlf\r\n', {0: ConflictChoice.theirs}), 'theirs\r\n');
    expect(applyConflictChoices('$block\n', {0: ConflictChoice.theirs}), 'theirs\n');
    expect(applyConflictChoices('<<<<<<<\n=======\n>>>>>>>', {0: ConflictChoice.both}), '');
    expect(applyConflictChoices('start\n<<<<<<<\n=======\n>>>>>>>\nend', {0: ConflictChoice.ours}), 'start\nend');
  });
  test('malformed markers and wrong sizes are left unchanged', () {
    for (final text in ['<<<<<<< ours\nvalue', '=======$block', '<<<<<<<<< ours\nx\n=======\ny\n>>>>>>> t']) {
      expect(parseConflictMarkers(text), isEmpty);
      expect(applyConflictChoices(text, {0: ConflictChoice.ours}), text);
    }
    expect(() => parseConflictMarkers(block, markerSize: 0), throwsArgumentError);
  });
}
