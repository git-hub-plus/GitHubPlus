// Ported from GitHub Desktop (MIT): app/src/lib/git (via GitHub+ v1 src/main/hub/server/announcer.ts)
import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _discoveryPort = 47321;

List<int> announcement(String name, int port, String version) =>
    utf8.encode(jsonEncode({'type': 'ghp-hub', 'name': name, 'port': port, 'version': version}));

/// Dart does not expose interface netmasks. The limited broadcast reaches
/// directly connected IPv4 LANs without guessing a subnet prefix.
class HubAnnouncer {
  HubAnnouncer._(this._socket, this._timer);
  final RawDatagramSocket _socket;
  final Timer _timer;

  static Future<HubAnnouncer> start(
    String name,
    int port,
    String version, {
    InternetAddress? target,
    int destinationPort = _discoveryPort,
    Duration interval = const Duration(seconds: 5),
  }) async {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.broadcastEnabled = true;
    socket.listen((_) {}, onError: (Object _) {});
    final bytes = announcement(name, port, version);
    void send() {
      try {
        socket.send(bytes, target ?? InternetAddress('255.255.255.255'), destinationPort);
      } on SocketException {
        /* Discovery is best effort. */
      }
    }

    send();
    return HubAnnouncer._(socket, Timer.periodic(interval, (_) => send()));
  }

  void stop() {
    _timer.cancel();
    _socket.close();
  }
}
