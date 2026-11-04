// JSON forms of commits, diffs and repository content for the hub HTTP API.
// The server encodes with these and the client decodes with the same file,
// so both sides always agree.
import 'dart:convert';
import 'dart:typed_data';

import '../content/repo_content.dart';
import '../models/commit.dart';
import '../models/diff.dart';
import '../models/status.dart';

T _enum<T extends Enum>(List<T> values, Object? name, T fallback) => values.asNameMap()[name] ?? fallback;

Map<String, Object?> identityToJson(CommitIdentity i) => {
  'name': i.name,
  'email': i.email,
  'date': i.date.millisecondsSinceEpoch,
  'tz': i.tzOffsetMinutes,
};

CommitIdentity identityFromJson(Map json) => CommitIdentity(
  name: json['name'] as String? ?? '',
  email: json['email'] as String? ?? '',
  date: DateTime.fromMillisecondsSinceEpoch(json['date'] as int? ?? 0),
  tzOffsetMinutes: json['tz'] as int? ?? 0,
);

Map<String, Object?> commitToJson(Commit c) => {
  'sha': c.sha,
  'summary': c.summary,
  'body': c.body,
  'author': identityToJson(c.author),
  'committer': identityToJson(c.committer),
  'parents': c.parentShas,
  'refs': c.refs,
};

Commit commitFromJson(Map json) => Commit(
  sha: json['sha'] as String,
  summary: json['summary'] as String? ?? '',
  body: json['body'] as String? ?? '',
  author: identityFromJson(json['author'] as Map),
  committer: identityFromJson(json['committer'] as Map),
  parentShas: [for (final p in json['parents'] as List? ?? const []) p as String],
  refs: [for (final r in json['refs'] as List? ?? const []) r as String],
);

Map<String, Object?> fileStatusToJson(FileStatus s) => {
  'kind': s.kind.name,
  'oldPath': s.oldPath,
  'renameIncludesModifications': s.renameIncludesModifications,
};

FileStatus fileStatusFromJson(Map json) => FileStatus(
  kind: _enum(FileStatusKind.values, json['kind'], FileStatusKind.modified),
  oldPath: json['oldPath'] as String?,
  renameIncludesModifications: json['renameIncludesModifications'] == true,
);

Map<String, Object?> committedFileToJson(CommittedFile f) => {'path': f.path, 'status': fileStatusToJson(f.status)};

CommittedFile committedFileFromJson(Map json) =>
    CommittedFile(path: json['path'] as String, status: fileStatusFromJson(json['status'] as Map));

Map<String, Object?> _textDiffToJson(TextDiff d) => {
  'text': d.text,
  'maxLineNumber': d.maxLineNumber,
  'hasHiddenBidiChars': d.hasHiddenBidiChars,
  if (d.lineEndingsChange != null)
    'lineEndingsChange': {'from': d.lineEndingsChange!.from.name, 'to': d.lineEndingsChange!.to.name},
  'hunks': [
    for (final h in d.hunks)
      {
        'header': [h.header.oldStartLine, h.header.oldLineCount, h.header.newStartLine, h.header.newLineCount],
        'start': h.unifiedDiffStart,
        'end': h.unifiedDiffEnd,
        'lines': [
          for (final l in h.lines)
            [l.text, l.type.name, l.originalLineNumber, l.oldLineNumber, l.newLineNumber, l.noTrailingNewLine],
        ],
      },
  ],
};

