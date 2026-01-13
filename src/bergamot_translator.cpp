#include "bergamot_translator.h"
#include <string>
#include <vector>
#include <unordered_map>
#include <mutex>
#include <cstring>
#include <cstdlib>
#include <iostream>
#include <fstream>

// Bergamot translator includes
#include "translator/byte_array_util.h"
#include "translator/parser.h"
#include "translator/response.h"
#include "translator/response_options.h"
#include "translator/service.h"
#include "translator/utils.h"
#include "compact_lang_det.h"

using namespace marian::bergamot;

// 全局状态
static std::unordered_map<std::string, std::shared_ptr<TranslationModel>> model_cache;
static std::unique_ptr<BlockingService> global_service = nullptr;
static std::mutex service_mutex;
static std::mutex translation_mutex;

// C++ 核心实现函数
namespace {
    void initializeService() {
        std::lock_guard<std::mutex> lock(service_mutex);
        
        if (global_service == nullptr) {
            BlockingService::Config blockingConfig;
            blockingConfig.cacheSize = 256;
            blockingConfig.logger.level = "off";
            global_service = std::make_unique<BlockingService>(blockingConfig);
        }
    }
    
    void loadModelIntoCache(const std::string& cfg, const std::string& key) {
        std::lock_guard<std::mutex> lock(service_mutex);
        
        // 检查模型是否已加载
        if (model_cache.find(key) != model_cache.end()) {
            return; // 模型已加载，直接返回
        }
        
        try {
            // 输出调试信息到 stderr（Flutter 会捕获）
            std::cerr << "[bergamot] Loading model with key: " << key << std::endl;
            std::cerr << "[bergamot] Config length: " << cfg.length() << " bytes" << std::endl;
            
            auto validate = true;
            auto pathsDir = "";
            
            // 解析配置
            std::cerr << "[bergamot] Parsing config..." << std::endl;
            auto options = parseOptionsFromString(cfg, validate, pathsDir);
            std::cerr << "[bergamot] Config parsed successfully" << std::endl;
            
            // 创建模型（这可能会抛出异常）
            std::cerr << "[bergamot] Creating TranslationModel..." << std::endl;
            model_cache[key] = std::make_shared<TranslationModel>(options);
            std::cerr << "[bergamot] Model created successfully for key: " << key << std::endl;
        } catch (const std::exception &e) {
            std::cerr << "[bergamot] ERROR loading model " << key << ": " << e.what() << std::endl;
            // 重新抛出异常，让调用者处理
            throw std::runtime_error("Failed to load model " + key + ": " + e.what());
        } catch (...) {
            std::cerr << "[bergamot] ERROR loading model " << key << ": Unknown exception" << std::endl;
            // 捕获所有其他异常
            throw std::runtime_error("Failed to load model " + key + ": Unknown error");
        }
    }
    
    std::vector<std::string> translateMultiple(std::vector<std::string> &&inputs, const char *key) {
        initializeService();
        
        std::string key_str(key);
        
        // 检查模型是否已加载
        if (model_cache.find(key_str) == model_cache.end()) {
            throw std::runtime_error("Model not loaded: " + key_str);
        }
        
        std::shared_ptr<TranslationModel> model = model_cache[key_str];
        
        std::vector<ResponseOptions> responseOptions;
        responseOptions.reserve(inputs.size());
        for (size_t i = 0; i < inputs.size(); ++i) {
            ResponseOptions opts;
            opts.HTML = false;
            opts.qualityScores = false;
            opts.alignment = false;
            opts.sentenceMappings = false;
            responseOptions.emplace_back(opts);
        }
        
        std::lock_guard<std::mutex> translation_lock(translation_mutex);
        std::vector<Response> responses = global_service->translateMultiple(model, std::move(inputs), responseOptions);
        
        std::vector<std::string> results;
        results.reserve(responses.size());
        for (const auto &response: responses) {
            results.push_back(response.target.text);
        }
        
        return results;
    }
    
