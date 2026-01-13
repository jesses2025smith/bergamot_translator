import 'package:bergamot_translator/bergamot_translator.dart' as bergamot;

import '../model/language.dart';
import '../model/manager.dart';
import '../utils/utils.dart' as utils;
import '../utils/logger.dart';

/// 翻译结果
class TranslationResult {
  final String translated;
  final String? error;

  TranslationResult.success(this.translated) : error = null;
  TranslationResult.error(this.error) : translated = '';

  bool get isSuccess => error == null;
}

/// 翻译服务
class TranslationService {
  static TranslationService? _instance;
  
  static TranslationService get instance {
    _instance ??= TranslationService._();
    return _instance!;
  }

  // 跟踪已加载的模型，避免重复加载
  final _loadedModels = <String>{};

  TranslationService._() {
    // 初始化翻译服务
    try {
      bergamot.BergamotTranslator.initializeService();
      info('TranslationService initialized');
    } catch (e) {
      error('Failed to initialize TranslationService: $e');
    }
  }

  /// 检查语言对的模型是否已准备好（已安装）
  Future<bool> isModelReady(Language from, Language to) async {
    if (from == to) {
      return true;
    }
    
    final translationPairs = ModelManager.getTranslationPairs(from, to);
    for (final pair in translationPairs) {
      final isInstalled = await ModelManager.isLanguagePairInstalled(
        pair.$1,
        pair.$2,
      );
      if (!isInstalled) {
        return false;
      }
    }
    return true;
  }

  /// 预加载模型
  Future<void> preloadModel(Language from, Language to) async {
    final translationPairs = ModelManager.getTranslationPairs(from, to);
    for (final pair in translationPairs) {
      final languageCode = '${pair.$1.code}${pair.$2.code}';
      
      // 检查模型是否已加载（避免重复加载）
      if (_loadedModels.contains(languageCode)) {
        debug('Model $languageCode already loaded, skipping');
        continue; // 已加载，跳过
      }
      
      debug('Preloading model with key: $languageCode');
      try {
        final config = await ModelManager.generateConfig(pair.$1, pair.$2);
        bergamot.BergamotTranslator.loadModel(config, languageCode);
        _loadedModels.add(languageCode); // 标记为已加载
        info('Preloaded model for ${pair.$1.displayName} -> ${pair.$2.displayName}');
      } catch (e) {
        error('Failed to preload model $languageCode: $e');
        rethrow;
      }
    }
  }

  /// 翻译文本
  Future<TranslationResult> translate(
    Language from,
    Language to,
    String text,
  ) async {
    try {
      // 如果源语言和目标语言相同，直接返回
      if (from == to) {
        return TranslationResult.success(text);
      }

      // 数字不需要翻译
      if (double.tryParse(text.trim()) != null) {
        return TranslationResult.success(text);
      }

      // 空白文本直接返回
      if (text.trim().isEmpty) {
        return TranslationResult.success('');
      }

      // 检查语言对是否已安装
      final translationPairs = ModelManager.getTranslationPairs(from, to);
      for (final pair in translationPairs) {
        final isInstalled = await ModelManager.isLanguagePairInstalled(
          pair.$1,
          pair.$2,
        );
        if (!isInstalled) {
          return TranslationResult.error(
            'Language pair ${pair.$1.displayName} -> ${pair.$2.displayName} not installed',
          );
        }
      }

      // 预加载模型
      await preloadModel(from, to);

      // 执行翻译
      final result = await _performTranslation(translationPairs, [text]);
      if (result.isEmpty) {
        return TranslationResult.error('Translation returned empty result');
      }

      return TranslationResult.success(result.first);
    } catch (e) {
      error('Translation failed: $e');
      return TranslationResult.error('Translation failed: ${e.toString()}');
    }
  }

  /// 批量翻译
  Future<TranslationResult> translateMultiple(
    Language from,
    Language to,
    List<String> texts,
  ) async {
    try {
      if (from == to) {
        return TranslationResult.success(texts.join('\n'));
      }

      // 检查语言对是否已安装
      final translationPairs = ModelManager.getTranslationPairs(from, to);
      for (final pair in translationPairs) {
        final isInstalled = await ModelManager.isLanguagePairInstalled(
          pair.$1,
          pair.$2,
        );
        if (!isInstalled) {
          return TranslationResult.error(
            'Language pair ${pair.$1.displayName} -> ${pair.$2.displayName} not installed',
          );
        }
      }

      // 预加载模型
      await preloadModel(from, to);

      // 执行翻译
      final results = await _performTranslation(translationPairs, texts);
      return TranslationResult.success(results.join('\n'));
    } catch (e) {
      error('Batch translation failed: $e');
      return TranslationResult.error('Batch translation failed: ${e.toString()}');
    }
  }

  /// 执行翻译
  Future<List<String>> _performTranslation(
    List<(Language, Language)> pairs,
    List<String> texts,
  ) async {
    // 预加载所有模型
    for (final pair in pairs) {
      final config = await ModelManager.generateConfig(pair.$1, pair.$2);
      final languageCode = '${pair.$1.code}${pair.$2.code}';
      bergamot.BergamotTranslator.loadModel(config, languageCode);
    }

    if (pairs.length == 1) {
      // 直接翻译
      final code = '${pairs[0].$1.code}${pairs[0].$2.code}';
      return bergamot.BergamotTranslator.translateMultiple(texts, code);
    } else if (pairs.length == 2) {
      // 枢轴翻译
      final toEng = '${pairs[0].$1.code}${pairs[0].$2.code}';
      final fromEng = '${pairs[1].$1.code}${pairs[1].$2.code}';
      return bergamot.BergamotTranslator.pivotMultiple(texts, toEng, fromEng);
    }

    return [];
  }

  /// 检测语言
  Future<Language?> detectLanguage(String text, [Language? hint]) async {
    try {
      final result = bergamot.BergamotTranslator.detectLanguage(
        text,
        hint?.code,
      );
      
      // 将语言代码转换为Language枚举
      try {
        return Language.values.firstWhere(
          (lang) => lang.code == result.language,
        );
      } catch (e) {
        debug('Unknown language code: ${result.language}');
        return null;
      }
    } catch (e) {
      error('Language detection failed: $e');
      return null;
    }
  }

  /// 清理资源
  static void cleanup() {
    bergamot.BergamotTranslator.cleanup();
  }
}