TextDiff _textDiffFromJson(Map json) {
  final change = json['lineEndingsChange'];
  return TextDiff(
    text: json['text'] as String? ?? '',
    maxLineNumber: json['maxLineNumber'] as int? ?? 0,
    hasHiddenBidiChars: json['hasHiddenBidiChars'] == true,
    lineEndingsChange: change is Map
        ? (
            from: _enum(LineEnding.values, change['from'], LineEnding.lf),
            to: _enum(LineEnding.values, change['to'], LineEnding.lf),
          )
        : null,
    hunks: [
      for (final h in json['hunks'] as List? ?? const [])
        DiffHunk(
          header: DiffHunkHeader(
            oldStartLine: (h['header'] as List)[0] as int,
            oldLineCount: (h['header'] as List)[1] as int,
            newStartLine: (h['header'] as List)[2] as int,
            newLineCount: (h['header'] as List)[3] as int,
          ),
          unifiedDiffStart: h['start'] as int,
          unifiedDiffEnd: h['end'] as int,
          lines: [
            for (final l in h['lines'] as List)
              DiffLine(
                text: l[0] as String,
                type: _enum(DiffLineType.values, l[1], DiffLineType.context),
                originalLineNumber: l[2] as int,
                oldLineNumber: l[3] as int?,
                newLineNumber: l[4] as int?,
                noTrailingNewLine: l[5] == true,
              ),
          ],
        ),
    ],
  );
}

Map<String, Object?> _imageToJson(DiffImage? i) =>
    i == null ? const {} : {'bytes': base64Encode(i.bytes), 'mediaType': i.mediaType};

DiffImage? _imageFromJson(Object? json) => json is Map && json['bytes'] is String
    ? DiffImage(bytes: base64Decode(json['bytes'] as String), mediaType: json['mediaType'] as String? ?? '')
    : null;

Map<String, Object?> fileDiffToJson(FileDiff diff) => switch (diff) {
  TextDiff d => {'kind': 'text', ..._textDiffToJson(d)},
  LargeDiff(:final diff, :final size) => {'kind': 'large', 'size': size, ..._textDiffToJson(diff)},
  BinaryDiff() => {'kind': 'binary'},
  ImageDiff(:final previous, :final current) => {
    'kind': 'image',
    'previous': _imageToJson(previous),
    'current': _imageToJson(current),
  },
  SubmoduleDiff(:final path, :final url, :final oldSha, :final newSha) => {
    'kind': 'submodule',
    'path': path,
    'url': url,
    'oldSha': oldSha,
    'newSha': newSha,
  },
  UnrenderableDiff() => {'kind': 'unrenderable'},
};

FileDiff fileDiffFromJson(Map json) => switch (json['kind']) {
  'text' => _textDiffFromJson(json),
  'large' => LargeDiff(diff: _textDiffFromJson(json), size: json['size'] as int? ?? 0),
  'binary' => const BinaryDiff(),
  'image' => ImageDiff(previous: _imageFromJson(json['previous']), current: _imageFromJson(json['current'])),
  'submodule' => SubmoduleDiff(
    path: json['path'] as String? ?? '',
    url: json['url'] as String?,
    oldSha: json['oldSha'] as String?,
    newSha: json['newSha'] as String?,
  ),
  _ => const UnrenderableDiff(),
};

Map<String, Object?> treeEntryToJson(TreeEntry e) => {'path': e.path, 'kind': e.kind.name, 'size': e.size};

TreeEntry treeEntryFromJson(Map json) => TreeEntry(
  path: json['path'] as String,
  kind: _enum(EntryKind.values, json['kind'], EntryKind.file),
  size: json['size'] as int?,
);

Map<String, Object?> blobToJson(BlobContent blob) => switch (blob) {
  TextBlob(:final text, :final size) => {'kind': 'text', 'text': text, 'size': size},
  ImageBlob(:final bytes) => {'kind': 'image', 'bytes': base64Encode(bytes)},
  BinaryBlob(:final size) => {'kind': 'binary', 'size': size},
  TooLargeBlob(:final size) => {'kind': 'tooLarge', 'size': size},
  MissingBlob() => {'kind': 'missing'},
  BlockedBlob() => {'kind': 'blocked'},
};

BlobContent blobFromJson(Map json) => switch (json['kind']) {
  'text' => TextBlob(json['text'] as String? ?? '', json['size'] as int? ?? 0),
  'image' => ImageBlob(Uint8List.fromList(base64Decode(json['bytes'] as String? ?? ''))),
  'binary' => BinaryBlob(json['size'] as int? ?? 0),
  'tooLarge' => TooLargeBlob(json['size'] as int? ?? 0),
  'blocked' => const BlockedBlob(),
  _ => const MissingBlob(),
};