    std::vector<std::string> pivotMultiple(const char *firstKey, const char *secondKey, std::vector<std::string> &&inputs) {
        initializeService();
        
        std::string first_key_str(firstKey);
        std::string second_key_str(secondKey);
        
        // 检查模型是否已加载
        if (model_cache.find(first_key_str) == model_cache.end()) {
            throw std::runtime_error("First model not loaded: " + first_key_str);
        }
        if (model_cache.find(second_key_str) == model_cache.end()) {
            throw std::runtime_error("Second model not loaded: " + second_key_str);
        }
        
        std::shared_ptr<TranslationModel> firstModel = model_cache[first_key_str];
        std::shared_ptr<TranslationModel> secondModel = model_cache[second_key_str];
        
        std::vector<ResponseOptions> responseOptions;
        responseOptions.reserve(inputs.size());
        for (size_t i = 0; i < inputs.size(); ++i) {
            ResponseOptions opts;
            opts.HTML = false;
            opts.qualityScores = false;
            opts.alignment = false;
            opts.sentenceMappings = false;
            responseOptions.emplace_back(opts);
        }
        
        std::lock_guard<std::mutex> translation_lock(translation_mutex);
        std::vector<Response> responses = global_service->pivotMultiple(firstModel, secondModel, std::move(inputs), responseOptions);
        
        std::vector<std::string> results;
        results.reserve(responses.size());
        for (const auto &response: responses) {
            results.push_back(response.target.text);
        }
        
        return results;
    }
    
    struct DetectionResult {
        std::string language;
        bool isReliable;
        int confidence;
    };
    
    DetectionResult detectLanguage(const char *text, const char *language_hint = nullptr) {
        bool is_reliable;
        int text_bytes = (int) strlen(text);
        bool is_plain_text = true;
        
        CLD2::Language hint_lang = CLD2::UNKNOWN_LANGUAGE;
        if (language_hint != nullptr && strlen(language_hint) > 0) {
            hint_lang = CLD2::GetLanguageFromName(language_hint);
        }
        
        CLD2::CLDHints hints = {nullptr, nullptr, 0, hint_lang};
        CLD2::Language language3[3];
        int percent3[3];
        double normalized_score3[3];
        int chunk_bytes;
        
        CLD2::ExtDetectLanguageSummary(
                text,
                text_bytes,
                is_plain_text,
                &hints,
                0,
                language3,
                percent3,
                normalized_score3,
                nullptr,
                &chunk_bytes,
                &is_reliable
        );
        
        return DetectionResult{
                CLD2::LanguageCode(language3[0]),
                is_reliable,
                percent3[0]
        };
    }
    
    void cleanup() {
        std::lock_guard<std::mutex> lock(service_mutex);
        global_service.reset();
        model_cache.clear();
    }
}

