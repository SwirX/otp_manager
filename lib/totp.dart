import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:otp/otp.dart';
import 'package:otp_manager/encryption.dart';

enum OTPType { TOTP, HOTP }

class OTPManager {
  final secStorage = const FlutterSecureStorage();
  final StreamController<List<OTPEntry>> _otpStreamController =
      StreamController.broadcast();
  Timer? _updateTimer;

  Stream<List<OTPEntry>> get otpStream => _otpStreamController.stream;

  OTPManager() {
    _startUpdateTimer();
  }

  void _startUpdateTimer() {
    _updateTimer = Timer.periodic(Duration(seconds: 1), (_) {
      _emitUpdatedOTPs();
    });
  }

  void _emitUpdatedOTPs() async {
    final otpList = await getAllOTP();
    _otpStreamController.add(otpList);
  }

  Future<List<OTPEntry>> getAllOTP() async {
    try {
      final otpString = await secStorage.read(key: "otps");
      final otpList = (jsonDecode(otpString ?? "[]") as List<dynamic>)
          .map((e) => OTPEntry.fromJson(e))
          .toList();
      return otpList;
    } catch (e) {
      if (kDebugMode) {
        print("Error reading OTPs from storage: $e");
      }
      return [];
    }
  }

  Future<void> addOTP(
    String title,
    String accountName,
    String secret, {
    int period = 30,
    String algorithm = "SHA1",
    int digits = 6,
    String type = "TOTP",
  }) async {
    try {
      algorithm.replaceAll("ALGORITHM_", "");
      final otpList = await getAllOTP();
      if (!otpList.any((e) => e.secret == secret)) {
        otpList.add(OTPEntry(
          title,
          accountName.replaceAll("$title:", ""),
          secret,
          period: period,
          algorithm: Algorithm.values.firstWhere(
              (algo) => algo.name.toLowerCase() == algorithm.toLowerCase(),
              orElse: () => Algorithm.SHA1),
          digits: digits,
          type: OTPType.values.firstWhere(
              (otptype) => otptype.name.toLowerCase() == type.toLowerCase(),
              orElse: () => OTPType.TOTP),
        ));
        await secStorage.write(
            key: "otps",
            value: jsonEncode(otpList.map((e) => e.toJson()).toList()));

        _emitUpdatedOTPs(); // Notify listeners of the update
      }
      if (kDebugMode) {
        print("Already existing");
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error adding OTP to storage: $e");
      }
      throw Exception("Failed to add OTP");
    }
  }

  Future<void> bulkAdd(List<OTPEntry> otps) async {
    final oldOtps = await getAllOTP();
    for (final otp in otps) {
      if (!oldOtps.any((e) => e.secret == otp.secret)) {
        oldOtps.add(otp);
      }
    }
    await secStorage.write(
        key: "otps",
        value: jsonEncode(oldOtps.map((e) => e.toJson()).toList()));
    _emitUpdatedOTPs();
  }

  Future<void> removeOTP(String secret) async {
    try {
      final otpList = await getAllOTP();
      otpList.removeWhere((entry) => entry.secret == secret);
      await secStorage.write(
          key: "otps",
          value: jsonEncode(otpList.map((e) => e.toJson()).toList()));
      _emitUpdatedOTPs();
    } catch (e) {
      if (kDebugMode) {
        print("Error removing OTP from storage");
      }
      throw Exception("Failed to remove otp");
    }
  }

  Future<void> editOTP(
      String secret, String? title, String? accountName) async {
    try {
      final otpList = await getAllOTP();
      final otp = otpList.firstWhere((entry) => entry.secret == secret);
      await removeOTP(secret);
      title = title ?? otp.title;
      accountName = accountName ?? otp.accountName;
      addOTP(title, accountName, secret);
    } catch (e) {
      if (kDebugMode) {
        print("Error Editing OTP");
      }
      throw Exception("Failed to edit the OTP");
    }
  }

