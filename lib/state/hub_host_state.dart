// EXTENSION POINT (owner: worker H3a). Provider names and startup type are fixed.
import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../core/hub/hub_models.dart';
import '../core/hub/server.dart';
import '../core/storage/json_file.dart';
import 'app_state.dart';

final hubServerProvider = Provider<HubServer>((ref) {
  final server = HubServer(git: ref.watch(gitProvider), appVersion: '0.1.0');
  ref.onDispose(() => unawaited(server.stop()));
  return server;
});

class HubSettingsNotifier extends AsyncNotifier<HubSettings> {
  Future<void> _pending = Future.value();
  String? _configuredRoot;
  String? get configuredRoot => _configuredRoot;
  File get _file => File(p.join(ref.read(bootstrapProvider).dataDirectory.path, 'hub.json'));

  @override
  Future<HubSettings> build() async {
    final root = p.join(ref.read(bootstrapProvider).dataDirectory.path, 'hub-repos');
    final settings = HubSettings.fromJson(await readJsonFile(_file));
    return settings.rootDirectory.isEmpty ? settings.copyWith(rootDirectory: root) : settings;
  }

  Future<void> startIfEnabled() {
    final next = _pending.then((_) async {
      if (!ref.mounted) return;
      final settings = await future;
      if (!ref.mounted || !settings.enabled) return;
      _configuredRoot = settings.rootDirectory;
      await ref.read(hubServerProvider).start(settings);
    });
    _pending = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  /// Persist before changing the server. Failed writes leave the live settings intact.
  /// Serializing the entire transaction prevents rapid edits from racing a restart.
  Future<void> save(HubSettings Function(HubSettings) change) {
    final next = _pending.then((_) async {
      final current = await future;
      final updated = change(current);
      if (updated.port < 1024 ||
          updated.port > 65535 ||
          updated.name.trim().isEmpty ||
          updated.rootDirectory.trim().isEmpty) {
        throw ArgumentError('Invalid hub settings');
      }
      await writeJsonFile(_file, updated.toJson());
      if (!ref.mounted) return;
      state = AsyncData(updated);
      final server = ref.read(hubServerProvider);
      if (updated.enabled) {
        _configuredRoot = updated.rootDirectory;
        await server.start(updated);
      } else {
        await server.stop();
      }
    });
    _pending = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }
}

final hubSettingsProvider = AsyncNotifierProvider<HubSettingsNotifier, HubSettings>(HubSettingsNotifier.new);

final hubStatusProvider = StreamProvider<HubServerStatus>((ref) {
  final server = ref.watch(hubServerProvider);
  return Stream<HubServerStatus>.multi((controller) {
    final subscription = server.statusChanges.listen(controller.add, onError: controller.addError);
    controller.add(server.status);
    controller.onCancel = subscription.cancel;
  });
});

/// Read once by the launcher shell. Retained by the app's ProviderContainer.
final hubStartupProvider = Provider<void>((ref) {
  unawaited(ref.read(hubSettingsProvider.notifier).startIfEnabled());
});

/// Keep management reads out of the way of repository moves on Windows.
class HubHostOperations {
  Future<void> _pending = Future.value();
  Future<T> run<T>(Future<T> Function() action) {
    final next = _pending.then((_) => action());
    _pending = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }
}

final hubHostOperationsProvider = Provider<HubHostOperations>((ref) => HubHostOperations());

Future<void> deleteHubRepository(HubServer server, String name) async {
  for (var attempt = 0; ; attempt++) {
    try {
      await server.deleteRepository(name);
      return;
    } on FileSystemException catch (error) {
      // A just-exited Git child may briefly retain its working directory.
      if (!Platform.isWindows || attempt >= 5 || !{32, 33}.contains(error.osError?.errorCode)) {
        rethrow;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }
}

class HubHostSnapshot {
  const HubHostSnapshot(this.repositories, this.pushes, this.todayPushes);
  final List<HubRepository> repositories;
  final List<HubPushRecord> pushes;
  final int todayPushes;
}

/// Core exposes no push event stream; poll only while the management screen is open.
final hubHostSnapshotProvider = FutureProvider.autoDispose<HubHostSnapshot>((ref) async {
  final server = ref.watch(hubServerProvider);
  final status = ref.watch(hubStatusProvider).value ?? server.status;
  final settings = ref.watch(hubSettingsProvider).value;
  if (!status.running &&
      (settings == null ||
          settings.enabled ||
          ref.read(hubSettingsProvider.notifier).configuredRoot != settings.rootDirectory)) {
    return const HubHostSnapshot([], [], 0);
  }
  if (status.running) {
    final timer = Timer(const Duration(seconds: 5), ref.invalidateSelf);
    ref.onDispose(timer.cancel);
  }
  return ref.read(hubHostOperationsProvider).run(() async {
    final repositories = await server.listRepositories();
    final pushes = await server.pushLog(limit: 0x7fffffff);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return HubHostSnapshot(repositories, pushes, pushes.where((r) => !r.at.toLocal().isBefore(today)).length);
  });
});
