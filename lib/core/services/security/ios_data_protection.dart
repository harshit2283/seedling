import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import '../error_reporter.dart';

/// Hardens on-disk memory storage on iOS via the native
/// `MediaFileProtectionPlugin` channel:
/// - sets `NSFileProtectionCompleteUntilFirstUserAuthentication` on the
///   directory and everything already inside it, and
/// - sets `NSURLIsExcludedFromBackupKey` so iCloud/iTunes backups never hold
///   the database or media (the key that decrypts the database is
///   device-only too; see `seedlingIOSOptions`).
///
/// Because backups no longer include memories, the Privacy settings tell
/// people to use Export or sync to keep a copy off the phone.
class IosDataProtection {
  static const MethodChannel defaultChannel = MethodChannel(
    'com.seedling.media/file_protection',
  );

  final MethodChannel _channel;
  final bool _isIOS;
  final ErrorReporter _errorReporter;

  IosDataProtection({
    MethodChannel? channel,
    bool? isIOS,
    ErrorReporter? errorReporter,
  }) : _channel = channel ?? defaultChannel,
       _isIOS = isIOS ?? Platform.isIOS,
       _errorReporter = errorReporter ?? const ErrorReporter();

  /// Applies file protection and backup exclusion to [directoryPath].
  /// Best effort: failures are reported, never thrown.
  Future<void> hardenDirectory(String directoryPath) async {
    if (!_isIOS || directoryPath.isEmpty) return;
    try {
      await _channel.invokeMethod<void>('protectPath', {
        'path': directoryPath,
        'recursive': true,
      });
    } catch (error, stackTrace) {
      _errorReporter.report(
        error,
        stack: stackTrace,
        context: 'IosDataProtection.protectPath',
      );
    }
    try {
      await _channel.invokeMethod<void>('excludeFromBackup', {
        'path': directoryPath,
      });
    } catch (error, stackTrace) {
      _errorReporter.report(
        error,
        stack: stackTrace,
        context: 'IosDataProtection.excludeFromBackup',
      );
    }
  }
}
