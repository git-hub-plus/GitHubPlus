// Ported from GitHub Desktop (MIT): app/src/lib/git/push.ts (via GitHub+ v1 tests/main/hub/client/discovery.test.ts)
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:github_plus/core/hub/client.dart';
import 'package:test/test.dart';

// Intercepts only silence timers; network IO and polling still use real time.
class SilenceTimer implements Timer {
  SilenceTimer(this.callback);
  final void Function() callback;
  bool _active = true;
  @override
  bool get isActive => _active;
  @override
  int get tick => _active ? 0 : 1;
  @override
  void cancel() {
    _active = false;
  }

  void elapse() {
    if (_active) {
      _active = false;
      callback();
    }
  }
}

void main() {
  late Directory root;
  late String store;
  setUp(() async {
    root = await Directory('test/core/hub').createTemp('discovery-');
    store = '${root.path}/manual.json';
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });

  test('UDP validates packets, expires after silence, revives and stops', () async {
    final timers = <SilenceTimer>[];
    await runZoned(
      () async {
        final discovery = HubDiscovery(storeFile: store);
        final updates = <List<Object>>[];
        final subscription = discovery.changes.listen((h) => updates.add(h));
        await discovery.start();
        final sender = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
        Future<void> send(Object data) async {
          final bytes = data is String ? utf8.encode(data) : utf8.encode(jsonEncode(data));
          sender.send(bytes, InternetAddress.loopbackIPv4, 47321);
          await Future<void>.delayed(const Duration(milliseconds: 30));
        }

        final good = {'type': 'ghp-hub', 'name': 'office', 'version': '1', 'port': 8765};
        try {
          for (final bad in [
            'broken',
            '[]',
            '{}',
            {...good, 'type': 'other'},
            {...good, 'port': 0},
            {...good, 'port': 65536},
            {...good, 'port': 1.5},
            {...good, 'name': ''},
            {...good, 'name': 'x' * 201},
            {...good, 'version': 1},
            ' ' * 4097,
          ]) {
            await send(bad);
          }
          expect(discovery.hubs, isEmpty);
          await send(good);
          expect(discovery.hubs.single.name, 'office');
          expect(discovery.hubs.single.url, 'http://127.0.0.1:8765');
          expect(discovery.hubs.single.online, isTrue);
          expect(discovery.hubs.single.manual, isFalse);
          expect(timers.length, 1);
          timers.single.elapse();
          expect(discovery.hubs.single.online, isFalse);
          await send(good);
          expect(discovery.hubs.single.online, isTrue);
          expect(updates.length, greaterThanOrEqualTo(4));
          await discovery.stop();
          expect(timers.last.isActive, isFalse);
          await send({...good, 'name': 'after stop'});
          expect(discovery.hubs.single.name, 'office');
        } finally {
          sender.close();
          await discovery.stop();
          await subscription.cancel();
        }
      },
      zoneSpecification: ZoneSpecification(
        createTimer: (self, parent, zone, duration, callback) {
          if (duration == const Duration(seconds: 15)) {
            final timer = SilenceTimer(zone.bindCallback(callback));
            timers.add(timer);
            return timer;
          }
          return parent.createTimer(zone, duration, callback);
        },
      ),
    );
  });

  test('manual hubs persist, restore offline, ping, expire and delete', () async {
    final timers = <SilenceTimer>[];
    await runZoned(
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server.listen((r) async {
          r.response.write(jsonEncode({'name': 'manual', 'version': '1'}));
          await r.response.close();
        });
        final discovery = HubDiscovery(storeFile: store, listen: false);
        final restored = HubDiscovery(storeFile: store, listen: false);
        try {
          await discovery.start();
          final h = await discovery.addManual('127.0.0.1:${server.port}/');
          expect(h.manual, isTrue);
          expect(h.online, isTrue);
          expect((jsonDecode(await File(store).readAsString()) as List).length, 1);
          await discovery.stop();
          final pinged = restored.changes.firstWhere((hubs) => hubs.isNotEmpty && hubs.single.online);
          await restored.start();
          expect(restored.hubs.single.online, isFalse);
          await pinged.timeout(const Duration(seconds: 3));
          expect(restored.hubs.single.name, 'manual');
          timers.last.elapse();
          expect(restored.hubs.single.online, isFalse);
          await restored.removeManual(h.url);
          expect(restored.hubs, isEmpty);
          expect(jsonDecode(await File(store).readAsString()), isEmpty);
        } finally {
          await discovery.stop();
          await restored.stop();
          await server.close(force: true);
        }
      },
      zoneSpecification: ZoneSpecification(
        createTimer: (self, parent, zone, duration, callback) {
          if (duration == const Duration(seconds: 15)) {
            final timer = SilenceTimer(zone.bindCallback(callback));
            timers.add(timer);
            return timer;
          }
          return parent.createTimer(zone, duration, callback);
        },
      ),
    );
  });
  test('bad stored entries and failed manual endpoints do not add hubs', () async {
    await File(store).writeAsString(
      jsonEncode([
        null,
        {},
        {'url': 'file:///bad', 'name': 'bad', 'manual': true},
      ]),
    );
    final discovery = HubDiscovery(storeFile: store, listen: false);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((r) async {
      r.response.write('{"name":"","version":"1"}');
      await r.response.close();
    });
    try {
      await discovery.start();
      expect(discovery.hubs, isEmpty);
      await expectLater(discovery.addManual('127.0.0.1:${server.port}'), throwsA(isA<HubApiException>()));
      await expectLater(discovery.addManual('8.8.8.8:8765'), throwsArgumentError);
      expect(discovery.hubs, isEmpty);
    } finally {
      await discovery.stop();
      await server.close(force: true);
    }
  });
}
