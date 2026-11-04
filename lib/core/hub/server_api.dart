// Ported from GitHub Desktop (MIT): app/src/lib/git (via GitHub+ v1 src/main/hub/server/server.ts)
import 'validation.dart';

/// Kept separate from the socket transport so the deny path is testable without
/// binding a public network interface. Never consult forwarded HTTP headers.
int hubAddressStatus(String address) => isPrivateAddress(address) ? 200 : 403;

class HubHttpError implements Exception {
  const HubHttpError(this.status, this.message);
  final int status;
  final String message;
  @override
  String toString() => message;
}
