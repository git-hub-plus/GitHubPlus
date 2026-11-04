// EXTENSION POINT (owner: worker H3a). Replace the body; keep the provider name and type.
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Read once by the launcher shell at startup: starts the hub server when
/// the saved hub settings have it enabled.
final hubStartupProvider = Provider<void>((ref) {});
