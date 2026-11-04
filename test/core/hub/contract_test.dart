import 'dart:convert';

import 'package:github_plus/core/content/repo_content.dart';
import 'package:github_plus/core/hub/hub_models.dart';
import 'package:github_plus/core/hub/validation.dart';
import 'package:github_plus/core/hub/wire.dart';
import 'package:github_plus/core/models/commit.dart';
import 'package:github_plus/core/models/diff.dart';
import 'package:test/test.dart';

/// Encodes to a JSON string and back, as the HTTP API does.
Map<String, Object?> _roundTrip(Map<String, Object?> json) => jsonDecode(jsonEncode(json)) as Map<String, Object?>;

void main() {
  test('LAN-only address policy', () {
    for (final ok in [
      '127.0.0.1',
      '10.1.2.3',
      '172.16.0.1',
      '172.31.255.1',
      '192.168.0.10',
      '169.254.1.1',
      '::1',
      'fd00::1',
      'fe80::1%12',
      '::ffff:192.168.0.5',
    ]) {
      expect(isPrivateAddress(ok), isTrue, reason: ok);
    }
    for (final bad in ['8.8.8.8', '172.32.0.1', '1.1.1.1', '2001:4860::8888', '::ffff:8.8.8.8', 'not-an-ip', '']) {
      expect(isPrivateAddress(bad), isFalse, reason: bad);
    }
  });

  test('repository names are safe folder and URL names', () {
    expect(['team-api', 'a.b_c', 'X1'].every(isValidRepositoryName), isTrue);
    expect(
      ['', '..', 'a..b', 'end.', '-x', 'con', 'COM1.txt', 'a/b', r'a\b', '한글', 'a b'].any(isValidRepositoryName),
      isFalse,
    );
  });

  test('LAN addresses rank office ranges first', () {
    final sorted = ['fe80::1', '10.0.0.2', '192.168.0.3', '172.16.0.4'].toList()
      ..sort((a, b) => lanAddressRank(a).compareTo(lanAddressRank(b)));
    expect(sorted, ['192.168.0.3', '172.16.0.4', '10.0.0.2', 'fe80::1']);
  });

  test('wire round trips commits, diffs and blobs', () {
    final who = CommitIdentity(
      name: '홍길동',
      email: 'h@example.com',
      date: DateTime(2026, 11, 4, 9),
      tzOffsetMinutes: 540,
    );
    final commit = Commit(
      sha: 'a' * 40,
      summary: '요약',
      body: '본문',
      author: who,
      committer: who,
      parentShas: ['b' * 40],
      refs: ['main'],
    );
    final back = commitFromJson(_roundTrip(commitToJson(commit)));
    expect((back.sha, back.summary, back.author.name, back.author.date), (commit.sha, '요약', '홍길동', who.date));
    expect(back.parentShas, commit.parentShas);
    expect(back.refs, ['main']);

    const diff = TextDiff(
      text: '@@ -1 +1 @@\n-a\n+b',
      maxLineNumber: 1,
      lineEndingsChange: (from: LineEnding.lf, to: LineEnding.crlf),
      hunks: [
        DiffHunk(
          header: DiffHunkHeader(oldStartLine: 1, oldLineCount: 1, newStartLine: 1, newLineCount: 1),
          unifiedDiffStart: 0,
          unifiedDiffEnd: 2,
          lines: [
            DiffLine(text: '@@ -1 +1 @@', type: DiffLineType.hunk, originalLineNumber: 0),
            DiffLine(text: '-a', type: DiffLineType.delete, originalLineNumber: 1, oldLineNumber: 1),
            DiffLine(
              text: '+b',
              type: DiffLineType.add,
              originalLineNumber: 2,
              newLineNumber: 1,
              noTrailingNewLine: true,
            ),
          ],
        ),
      ],
    );
    final decoded = fileDiffFromJson(_roundTrip(fileDiffToJson(diff))) as TextDiff;
    expect(decoded.selectableLines, [1, 2]);
    expect(decoded.hunks.single.lines.last.noTrailingNewLine, isTrue);
    expect(decoded.lineEndingsChange?.to, LineEnding.crlf);
    expect(fileDiffFromJson(_roundTrip(fileDiffToJson(const BinaryDiff()))), isA<BinaryDiff>());

    final blob = blobFromJson(_roundTrip(blobToJson(const TextBlob('# 제목', 8)))) as TextBlob;
    expect((blob.text, blob.size), ('# 제목', 8));
    expect((blobFromJson(_roundTrip(blobToJson(ImageBlob([1, 2, 3])))) as ImageBlob).bytes, [1, 2, 3]);
    final entry = treeEntryFromJson(
      _roundTrip(treeEntryToJson(const TreeEntry(path: 'docs', kind: EntryKind.directory))),
    );
    expect((entry.path, entry.kind), ('docs', EntryKind.directory));
  });

  test('hub settings tolerate bad JSON', () {
    final s = HubSettings.fromJson({'port': 'x', 'enabled': true, 'rootDirectory': 5});
    expect((s.port, s.enabled, s.rootDirectory), (8765, true, ''));
  });
}