  /// Generates a new secret key for OTP and returns it.
  String generateSecretKey({int length = 32}) {
    final random = Random.secure();
    final bytes = List<int>.generate(length, (_) => random.nextInt(256));
    return base32Encode(Uint8List.fromList(bytes));
  }

  /// Encodes a list of bytes in Base32.
  String base32Encode(Uint8List data) {
    const base32Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    var output = StringBuffer();
    var currentByte = 0;
    var bitsRemaining = 8;
    for (var byte in data) {
      currentByte = (currentByte << 8) | byte;
      bitsRemaining += 8;
      while (bitsRemaining >= 5) {
        final index = (currentByte >> (bitsRemaining - 5)) & 31;
        output.write(base32Chars[index]);
        bitsRemaining -= 5;
      }
    }
    if (bitsRemaining > 0) {
      output.write(base32Chars[(currentByte << (5 - bitsRemaining)) & 31]);
    }
    return output.toString();
  }

  Future<File> exportAllToFile(String path, {String? password}) async {
    print("\n\n\n\n\nexporting otps....");
    final otps = await getAllOTP();
    final otpString = jsonEncode(otps.map((e) => e.toJson()).toList());
    final file = File(path);
    print("created file");
    print("password check");
    if (password != null) {
      print("\n\n\n\n\n\nencrypted export");
      final encryptedBytes =
          EncryptionHelper.encryptString(otpString, password);
      // Prepend "ENCRYPTED:" to the encrypted content
      final marker = utf8.encode("ENCRYPTED:");
      final markedEncryptedBytes = Uint8List.fromList(marker + encryptedBytes);
      await file.writeAsBytes(markedEncryptedBytes);
    } else {
      print("\n\n\n\n\n\nplain export");
      final bytes = utf8.encode(otpString);
      await file.writeAsBytes(bytes);
    }
    return file;
  }

  Future<Uint8List> exportAllAsBytes({String? password}) async {
    final otps = await getAllOTP();
    final otpString = jsonEncode(otps.map((e) => e.toJson()).toList());
    if (password != null) {
      final encryptedBytes =
          EncryptionHelper.encryptString(otpString, password);
      final marker = utf8.encode("ENCRYPTED:");
      final markedEncryptedBytes = Uint8List.fromList(marker + encryptedBytes);
      return markedEncryptedBytes;
    } else {
      final bytes = utf8.encode(otpString);
      return bytes;
    }
  }

  Future<void> importFromFile(String path, {String? password}) async {
    final file = File(path);
    final fileBytes = await file.readAsBytes();

    // Check if the file starts with the "ENCRYPTED:" marker
    final marker = utf8.encode("ENCRYPTED:");
    final isEncrypted =
        fileBytes.sublist(0, marker.length).toString() == marker.toString();

    if (isEncrypted) {
      if (password == null) {
        throw ArgumentError(
            "Decryption password is required for encrypted files.");
      }

      // Remove the "ENCRYPTED:" marker before decryption
      final encryptedBytes = fileBytes.sublist(marker.length);
      final decryptedString =
          EncryptionHelper.decryptString(encryptedBytes, password);
      final List otps = jsonDecode(decryptedString);
      final otpsObj = otps.map((e) => OTPEntry.fromJson(e)).toList();
      await bulkAdd(otpsObj);
    } else {
      // The file is unencrypted, treat it as plain text
      final otpString = utf8.decode(fileBytes);
      final List<Map<String, dynamic>> otps = jsonDecode(otpString);
      final otpsObj = otps.map((e) => OTPEntry.fromJson(e)).toList();
      await bulkAdd(otpsObj);
    }
  }

