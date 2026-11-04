// CONTRACT (owner: worker A1). Signatures are fixed; A1 implements the bodies.
import '../models/advanced.dart';

/// Finds conflict blocks (marker size [markerSize], diff3 base sections
/// included). [text] is split on '\n'; a trailing '\r' stays part of each
/// line so line endings survive [applyConflictChoices].
List<ConflictRegion> parseConflictMarkers(String text, {int markerSize = 7}) => throw UnimplementedError('A1');

/// Rewrites [text] taking, for each block index in [choices], its ours,
/// theirs, or both (ours then theirs) side. Blocks without a choice stay as
/// they are (markers included).
String applyConflictChoices(String text, Map<int, ConflictChoice> choices, {int markerSize = 7}) =>
    throw UnimplementedError('A1');
