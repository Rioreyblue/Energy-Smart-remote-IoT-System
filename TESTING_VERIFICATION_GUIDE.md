<!-- # Testing Verification Code Guide

This guide explains how to use the testing verification code system for SMS phone verification in your Energy Smart Flutter app.

## Overview

The testing verification system allows developers to test phone verification without sending actual SMS messages. This is useful for development, testing, and debugging purposes.

## Features

- **Testing Mode Toggle**: Enable/disable testing mode in the verification page
- **Predefined Testing Codes**: Use specific codes to test different scenarios
- **Custom Testing Codes**: Use any 6-digit number for basic testing
- **SMS Server Testing**: Server-side testing mode support
- **Debug Tools**: Comprehensive testing utilities

## How to Use

### 1. Enable Testing Mode

1. Navigate to the phone verification page
2. Scroll down to the "Testing Mode" section
3. Toggle the switch to enable testing mode
4. The UI will show available testing codes

### 2. Available Testing Codes

| Code | Scenario | Description |
|------|----------|-------------|
| `123456` | Success | Always succeeds verification |
| `000000` | Invalid | Always fails verification |
| `999999` | Expired | Simulates expired code |
| `111111` | Rate Limit | Simulates too many attempts |
| `222222` | Network Error | Simulates network issues |

### 3. Using Testing Codes

1. **Quick Entry**: Tap the "USE" button next to any testing code to auto-fill it
2. **Manual Entry**: Type any of the predefined codes or any 6-digit number
3. **Verify**: Tap the "Verify Code" button to test the scenario

### 4. Custom Testing Codes

- Any 6-digit number (e.g., `123789`) will be accepted as valid
- Use the "Set Custom Code" option to store a specific code for repeated testing

## Testing Scenarios

### Success Scenario (Code: 123456)
- **Expected Result**: Verification succeeds
- **Use Case**: Test successful verification flow
- **Message**: "Testing verification successful! Welcome to Energy Smart."

### Invalid Scenario (Code: 000000)
- **Expected Result**: Verification fails
- **Use Case**: Test invalid code handling
- **Message**: "Testing code rejected - Invalid scenario"

### Expired Scenario (Code: 999999)
- **Expected Result**: Verification fails
- **Use Case**: Test expired code handling
- **Message**: "Testing code expired - Expired scenario"

### Rate Limit Scenario (Code: 111111)
- **Expected Result**: Verification fails
- **Use Case**: Test rate limiting
- **Message**: "Too many attempts - Rate limit scenario"

### Network Error Scenario (Code: 222222)
- **Expected Result**: Verification fails
- **Use Case**: Test network error handling
- **Message**: "Network error - Network error scenario"

## SMS Server Testing Mode

The SMS server also supports testing mode:

### Enable Server Testing Mode

Set environment variables:
```bash
# Enable testing mode
export TESTING_MODE=true

# Or set NODE_ENV to development
export NODE_ENV=development
```

### Server Testing Endpoints

- `GET /health` - Check server status and testing mode
- `GET /testing-codes` - Get available testing codes
- `POST /send-sms` - Send SMS (simulated in testing mode)

### Server Testing Response

When testing mode is enabled, the server will:
- Simulate SMS sending without actual SMS
- Return testing response with `testing: true`
- Log simulated SMS to console

## Debug Tools

### Verification Test Page

Access the debug verification test page to:
- Test current user status
- Test email verification
- Test phone verification
- Test full verification status
- Test testing mode functionality
- View testing instructions

### Testing Service Methods

```dart
// Check if testing mode is enabled
bool isEnabled = await TestingVerificationService.isTestingModeEnabled();

// Enable/disable testing mode
await TestingVerificationService.setTestingMode(true);

// Validate a testing code
TestingCodeResult result = TestingVerificationService.validateTestingCode('123456');

// Get testing instructions
String instructions = TestingVerificationService.getTestingInstructions();

// Get available scenarios
List<String> scenarios = TestingVerificationService.getTestingScenarios();
```

## Best Practices

### Development
1. **Always enable testing mode** during development
2. **Use predefined codes** to test specific scenarios
3. **Test all scenarios** before deploying
4. **Disable testing mode** in production

### Testing
1. **Test success flow** with code `123456`
2. **Test error handling** with other predefined codes
3. **Test rate limiting** with code `111111`
4. **Test network errors** with code `222222`

### Production
1. **Ensure testing mode is disabled** in production
2. **Verify real SMS functionality** works correctly
3. **Monitor SMS delivery** and verification rates
4. **Have fallback mechanisms** for SMS failures

## Troubleshooting

### Testing Mode Not Working
- Check if testing mode is enabled in the verification page
- Verify the testing service is properly imported
- Check console logs for testing mode status

### Codes Not Working
- Ensure you're using the exact 6-digit codes
- Check if testing mode is enabled
- Verify the code validation logic

### Server Issues
- Check if `TESTING_MODE` environment variable is set
- Verify server logs for testing mode status
- Test server health endpoint

## Security Considerations

### Testing Mode Security
- **Never enable testing mode in production**
- **Use environment variables** to control testing mode
- **Log testing mode usage** for audit purposes
- **Restrict testing mode access** to development environments

### Code Security
- **Testing codes are not secure** and should not be used in production
- **Real verification codes** are time-limited and single-use
- **Rate limiting** applies to both testing and real codes

## Integration with CI/CD

### Automated Testing
```yaml
# Example GitHub Actions workflow
- name: Test Verification System
  run: |
    export TESTING_MODE=true
    flutter test test/verification_test.dart
```

### Environment Configuration
```dart
// Example environment configuration
class Environment {
  static const bool isTestingMode = bool.fromEnvironment('TESTING_MODE', defaultValue: false);
  static const bool isProduction = bool.fromEnvironment('PRODUCTION', defaultValue: false);
}
```

## Support

For issues or questions about the testing verification system:

1. Check the console logs for detailed error messages
2. Use the debug verification test page
3. Verify testing mode is properly enabled
4. Check server health and testing mode status

## Changelog

### Version 1.0.0
- Initial implementation of testing verification system
- Support for predefined testing codes
- Testing mode toggle in verification page
- SMS server testing mode support
- Debug tools and comprehensive testing guide




 -->
