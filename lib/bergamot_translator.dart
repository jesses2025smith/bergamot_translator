import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'bergamot_translator_bindings_generated.dart';

/// Bergamot 翻译器异常
class BergamotException implements Exception {
  final String message;
  final int? errorCode;

  BergamotException(this.message, [this.errorCode]);

  @override
  String toString() =>
      'BergamotException: $message${errorCode != null ? ' (code: $errorCode)' : ''}';
}

/// 语言检测结果
class DetectionResult {
  /// 语言代码（如 "en", "zh"）
  final String language;

  /// 是否可靠
  final bool isReliable;

  /// 置信度（0-100）
  final int confidence;

  DetectionResult({
    required this.language,
    required this.isReliable,
    required this.confidence,
  });

  @override
  String toString() =>
      'DetectionResult(language: $language, isReliable: $isReliable, confidence: $confidence)';
}

/// Bergamot 翻译器
class BergamotTranslator {
  static const String _libName = 'bergamot_translator';

  /// 动态库实例
  static ffi.DynamicLibrary? _dylib;

  /// 绑定实例
  static BergamotTranslatorBindings? _bindings;

  /// 初始化动态库
  static void _ensureInitialized() {
    if (_dylib != null && _bindings != null) return;

    _dylib = () {
      if (Platform.isMacOS || Platform.isIOS) {
        return ffi.DynamicLibrary.open('$_libName.framework/$_libName');
      }
      if (Platform.isAndroid || Platform.isLinux) {
        return ffi.DynamicLibrary.open('lib$_libName.so');
      }
      if (Platform.isWindows) {
        return ffi.DynamicLibrary.open('$_libName.dll');
      }
      throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
    }();

    _bindings = BergamotTranslatorBindings(_dylib!);
  }

  /// 初始化翻译服务
  ///
  /// 必须在调用其他方法之前调用此方法。
  ///
  /// 抛出 [BergamotException] 如果初始化失败。
  static void initializeService() {
    _ensureInitialized();
    final result = _bindings!.bergamot_initialize_service();
    if (result != 0) {
      throw BergamotException('Failed to initialize service', result);
    }
  }

  /// 加载模型到缓存
  ///
  /// [cfg] 模型配置字符串（YAML格式）
  /// [key] 模型缓存键，用于后续翻译时引用此模型
  ///
  /// 抛出 [BergamotException] 如果加载失败。
  static void loadModel(String cfg, String key) {
    _ensureInitialized();
    final cfgPtr = cfg.toNativeUtf8();
    final keyPtr = key.toNativeUtf8();
    try {
      final result = _bindings!.bergamot_load_model(
        cfgPtr.cast<ffi.Char>(),
        keyPtr.cast<ffi.Char>(),
      );
      if (result != 0) {
        // 提供更详细的错误信息
        throw BergamotException(
          'Failed to load model: $key. '
          'Please check: 1) Model files exist and are accessible, '
          '2) Config YAML format is correct, '
          '3) File paths in config are absolute and valid.',
          result,
        );
      }
    } catch (e) {
      if (e is BergamotException) {
        rethrow;
      }
      throw BergamotException('Unexpected error loading model $key: $e');
    } finally {
      malloc.free(cfgPtr);
      malloc.free(keyPtr);
    }
  }

  /// 批量翻译
  ///
  /// [inputs] 要翻译的文本列表
  /// [key] 模型缓存键（必须已通过 [loadModel] 加载）
  ///
  /// 返回翻译结果列表，顺序与输入列表对应。
  ///
  /// 抛出 [BergamotException] 如果翻译失败。
  static List<String> translateMultiple(List<String> inputs, String key) {
    if (inputs.isEmpty) {
      return [];
    }

    _ensureInitialized();

    // 分配输入字符串数组
    final inputPtrs = inputs
        .map((s) => s.toNativeUtf8().cast<ffi.Char>())
        .toList();
    final inputsArray = malloc.allocate<ffi.Pointer<ffi.Char>>(
      ffi.sizeOf<ffi.Pointer<ffi.Char>>() * inputs.length,
    );

    for (int i = 0; i < inputs.length; i++) {
      inputsArray[i] = inputPtrs[i];
    }

    final keyPtr = key.toNativeUtf8().cast<ffi.Char>();
    final outputsPtr = malloc.allocate<ffi.Pointer<ffi.Pointer<ffi.Char>>>(
      ffi.sizeOf<ffi.Pointer<ffi.Pointer<ffi.Char>>>(),
    );
    final outputCountPtr = malloc<ffi.Int32>(ffi.sizeOf<ffi.Int32>());

    try {
      final result = _bindings!.bergamot_translate_multiple(
        inputsArray,
        inputs.length,
        keyPtr,
        outputsPtr,
        outputCountPtr.cast(),
      );

      if (result != 0) {
        throw BergamotException('Failed to translate', result);
      }

      final outputCount = outputCountPtr[0];
      final outputsArray = outputsPtr.value;

      final translations = <String>[];
      for (int i = 0; i < outputCount; i++) {
        final strPtr = outputsArray[i];
        translations.add(strPtr.cast<Utf8>().toDartString());
      }

      // 释放 C 分配的内存
      _bindings!.bergamot_free_string_array(outputsArray, outputCount);

      return translations;
    } finally {
      // 释放输入字符串
      for (final ptr in inputPtrs) {
        malloc.free(ptr);
      }
      malloc.free(inputsArray);
      malloc.free(keyPtr);
      malloc.free(outputsPtr);
      malloc.free(outputCountPtr);
    }
  }

