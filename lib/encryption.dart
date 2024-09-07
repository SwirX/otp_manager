import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import 'package:encrypt/encrypt.dart';
import 'dart:convert';


class EncryptionHelper {
  static const int ivLength = 16; // AES block size
  static const int keyLength = 32; // 256-bit key

  static Uint8List deriveKey(String password, {int length = keyLength}) {
    final salt = utf8.encode('0.3si56.060de.fr50r60.ezf8'); // You can use a different salt
    final key = pbkdf2(utf8.encode(password), salt, length);
    return key;
  }

  static Uint8List pbkdf2(List<int> password, List<int> salt, int length) {
    final keyDerivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(Uint8List.fromList(salt), 1000, length));
    return keyDerivator.process(Uint8List.fromList(password));
  }

  static Uint8List encryptString(String plainText, String password) {
    final key = Key(deriveKey(password));
    final iv = IV.fromSecureRandom(ivLength);
    final encrypter = Encrypter(AES(key));

    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return Uint8List.fromList(iv.bytes + encrypted.bytes);
  }

  static String decryptString(Uint8List encryptedData, String password) {
    final key = Key(deriveKey(password));
    final iv = IV(encryptedData.sublist(0, ivLength));
    final encryptedBytes = encryptedData.sublist(ivLength);
    final encrypter = Encrypter(AES(key));

    final decrypted = encrypter.decrypt(Encrypted(encryptedBytes), iv: iv);
    return decrypted;
  }
}


void main() {
  final password = '';
  final plainText = jsonEncode([
    {"title": "random", "account": "random", "type": "TOTP", "digits": 6},
    {"title": "random", "account": "random", "type": "TOTP", "digits": 6}
  ]);

  // Encrypting the string
  final encrypted = EncryptionHelper.encryptString(plainText, password);
  print('Encrypted: $encrypted');

  try {
    // Decrypting the string
    final decrypted = EncryptionHelper.decryptString(encrypted, password);
    print('Decrypted: ${jsonDecode(decrypted)}');
  } catch (e) {
    print("Cannot decrypt, wrong password");
  }
}
