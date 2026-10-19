import 'package:uuid/uuid.dart';

/// The single source of entry sync identifiers.
///
/// Every entry gets a random (v4) UUID when it is first saved. Manual links,
/// sync records and remote deletions all refer to entries by this value, so
/// there must be exactly one generator: IDs minted anywhere else would later
/// be "repaired" by sync and silently break the links that point at them.
abstract final class SyncId {
  static const _uuid = Uuid();
  static final _pattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  /// A fresh random sync identifier.
  static String generate() => _uuid.v4();

  /// Whether [value] is a well-formed UUID that sync will accept as-is.
  static bool isValid(String? value) =>
      value != null && value.isNotEmpty && _pattern.hasMatch(value);
}
