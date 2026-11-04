// Hub shapes (from GitHub+ v1 src/shared/ipc/hub.ts). JSON is the hub HTTP
// API format and the on-disk settings format.

/// Host-side hub settings.
class HubSettings {
  const HubSettings({
    this.enabled = false,
    this.port = 8765,
    this.rootDirectory = '',
    this.name = 'GitHub+ Hub',
    this.keepRunningInTray = true,
    this.backupDirectory,
  });

  final bool enabled;
  final int port;

  /// Folder holding the bare repositories (`<name>.git`) and `push-log.jsonl`.
  final String rootDirectory;

  /// Name announced on the LAN, e.g. "사무실 허브".
  final String name;
  final bool keepRunningInTray;

  /// Optional folder for `git bundle` backups.
  final String? backupDirectory;

  HubSettings copyWith({
    bool? enabled,
    int? port,
    String? rootDirectory,
    String? name,
    bool? keepRunningInTray,
    String? backupDirectory,
  }) => HubSettings(
    enabled: enabled ?? this.enabled,
    port: port ?? this.port,
    rootDirectory: rootDirectory ?? this.rootDirectory,
    name: name ?? this.name,
    keepRunningInTray: keepRunningInTray ?? this.keepRunningInTray,
    backupDirectory: backupDirectory ?? this.backupDirectory,
  );

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'port': port,
    'rootDirectory': rootDirectory,
    'name': name,
    'keepRunningInTray': keepRunningInTray,
    'backupDirectory': backupDirectory,
  };

  static HubSettings fromJson(Object? json) {
    if (json is! Map) return const HubSettings();
    final port = json['port'];
    return HubSettings(
      enabled: json['enabled'] == true,
      port: port is int && port > 0 && port < 65536 ? port : 8765,
      rootDirectory: _string(json['rootDirectory']) ?? '',
      name: _string(json['name']) ?? 'GitHub+ Hub',
      keepRunningInTray: json['keepRunningInTray'] != false,
      backupDirectory: _string(json['backupDirectory']),
    );
  }
}

class HubServerStatus {
  const HubServerStatus({
    required this.running,
    required this.port,
    this.addresses = const [],
    this.repositoryCount = 0,
    this.error,
  });

  final bool running;
  final int port;

  /// Base URLs clients can use, best first, e.g. `http://192.168.0.10:8765`.
  final List<String> addresses;
  final int repositoryCount;
  final String? error;
}

class HubRepository {
  const HubRepository({required this.name, required this.url, this.description, this.defaultBranch, this.lastPushAt});

  final String name;

  /// Clone URL, e.g. `http://192.168.0.10:8765/team-api.git`.
  final String url;
  final String? description;
  final String? defaultBranch;
  final DateTime? lastPushAt;

  Map<String, Object?> toJson() => {
    'name': name,
    'url': url,
    'description': description,
    'defaultBranch': defaultBranch,
    'lastPushAt': lastPushAt?.millisecondsSinceEpoch,
  };

  static HubRepository? fromJson(Object? json) {
    if (json is! Map) return null;
    final name = _string(json['name']), url = _string(json['url']);
    if (name == null || url == null) return null;
    final at = json['lastPushAt'];
    return HubRepository(
      name: name,
      url: url,
      description: _string(json['description']),
      defaultBranch: _string(json['defaultBranch']),
      lastPushAt: at is int ? DateTime.fromMillisecondsSinceEpoch(at) : null,
    );
  }
}

/// One accepted ref update, appended to `push-log.jsonl` (one JSON per line).
class HubPushRecord {
  const HubPushRecord({
    required this.at,
    required this.repository,
    required this.ref,
    required this.oldSha,
    required this.newSha,
    required this.clientAddress,
    this.clientHost,
  });

  final DateTime at;
  final String repository;
  final String ref;
  final String oldSha;
  final String newSha;
  final String clientAddress;
  final String? clientHost;

  Map<String, Object?> toJson() => {
    'at': at.millisecondsSinceEpoch,
    'repository': repository,
    'ref': ref,
    'oldSha': oldSha,
    'newSha': newSha,
    'clientAddress': clientAddress,
    'clientHost': clientHost,
  };

  static HubPushRecord? fromJson(Object? json) {
    if (json is! Map) return null;
    final at = json['at'];
    final repository = _string(json['repository']), ref = _string(json['ref']);
    final oldSha = _string(json['oldSha']), newSha = _string(json['newSha']);
    final address = _string(json['clientAddress']);
    if (at is! int || repository == null || ref == null || oldSha == null || newSha == null || address == null) {
      return null;
    }
    return HubPushRecord(
      at: DateTime.fromMillisecondsSinceEpoch(at),
      repository: repository,
      ref: ref,
      oldSha: oldSha,
      newSha: newSha,
      clientAddress: address,
      clientHost: _string(json['clientHost']),
    );
  }
}

/// A hub seen on the LAN (UDP announcement) or added by address.
class DiscoveredHub {
  const DiscoveredHub({
    required this.url,
    required this.name,
    required this.lastSeen,
    this.manual = false,
    this.online = true,
  });

  /// Base URL, also the id, e.g. `http://192.168.0.10:8765`.
  final String url;
  final String name;
  final DateTime lastSeen;
  final bool manual;
  final bool online;

  String get id => url;

  Map<String, Object?> toJson() => {
    'url': url,
    'name': name,
    'lastSeen': lastSeen.millisecondsSinceEpoch,
    'manual': manual,
  };

  static DiscoveredHub? fromJson(Object? json) {
    if (json is! Map) return null;
    final url = _string(json['url']), name = _string(json['name']);
    final seen = json['lastSeen'];
    if (url == null || name == null) return null;
    return DiscoveredHub(
      url: url,
      name: name,
      lastSeen: DateTime.fromMillisecondsSinceEpoch(seen is int ? seen : 0),
      manual: json['manual'] == true,
      online: false,
    );
  }
}

String? _string(Object? value) => value is String ? value : null;
