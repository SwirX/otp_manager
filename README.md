# OTP Manager Flutter Package

A Flutter package for managing Time-Based One-Time Password (TOTP) codes. This package allows you to generate, store, and retrieve OTP codes with associated titles and account names, making it easier to manage multiple OTP entries.

## Features

- **Generate OTP Secret Keys**: Create new OTP secrets.
- **Store and Retrieve OTP Entries**: Save and load OTP entries with associated titles and account names.
- **Generate OTP Codes**: Obtain current and next OTP codes.
- **Calculate Time Remaining**: Get the remaining time before the current OTP code expires.

## Installation

To use this package in your Flutter project, add the following to your `pubspec.yaml` file:

```yaml
dependencies:
  otp_manager:
    git:
      url: https://github.com/SwirX/otp_manager.git
      ref: main
```

Then run flutter pub get to install the package.

## Usage

### Generating a Secret Key

```dart
import 'package:otp_manager/otp_manager.dart';

final otpManager = OTPManager();
final secret = otpManager.generateSecretKey();
print('Generated Secret: $secret');
```

## Adding an OTP Entry

```dart
final otpManager = OTPManager();
await otpManager.addOTP("My App", "myaccount@example.com", secret);
```

## Retrieving OTP Entries

```dart
final otpList = await otpManager.getAllOTP();
for (var otp in otpList) {
  final otpGenerator = OTPGenerator(secret: otp.secret);
  print('Title: ${otp.title}');
  print('Account: ${otp.accountName}');
  print('Current Code: ${otpGenerator.getCurrentCode()}');
  print('Next Code: ${otpGenerator.getNextCode()}');
  print('Time Remaining: ${otpGenerator.getRemainingTime()} seconds');
}
```

## Classes

### OTPManager

- **generateSecretKey({int length = 32})**: Generates a new OTP secret key.
- **addOTP(String title, String accountName, String secret)**: Adds an OTP entry to storage.
- **getAllOTP()**: Retrieves all stored OTP entries.

### OTPGenerator

- **getCurrentCode()**: Generates the current OTP code.
- **getNextCode()**: Generates the next OTP code.
- **getRemainingTime()**: Returns the time left before the current OTP code expires.

### OTPEntry

- **title**: The title or description of the OTP entry.
- **accountName**: The account name associated with the OTP entry.
- **secret**: The OTP secret key.

## Contributing

Contributions are welcome! Please open an issue or a pull request if you have any suggestions or improvements.

## License

This package is licensed under the BSD 3-clause LICENCE. See the [LICENCE](https://github.com/SwirX/otp_manager/blob/main/LICENSE) file for more information.