// C FFI 接口实现
extern "C" {

FFI_PLUGIN_EXPORT int bergamot_initialize_service(void) {
    try {
        initializeService();
        return 0;
    } catch (const std::exception &e) {
        return -1;
    }
}

FFI_PLUGIN_EXPORT int bergamot_load_model(const char* cfg, const char* key) {
    if (cfg == nullptr || key == nullptr) {
        std::cerr << "[bergamot] ERROR: Null pointer in bergamot_load_model" << std::endl;
        return -1;
    }
    
    try {
        std::string cfg_str(cfg);
        std::string key_str(key);
        
        std::cerr << "[bergamot] bergamot_load_model called with key: " << key_str << std::endl;
        
        // 确保服务已初始化
        initializeService();
        std::cerr << "[bergamot] Service initialized" << std::endl;
        
        // 加载模型
        loadModelIntoCache(cfg_str, key_str);
        std::cerr << "[bergamot] Model loaded successfully" << std::endl;
        return 0;
    } catch (const std::exception &e) {
        std::cerr << "[bergamot] EXCEPTION in bergamot_load_model: " << e.what() << std::endl;
        return -1;
    } catch (...) {
        std::cerr << "[bergamot] UNKNOWN EXCEPTION in bergamot_load_model" << std::endl;
        return -1;
    }
}

FFI_PLUGIN_EXPORT int bergamot_translate_multiple(
    const char** inputs,
    int input_count,
    const char* key,
    char*** outputs,
    int* output_count
) {
    if (inputs == nullptr || input_count <= 0 || key == nullptr || outputs == nullptr || output_count == nullptr) {
        return -1;
    }
    
    try {
        std::vector<std::string> cpp_inputs;
        cpp_inputs.reserve(input_count);
        
        for (int i = 0; i < input_count; i++) {
            if (inputs[i] != nullptr) {
                cpp_inputs.emplace_back(inputs[i]);
            } else {
                cpp_inputs.emplace_back("");
            }
        }
        
        std::vector<std::string> translations = translateMultiple(std::move(cpp_inputs), key);
        
        // 分配输出数组
        char** result_array = (char**)malloc(translations.size() * sizeof(char*));
        if (result_array == nullptr) {
            return -1;
        }
        
        for (size_t i = 0; i < translations.size(); ++i) {
            size_t len = translations[i].length();
            result_array[i] = (char*)malloc((len + 1) * sizeof(char));
            if (result_array[i] == nullptr) {
                // 清理已分配的内存
                for (size_t j = 0; j < i; ++j) {
                    free(result_array[j]);
                }
                free(result_array);
                return -1;
            }
            strncpy(result_array[i], translations[i].c_str(), len);
            result_array[i][len] = '\0';
        }
        
        *outputs = result_array;
        *output_count = (int)translations.size();
        return 0;
    } catch (const std::exception &e) {
        return -1;
    }
}

FFI_PLUGIN_EXPORT int bergamot_pivot_multiple(
    const char* first_key,
    const char* second_key,
    const char** inputs,
    int input_count,
    char*** outputs,
    int* output_count
) {
    if (first_key == nullptr || second_key == nullptr || inputs == nullptr || 
        input_count <= 0 || outputs == nullptr || output_count == nullptr) {
        return -1;
    }
    
    try {
        std::vector<std::string> cpp_inputs;
        cpp_inputs.reserve(input_count);
        
        for (int i = 0; i < input_count; i++) {
            if (inputs[i] != nullptr) {
                cpp_inputs.emplace_back(inputs[i]);
            } else {
                cpp_inputs.emplace_back("");
            }
        }
        
        std::vector<std::string> translations = pivotMultiple(first_key, second_key, std::move(cpp_inputs));
        
        // 分配输出数组
        char** result_array = (char**)malloc(translations.size() * sizeof(char*));
        if (result_array == nullptr) {
            return -1;
        }
        
        for (size_t i = 0; i < translations.size(); ++i) {
            size_t len = translations[i].length();
            result_array[i] = (char*)malloc((len + 1) * sizeof(char));
            if (result_array[i] == nullptr) {
                // 清理已分配的内存
                for (size_t j = 0; j < i; ++j) {
                    free(result_array[j]);
                }
                free(result_array);
                return -1;
            }
            strncpy(result_array[i], translations[i].c_str(), len);
            result_array[i][len] = '\0';
        }
        
        *outputs = result_array;
        *output_count = (int)translations.size();
        return 0;
    } catch (const std::exception &e) {
        return -1;
    }
}

FFI_PLUGIN_EXPORT int bergamot_detect_language(
    const char* text,
    const char* hint,
    BergamotDetectionResult* result
) {
    if (text == nullptr || result == nullptr) {
        return -1;
    }
    
    try {
        DetectionResult detection = detectLanguage(text, hint);
        
        // 复制语言代码
        strncpy(result->language, detection.language.c_str(), sizeof(result->language) - 1);
        result->language[sizeof(result->language) - 1] = '\0';
        
        result->is_reliable = detection.isReliable ? 1 : 0;
        result->confidence = detection.confidence;
        
        return 0;
    } catch (const std::exception &e) {
        return -1;
    }
}

FFI_PLUGIN_EXPORT void bergamot_cleanup(void) {
    cleanup();
}

FFI_PLUGIN_EXPORT void bergamot_free_string_array(char** array, int count) {
    if (array == nullptr || count <= 0) {
        return;
    }
    
    for (int i = 0; i < count; i++) {
        if (array[i] != nullptr) {
            free(array[i]);
        }
    }
    free(array);
}

} // extern "C"

