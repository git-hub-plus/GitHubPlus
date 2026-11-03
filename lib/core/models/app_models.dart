/// Where a repository's main remote lives; drives the library group.
enum RepositoryGroup { local, hub, github }

enum ThemePreference { dark, light, system }

enum AppLanguage { ko, en }

/// Which vocabulary the UI uses: Git terms (커밋, 푸시) or plain words (버전 저장, 업로드).
enum TermStyle { plain, git }

class RepositoryInfo {
  const RepositoryInfo({
    required this.id,
    required this.path,
    required this.name,
    required this.group,
    required this.addedAt,
    this.alias,
    this.remoteUrl,
    this.pinned = false,
    this.lastOpenedAt,
    this.available = true,
  });

  /// Stable id derived from the normalized absolute path.
  final String id;
  final String path;
  final String name;
  final String? alias;
  final RepositoryGroup group;
  final String? remoteUrl;
  final bool pinned;
  final DateTime addedAt;
  final DateTime? lastOpenedAt;

  /// False when the folder is gone or no longer a git repository.
  final bool available;

  String get displayName => alias ?? name;

  RepositoryInfo copyWith({
    String? alias,
    bool clearAlias = false,
    RepositoryGroup? group,
    String? remoteUrl,
    bool? pinned,
    DateTime? lastOpenedAt,
    bool? available,
  }) => RepositoryInfo(
    id: id,
    path: path,
    name: name,
    alias: clearAlias ? null : (alias ?? this.alias),
    group: group ?? this.group,
    remoteUrl: remoteUrl ?? this.remoteUrl,
    pinned: pinned ?? this.pinned,
    addedAt: addedAt,
    lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
    available: available ?? this.available,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'path': path,
    'name': name,
    'alias': alias,
    'group': group.name,
    'remoteUrl': remoteUrl,
    'pinned': pinned,
    'addedAt': addedAt.millisecondsSinceEpoch,
    'lastOpenedAt': lastOpenedAt?.millisecondsSinceEpoch,
  };

  static RepositoryInfo? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'], path = json['path'], name = json['name'];
    if (id is! String || path is! String || name is! String) return null;
    DateTime? time(Object? value) => value is int ? DateTime.fromMillisecondsSinceEpoch(value) : null;
    return RepositoryInfo(
      id: id,
      path: path,
      name: name,
      alias: _string(json['alias']),
      group: RepositoryGroup.values.asNameMap()[json['group']] ?? RepositoryGroup.local,
      remoteUrl: _string(json['remoteUrl']),
      pinned: json['pinned'] == true,
      addedAt: time(json['addedAt']) ?? DateTime.now(),
      lastOpenedAt: time(json['lastOpenedAt']),
    );
  }
}

class AppSettings {
  const AppSettings({
    this.language = AppLanguage.ko,
    this.theme = ThemePreference.dark,
    this.defaultRepositoryDirectory,
    this.dailyCommitGoal = 5,
    this.pushGoal = 10,
    this.reduceMotion = false,
    this.termStyle = TermStyle.plain,
  });

  final AppLanguage language;
  final ThemePreference theme;
  final String? defaultRepositoryDirectory;

  /// Goal bar targets (후원 목표 바).
  final int dailyCommitGoal;
  final int pushGoal;

  /// Turns off decorative animations in addition to the OS setting.
  final bool reduceMotion;

  final TermStyle termStyle;

  AppSettings copyWith({
    AppLanguage? language,
    ThemePreference? theme,
    String? defaultRepositoryDirectory,
    int? dailyCommitGoal,
    int? pushGoal,
    bool? reduceMotion,
    TermStyle? termStyle,
  }) => AppSettings(
    language: language ?? this.language,
    theme: theme ?? this.theme,
    defaultRepositoryDirectory: defaultRepositoryDirectory ?? this.defaultRepositoryDirectory,
    dailyCommitGoal: dailyCommitGoal ?? this.dailyCommitGoal,
    pushGoal: pushGoal ?? this.pushGoal,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    termStyle: termStyle ?? this.termStyle,
  );

  Map<String, Object?> toJson() => {
    'language': language.name,
    'theme': theme.name,
    'defaultRepositoryDirectory': defaultRepositoryDirectory,
    'dailyCommitGoal': dailyCommitGoal,
    'pushGoal': pushGoal,
    'reduceMotion': reduceMotion,
    'termStyle': termStyle.name,
  };

  static AppSettings fromJson(Object? json) {
    if (json is! Map) return const AppSettings();
    int goal(Object? value, int fallback) => value is int && value > 0 && value <= 1000 ? value : fallback;
    return AppSettings(
      language: AppLanguage.values.asNameMap()[json['language']] ?? AppLanguage.ko,
      theme: ThemePreference.values.asNameMap()[json['theme']] ?? ThemePreference.dark,
      defaultRepositoryDirectory: _string(json['defaultRepositoryDirectory']),
      dailyCommitGoal: goal(json['dailyCommitGoal'], 5),
      pushGoal: goal(json['pushGoal'], 10),
      reduceMotion: json['reduceMotion'] == true,
      termStyle: TermStyle.values.asNameMap()[json['termStyle']] ?? TermStyle.plain,
    );
  }
}

/// Tolerates hand-edited or corrupted JSON: wrong types read as missing.
String? _string(Object? value) => value is String ? value : null;
