// Ported from GitHub+ v1 src/main/hub/shared/validation.ts.
import 'dart:io';

/// LAN-only policy shared by the hub host and the discovery client:
/// loopback, RFC 1918, link-local, IPv6 unique-local/link-local, and
/// IPv4-mapped IPv6 forms of those.
bool isPrivateAddress(String input) {
  final address = InternetAddress.tryParse(input.toLowerCase().split('%').first);
  if (address == null) return false;
  final bytes = address.rawAddress;
  if (address.type == InternetAddressType.IPv4) return _privateV4(bytes);
  final mapped = bytes.take(10).every((b) => b == 0) && bytes[10] == 0xff && bytes[11] == 0xff;
  if (mapped) return _privateV4(bytes.sublist(12));
  final loopback = bytes.take(15).every((b) => b == 0) && bytes[15] == 1;
  return loopback || (bytes[0] & 0xfe) == 0xfc || (bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0x80);
}

bool _privateV4(List<int> b) =>
    b[0] == 127 ||
    b[0] == 10 ||
    (b[0] == 172 && b[1] >= 16 && b[1] <= 31) ||
    (b[0] == 192 && b[1] == 168) ||
    (b[0] == 169 && b[1] == 254);

final _repositoryName = RegExp(r'^[a-zA-Z0-9_.-]{1,100}$');
final _reservedName = RegExp(r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)', caseSensitive: false);

/// Hub repository names: safe as a folder name on Windows and in URLs.
bool isValidRepositoryName(String name) =>
    _repositoryName.hasMatch(name) &&
    !name.contains('..') &&
    !name.endsWith('.') &&
    !name.startsWith('-') &&
    !_reservedName.hasMatch(name);

/// Preference order for LAN addresses shown to users: home/office router
/// ranges first, then other private IPv4, then IPv6. Lower is better.
int lanAddressRank(String address) {
  final host = address.replaceAll(RegExp(r'^\[|\]$'), '');
  if (host.contains(':')) return (int.tryParse(host.split(':').first, radix: 16) ?? 0) & 0xffc0 == 0xfe80 ? 7 : 6;
  final parts = host.split('.').map(int.tryParse).toList();
  final a = parts.isNotEmpty ? parts[0] ?? 0 : 0, b = parts.length > 1 ? parts[1] ?? 0 : 0;
  if (a == 192 && b == 168) return 0;
  if (a == 172 && b >= 16 && b <= 31) return 1;
  if (a == 10) return 2;
  if (a == 169 && b == 254) return 5;
  return 4;
}
