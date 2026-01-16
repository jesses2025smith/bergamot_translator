# bergamot_translator

A Flutter FFI plugin that provides FFI bindings for the [Bergamot Translator](https://github.com/browsermt/bergamot-translator) library.

## Overview

This library is an FFI wrapper for the Bergamot Translator, enabling Flutter applications to use offline machine translation capabilities directly from Dart code.

## Platform Support

### Supported Platforms

- **Linux**: Can compile for Linux and Android applications
- **macOS**: Can compile for macOS, iOS, and Android applications

### Unsupported Platforms

- **Windows**: Currently cannot be compiled successfully

## Prerequisites

Before building this plugin, you need to initialize the submodules and apply the patch file to the third-party dependencies:

```bash
# Initialize submodules (if not already done)
git submodule update --init --recursive

# Apply the patch file from the project root directory
# The patch paths are relative to the project root
git apply third_party/patches/00-bergamot-translator.patch
```

**Note**: The patch file must be applied from the project root directory, not from within the submodule directory, because the patch paths are relative to the project root.

The patch file (`third_party/patches/00-bergamot-translator.patch`) contains necessary modifications to the third-party dependencies for successful compilation.

## Getting Started

### Installation

Add `bergamot_translator` to your `pubspec.yaml`:

```yaml
dependencies:
  bergamot_translator:
    path: ../bergamot_translator  # or use git dependency
```

### Usage

For example code and usage demonstrations, please refer to the [example](./example) directory.

## Project Structure

This plugin follows the standard Flutter FFI plugin structure:

* `src`: Contains the native source code and CMakeLists.txt for building the native library
* `lib`: Contains the Dart code that defines the API and calls into native code using `dart:ffi`
* `third_party`: Contains third-party dependencies including bergamot-translator
* Platform folders (`android`, `ios`, `linux`, `macos`): Contains build files for each platform

## Building Native Code

The native build systems used by this FFI plugin are:

* **Android**: Gradle, which invokes the Android NDK for native builds
  * See `android/build.gradle`
* **iOS and macOS**: Xcode, via CocoaPods
  * See `ios/bergamot_translator.podspec`
  * See `macos/bergamot_translator.podspec`
* **Linux**: CMake
  * See `linux/CMakeLists.txt`

## Generating FFI Bindings

The Dart bindings are generated from the header file (`src/bergamot_translator.h`) using `package:ffigen`.

To regenerate the bindings:

```bash
dart run ffigen --config ffigen.yaml
```

## Usage Notes

- Very short-running native functions can be directly invoked from any isolate
- Longer-running functions should be invoked on a helper isolate to avoid dropping frames in Flutter applications

## Example

See the [example](./example) directory for a complete working example demonstrating how to use this plugin.

## Additional Resources

- [Flutter FFI Documentation](https://docs.flutter.dev/development/platform-integration/c-interop)
- [Bergamot Translator](https://github.com/mozilla/bergamot-translator)
- [Flutter Documentation](https://docs.flutter.dev)

## License

See the LICENSE file for details.
