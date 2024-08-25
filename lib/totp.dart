import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:otp/otp.dart';

class OTPManager {
  final secStorage = const FlutterSecureStorage();

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

  Future<void> addOTP(String title, String accountName, String secret,
      {int period = 30}) async {
    try {
      final otpList = await getAllOTP();
      otpList.add(OTPEntry(
        title,
        accountName,
        secret,
        period: period,
      ));
      await secStorage.write(
          key: "otps",
          value: jsonEncode(otpList.map((e) => e.toJson()).toList()));
    } catch (e) {
      if (kDebugMode) {
        print("Error adding OTP to storage: $e");
      }
      throw Exception("Failed to add OTP");
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
}

class OTPGenerator {
  final String secret;
  final int interval;

  OTPGenerator({required this.secret, this.interval = 30});

  /// Generates the current OTP code based on the current time.
  String _getCurrentCode() {
    final currentTimestamp = DateTime.now().millisecondsSinceEpoch;
    return OTP.generateTOTPCodeString(
      secret,
      currentTimestamp,
      interval: interval,
    );
  }

  /// Generates the next OTP code that will be valid after the current one expires.
  String _getNextCode() {
    final nextTimestamp =
        DateTime.now().millisecondsSinceEpoch + interval * 1000;
    return OTP.generateTOTPCodeString(
      secret,
      nextTimestamp,
      interval: interval,
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
  final String title;
  final String secret;
  final int? period;
  String? accountName;

  OTPEntry(this.title, this.accountName, this.secret, {this.period = 30}) {
    if (this.accountName == null) {
      accountName = title;
    }
  }

  /// Converts an OTPEntry to a JSON map.
  Map<String, dynamic> toJson() => {
        'title': title,
        'accountName': accountName,
        'secret': secret,
      };

  /// Creates an OTPEntry from a JSON map.
  factory OTPEntry.fromJson(Map<String, dynamic> json) => OTPEntry(
        json['title'],
        json['accountName'],
        json['secret'],
      );
}
