import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../core/hub/client.dart';
import '../core/hub/hub_models.dart';
import 'app_state.dart';

// Discovery lives for the application scope; matchers are removed with it.
final hubDiscoveryProvider = Provider<HubDiscovery>((ref) {
  final bootstrap = ref.watch(bootstrapProvider);
  final discovery = HubDiscovery(storeFile: p.join(bootstrap.dataDirectory.path, 'hubs.json'));
  final unregister = bootstrap.repositoryStore.registerHubMatcher((url) => isHubRemote(url, discovery.hubs));
  ref.onDispose(() {
    unregister();
    unawaited(discovery.stop());
  });
  return discovery;
});

final discoveredHubsProvider = StreamProvider<List<DiscoveredHub>>((ref) async* {
  final discovery = ref.watch(hubDiscoveryProvider);
  // Subscribe before starting so the initial discovery event cannot be lost.
  final events = StreamController<List<DiscoveredHub>>();
  final subscription = discovery.changes.listen(events.add, onError: events.addError);
  ref.onDispose(() {
    unawaited(subscription.cancel());
    unawaited(events.close());
  });
  await discovery.start();
  yield discovery.hubs;
  yield* events.stream;
});

class HubSelection extends Notifier<DiscoveredHub?> {
  @override
  DiscoveredHub? build() => null;
  void select(DiscoveredHub? hub) => state = hub;
}

final selectedHubProvider = NotifierProvider<HubSelection, DiscoveredHub?>(HubSelection.new);

final hubApiProvider = Provider.autoDispose.family<HubClient, String>((ref, url) {
  final client = HubClient(url);
  ref.onDispose(client.close);
  return client;
});
final hubRepositoriesProvider = FutureProvider.autoDispose.family<List<HubRepository>, String>(
  (ref, url) => ref.watch(hubApiProvider(url)).listRepositories(),
);
