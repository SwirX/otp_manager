import 'package:otp_manager/totp.dart';

void main() async {
  final otpManager = OTPManager();

  // Generate a new secret key
  final secretKey = otpManager.generateSecretKey();
  print('Generated Secret Key: $secretKey');

  // Add the new OTP secret to secure storage
  await otpManager.addOTP("test_code", "test_name", secretKey);

  // Retrieve all OTP secrets from storage
  final allSecrets = await otpManager.getAllOTP();
  if (allSecrets.isEmpty) {
    print('No OTP secrets found in storage.');
    return;
  }

  // Assuming the first secret is the one we just added
  final storedSecret = allSecrets.first.secret;
  final otpGenerator = OTPGenerator(secret: storedSecret);

  // Generate and print current and next OTP codes
  final codes = otpGenerator.getCodes();
  print('Current OTP Code: ${codes.current}');
  print('Next OTP Code: ${codes.next}');

  // Print remaining time for current code
  final remainingTime = otpGenerator.getRemainingTime();
  print('Time remaining before current OTP expires: $remainingTime seconds');
}