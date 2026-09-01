# WebView Master Tests

This directory contains unit tests for the WebView Master plugin.

## Running Tests

To run all tests:

```bash
flutter test
```

To run tests with coverage:

```bash
flutter test --coverage
```

To run a specific test file:

```bash
flutter test test/web_view_master_test.dart
```

## Test Structure

### `web_view_master_test.dart`
- Tests the main plugin interface
- Verifies platform version retrieval
- Tests method channel communication

### `web_view_master_method_channel_test.dart`
- Tests the method channel implementation
- Verifies platform method calls
- Tests callback handling

## Test Coverage

The tests cover:
- ✅ Platform version retrieval
- ✅ Method channel communication
- ✅ Plugin initialization
- ✅ Basic WebView operations
- ✅ Error handling
- ✅ Mock platform interface

## Adding New Tests

When adding new features, please include corresponding tests:

1. Create test files following the naming convention: `feature_name_test.dart`
2. Use the existing mock platform interface
3. Test both success and error scenarios
4. Include edge cases and boundary conditions

## Mock Platform

The tests use `MockWebViewMasterPlatform` which implements all the required methods:
- `createWebView`
- `loadUrl`
- `evaluateJavaScript`
- `navigation methods`
- `cache and cookie management`
- And more...

## Test Best Practices

1. **Isolation**: Each test should be independent
2. **Mocking**: Use mocks for platform-specific code
3. **Coverage**: Aim for high test coverage
4. **Documentation**: Document complex test scenarios
5. **Maintenance**: Keep tests updated with code changes

## Continuous Integration

These tests are designed to run in CI/CD environments:
- No platform-specific dependencies
- Fast execution
- Reliable results
- Clear error messages

## Future Test Plans

- Integration tests for real WebView functionality
- Performance tests
- Memory leak tests
- Platform-specific behavior tests
- Accessibility tests