  Future<void> importFromBytes(Uint8List bytes, {String? password}) async {
    // Check if the file starts with the "ENCRYPTED:" marker
    final marker = utf8.encode("ENCRYPTED:");
    final isEncrypted =
        bytes.sublist(0, marker.length).toString() == marker.toString();

    if (isEncrypted) {
      if (password == null) {
        throw ArgumentError(
            "Decryption password is required for encrypted files.");
      }

      // Remove the "ENCRYPTED:" marker before decryption
      final encryptedBytes = bytes.sublist(marker.length);
      final decryptedString =
          EncryptionHelper.decryptString(encryptedBytes, password);
      final List otps = jsonDecode(decryptedString);
      final otpsObj = otps.map((e) => OTPEntry.fromJson(e)).toList();
      await bulkAdd(otpsObj);
    } else {
      // The file is unencrypted, treat it as plain text
      final otpString = utf8.decode(bytes);
      final List otps = jsonDecode(otpString);
      final otpsObj = otps.map((e) => OTPEntry.fromJson(e)).toList();
      await bulkAdd(otpsObj);
    }
  }
}

class OTPGenerator {
  final String secret;
  final int interval;
  final Algorithm algorithm;
  final int digits;

  OTPGenerator(
      {required this.secret,
      this.interval = 30,
      this.algorithm = Algorithm.SHA1,
      this.digits = 6});

  /// Generates the current OTP code based on the current time.
  String _getCurrentCode() {
    final currentTimestamp = DateTime.now().millisecondsSinceEpoch;
    return OTP.generateTOTPCodeString(
      secret,
      currentTimestamp,
      algorithm: algorithm,
      interval: interval,
      isGoogle: true,
      length: digits,
    );
  }

  /// Generates the next OTP code that will be valid after the current one expires.
  String _getNextCode() {
    final nextTimestamp =
        DateTime.now().millisecondsSinceEpoch + (interval * 1000);
    return OTP.generateTOTPCodeString(
      secret,
      nextTimestamp,
      algorithm: algorithm,
      interval: interval,
      isGoogle: true,
      length: digits,
    );
  }

  /// Returns the time left (in seconds) before the current OTP code expires.
  int getRemainingTime() {
    final secondsSinceEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return interval - (secondsSinceEpoch % interval);
  }

  /// Generates both the current and next OTP codes.
  OTPCodes getCodes() {
    return OTPCodes(
      current: _getCurrentCode(),
      next: _getNextCode(),
    );
  }
}

class OTPCodes {
  final String current;
  final String next;

  OTPCodes({required this.current, required this.next});
}

class OTPEntry {
  final String secret;
  final int period;
  final int digits;
  final Algorithm algorithm;
  final OTPType type;
  final DateTime addedAt; // New field to store the timestamp
  String title;
  String accountName;

  OTPEntry(
    this.title,
    this.accountName,
    this.secret, {
    this.period = 30,
    this.digits = 6,
    this.algorithm = Algorithm.SHA1,
    this.type = OTPType.TOTP,
    DateTime?
        addedAt, // Optional parameter, defaults to current time if not provided
  }) : addedAt = addedAt ?? DateTime.now() {
    accountName = accountName.replaceAll("$title:", "");
  }

  String get name => title == "" ? accountName : "$title:$accountName";

  Map<String, dynamic> toJson() => {
        'title': title,
        'accountName': accountName,
        'secret': secret,
        'type': type.index,
        'algorithm': algorithm.index,
        'digits': digits,
        'period': period,
        'addedAt': addedAt.toIso8601String(), // Convert DateTime to string
      };

  factory OTPEntry.fromJson(Map<String, dynamic> json) => OTPEntry(
        json['title'],
        json['accountName'],
        json['secret'],
        algorithm: Algorithm.values[json["algorithm"] ?? 0],
        digits: json["digits"] ?? 6,
        period: json["period"] ?? 30,
        type: OTPType.values[json["type"] ?? 0],
        addedAt: DateTime.parse(json['addedAt'] ??
            DateTime.now().toIso8601String()), // Parse string to DateTime
      );
}