  /// 翻译单个文本
  ///
  /// [input] 要翻译的文本
  /// [key] 模型缓存键（必须已通过 [loadModel] 加载）
  ///
  /// 返回翻译结果。
  ///
  /// 抛出 [BergamotException] 如果翻译失败。
  static String translate(String input, String key) {
    final results = translateMultiple([input], key);
    if (results.isEmpty) {
      throw BergamotException('Translation returned empty result');
    }
    return results.first;
  }

  /// 枢轴翻译（通过中间语言）
  ///
  /// [inputs] 要翻译的文本列表
  /// [firstKey] 第一个模型缓存键（源语言 -> 中间语言）
  /// [secondKey] 第二个模型缓存键（中间语言 -> 目标语言）
  ///
  /// 返回翻译结果列表，顺序与输入列表对应。
  ///
  /// 抛出 [BergamotException] 如果翻译失败。
  static List<String> pivotMultiple(
    List<String> inputs,
    String firstKey,
    String secondKey,
  ) {
    if (inputs.isEmpty) {
      return [];
    }

    _ensureInitialized();

    // 分配输入字符串数组
    final inputPtrs = inputs
        .map((s) => s.toNativeUtf8().cast<ffi.Char>())
        .toList();
    final inputsArray = malloc.allocate<ffi.Pointer<ffi.Char>>(
      ffi.sizeOf<ffi.Pointer<ffi.Char>>() * inputs.length,
    );

    for (int i = 0; i < inputs.length; i++) {
      inputsArray[i] = inputPtrs[i];
    }

    final firstKeyPtr = firstKey.toNativeUtf8().cast<ffi.Char>();
    final secondKeyPtr = secondKey.toNativeUtf8().cast<ffi.Char>();
    final outputsPtr = malloc.allocate<ffi.Pointer<ffi.Pointer<ffi.Char>>>(
      ffi.sizeOf<ffi.Pointer<ffi.Pointer<ffi.Char>>>(),
    );
    final outputCountPtr = malloc<ffi.Int32>(ffi.sizeOf<ffi.Int32>());

    try {
      final result = _bindings!.bergamot_pivot_multiple(
        firstKeyPtr,
        secondKeyPtr,
        inputsArray,
        inputs.length,
        outputsPtr,
        outputCountPtr.cast(),
      );

      if (result != 0) {
        throw BergamotException('Failed to pivot translate', result);
      }

      final outputCount = outputCountPtr[0];
      final outputsArray = outputsPtr.value;

      final translations = <String>[];
      for (int i = 0; i < outputCount; i++) {
        final strPtr = outputsArray[i];
        translations.add(strPtr.cast<Utf8>().toDartString());
      }

      // 释放 C 分配的内存
      _bindings!.bergamot_free_string_array(outputsArray, outputCount);

      return translations;
    } finally {
      // 释放输入字符串
      for (final ptr in inputPtrs) {
        malloc.free(ptr);
      }
      malloc.free(inputsArray);
      malloc.free(firstKeyPtr);
      malloc.free(secondKeyPtr);
      malloc.free(outputsPtr);
      malloc.free(outputCountPtr);
    }
  }

  /// 枢轴翻译单个文本（通过中间语言）
  ///
  /// [input] 要翻译的文本
  /// [firstKey] 第一个模型缓存键（源语言 -> 中间语言）
  /// [secondKey] 第二个模型缓存键（中间语言 -> 目标语言）
  ///
  /// 返回翻译结果。
  ///
  /// 抛出 [BergamotException] 如果翻译失败。
  static String pivot(String input, String firstKey, String secondKey) {
    final results = pivotMultiple([input], firstKey, secondKey);
    if (results.isEmpty) {
      throw BergamotException('Pivot translation returned empty result');
    }
    return results.first;
  }

  /// 检测语言
  ///
  /// [text] 待检测的文本
  /// [hint] 可选的语言提示（如 "en", "zh"），可为 null
  ///
  /// 返回 [DetectionResult] 包含检测到的语言信息。
  ///
  /// 抛出 [BergamotException] 如果检测失败。
  static DetectionResult detectLanguage(String text, [String? hint]) {
    _ensureInitialized();

    final textPtr = text.toNativeUtf8();
    final hintPtr = hint?.toNativeUtf8();
    final resultPtr = malloc.allocate<BergamotDetectionResult>(
      ffi.sizeOf<BergamotDetectionResult>(),
    );

    try {
      final result = _bindings!.bergamot_detect_language(
        textPtr.cast<ffi.Char>(),
        hintPtr?.cast<ffi.Char>() ?? ffi.Pointer<ffi.Char>.fromAddress(0),
        resultPtr,
      );

      if (result != 0) {
        throw BergamotException('Failed to detect language', result);
      }

      final detectionResult = resultPtr.ref;
      final languageBytes = detectionResult.language;
      // 将 Array<Char> 转换为字符串
      final languageList = <int>[];
      for (int i = 0; i < 8; i++) {
        final char = languageBytes[i];
        if (char == 0) break;
        languageList.add(char);
      }
      final language = String.fromCharCodes(languageList);

      return DetectionResult(
        language: language,
        isReliable: detectionResult.is_reliable != 0,
        confidence: detectionResult.confidence,
      );
    } finally {
      malloc.free(textPtr);
      if (hintPtr != null) {
        malloc.free(hintPtr);
      }
      malloc.free(resultPtr);
    }
  }

  /// 清理资源（释放所有模型和服务）
  ///
  /// 在应用程序退出前调用此方法以释放所有资源。
  static void cleanup() {
    if (_bindings != null) {
      _bindings!.bergamot_cleanup();
    }
  }
}
