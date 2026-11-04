// Ported from GitHub Desktop (MIT): app/src/lib/git (via GitHub+ v1 tests/main/hub/server/announcer.test.ts)
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:github_plus/core/hub/announcer.dart';

void main() {
  test('announcement follows discovery wire contract', () {
    expect(jsonDecode(utf8.decode(announcement('Office', 8765, '1.0'))), {
      'type': 'ghp-hub',
      'name': 'Office',
      'port': 8765,
      'version': '1.0',
    });
  });
  test('UDP sends immediately, repeats and stops', () async {
    final receiver = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    final packets = <Map>[];
    final repeated = Completer<void>();
    final sub = receiver.listen((event) {
      if (event == RawSocketEvent.read) {
        final packet = receiver.receive();
        if (packet != null) packets.add(jsonDecode(utf8.decode(packet.data)) as Map);
        if (packets.length >= 3 && !repeated.isCompleted) repeated.complete();
      }
    });
    HubAnnouncer? announcer;
    try {
      announcer = await HubAnnouncer.start(
        'Test',
        42,
        'v1',
        target: InternetAddress.loopbackIPv4,
        destinationPort: receiver.port,
        interval: const Duration(milliseconds: 40),
      );
      await repeated.future.timeout(const Duration(seconds: 5));
      announcer.stop();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      final count = packets.length;
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(packets.length, count);
      expect(packets.first, {'type': 'ghp-hub', 'name': 'Test', 'port': 42, 'version': 'v1'});
    } finally {
      announcer?.stop();
      await sub.cancel();
      receiver.close();
    }
  });
}
