# Third-party library include directories

# Bergamot translator root directory
# Located at: third_party/bergamot-translator/
# Used for: 3rd_party/marian-dev/src/3rd_party/CLI/CLI.hpp, 3rd_party/yaml-cpp/yaml.h, etc.
# This is needed because parser.h includes paths relative to bergamot-translator root
set(BERGAMOT_TRANSLATOR_ROOT_INCLUDE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/bergamot-translator")

# Bergamot translator headers
# Located at: third_party/bergamot-translator/src/
# Used for: translator/*.h includes
set(BERGAMOT_TRANSLATOR_INCLUDE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/bergamot-translator/src")

# Marian-dev headers (dependency of bergamot-translator)
# Located at: third_party/bergamot-translator/3rd_party/marian-dev/src/
# Used for: data/types.h, data/vocab_base.h, common/*.h, etc.
set(MARIAN_DEV_INCLUDE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/bergamot-translator/3rd_party/marian-dev/src")

# Marian-dev 3rd_party headers (for sentencepiece, absl, etc.)
# Located at: third_party/bergamot-translator/3rd_party/marian-dev/src/3rd_party/
# Used for: sentencepiece/third_party/absl/strings/string_view.h, etc.
set(MARIAN_DEV_3RD_PARTY_INCLUDE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/bergamot-translator/3rd_party/marian-dev/src/3rd_party")

# SSplit-cpp headers (sentence splitter)
# Located at: third_party/bergamot-translator/3rd_party/ssplit-cpp/src/ssplit/
# Used for: ssplit.h (text_processor.h includes "ssplit.h")
set(SSPLIT_CPP_INCLUDE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/bergamot-translator/3rd_party/ssplit-cpp/src/ssplit")

# YAML-cpp library (required for bergamot-translator parser)
# Located at: third_party/bergamot-translator/3rd_party/marian-dev/src/3rd_party/yaml-cpp/
set(YAML_CPP_DIR "${CMAKE_CURRENT_SOURCE_DIR}/bergamot-translator/3rd_party/marian-dev/src/3rd_party/yaml-cpp")
file(GLOB YAML_CPP_SOURCES 
    ${YAML_CPP_DIR}/*.cpp
    ${YAML_CPP_DIR}/contrib/*.cpp
)

# Create yaml-cpp static library
add_library(yaml-cpp STATIC ${YAML_CPP_SOURCES})

# Set properties for yaml-cpp
set_target_properties(yaml-cpp PROPERTIES
    CXX_STANDARD 17
    CXX_STANDARD_REQUIRED ON
    POSITION_INDEPENDENT_CODE ON
)

# Add include directories for yaml-cpp
target_include_directories(yaml-cpp PUBLIC
    ${YAML_CPP_DIR}/..
    ${YAML_CPP_DIR}
)

# Add compile options for yaml-cpp
target_compile_options(yaml-cpp PRIVATE
    -Wno-unused-value
    -Wno-unused-parameter
    -Wno-unused-variable
    -Wno-deprecated-declarations  # Suppress deprecated iterator warnings
    -fPIC
)

# CLD2 language detection library
# Set CLD2_DIR before including cld2.cmake for correct path resolution
set(CLD2_DIR "${CMAKE_CURRENT_SOURCE_DIR}/cld2")
include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/cld2.cmake)

# CLD2 language detection headers
# Located at: third_party/cld2/public/
# Used for: compact_lang_det.h
set(CLD2_INCLUDE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/cld2/public")

# Create an interface library to propagate include directories
add_library(third_party_includes INTERFACE)

target_include_directories(third_party_includes INTERFACE
    ${BERGAMOT_TRANSLATOR_ROOT_INCLUDE_DIR}
    ${BERGAMOT_TRANSLATOR_INCLUDE_DIR}
    ${MARIAN_DEV_INCLUDE_DIR}
    ${MARIAN_DEV_3RD_PARTY_INCLUDE_DIR}
    ${SSPLIT_CPP_INCLUDE_DIR}
    ${CLD2_INCLUDE_DIR}
)

# Set C++ standard to C++17 (required by bergamot-translator)
target_compile_features(third_party_includes INTERFACE cxx_std_17)

# Build bergamot-translator library
# Collect all source files from bergamot-translator
set(BERGAMOT_TRANSLATOR_SOURCES
    ${BERGAMOT_TRANSLATOR_INCLUDE_DIR}/translator/byte_array_util.cpp
    ${BERGAMOT_TRANSLATOR_INCLUDE_DIR}/translator/text_processor.cpp
    ${BERGAMOT_TRANSLATOR_INCLUDE_DIR}/translator/translation_model.cpp
    ${BERGAMOT_TRANSLATOR_INCLUDE_DIR}/translator/request.cpp
    ${BERGAMOT_TRANSLATOR_INCLUDE_DIR}/translator/batching_pool.cpp
    ${BERGAMOT_TRANSLATOR_INCLUDE_DIR}/translator/aggregate_batching_pool.cpp
    ${BERGAMOT_TRANSLATOR_INCLUDE_DIR}/translator/response_builder.cpp
    ${BERGAMOT_TRANSLATOR_INCLUDE_DIR}/translator/quality_estimator.cpp
    ${BERGAMOT_TRANSLATOR_INCLUDE_DIR}/translator/batch.cpp
    ${BERGAMOT_TRANSLATOR_INCLUDE_DIR}/translator/annotation.cpp
    ${BERGAMOT_TRANSLATOR_INCLUDE_DIR}/translator/service.cpp
    ${BERGAMOT_TRANSLATOR_INCLUDE_DIR}/translator/parser.cpp
    ${BERGAMOT_TRANSLATOR_INCLUDE_DIR}/translator/response.cpp
    ${BERGAMOT_TRANSLATOR_INCLUDE_DIR}/translator/html.cpp
    ${BERGAMOT_TRANSLATOR_INCLUDE_DIR}/translator/xh_scanner.cpp
)

# Create bergamot-translator static library
add_library(bergamot-translator STATIC ${BERGAMOT_TRANSLATOR_SOURCES})

# Set C++ standard for bergamot-translator
set_target_properties(bergamot-translator PROPERTIES
    CXX_STANDARD 17
    CXX_STANDARD_REQUIRED ON
    POSITION_INDEPENDENT_CODE ON  # Required for linking into shared libraries
)

# Link include directories and yaml-cpp library
target_link_libraries(bergamot-translator PUBLIC 
    third_party_includes
    yaml-cpp
)

# Add compile options to handle potential issues
target_compile_options(bergamot-translator PRIVATE
    -Wno-unused-parameter
    -Wno-unused-variable
    -Wno-unused-value  # Suppress "expression result unused" warnings
    -Wno-deprecated-declarations  # Suppress deprecated iterator warnings from yaml-cpp
    -fPIC  # Position Independent Code - required for linking into shared libraries
)

# Build minimal marian data library (for Word::ZERO, FastOpt::uniqueNullPtr, createLoggers and other static symbols)
# We need to compile vocab.cpp which contains the definitions of Word::ZERO, Word::NONE, etc.
# and fastopt.cpp which contains FastOpt::uniqueNullPtr
# and logging.cpp which contains createLoggers function
# Located at: third_party/bergamot-translator/3rd_party/marian-dev/src/
set(MARIAN_DATA_SOURCES
    ${MARIAN_DEV_INCLUDE_DIR}/data/vocab.cpp
    ${MARIAN_DEV_INCLUDE_DIR}/data/default_vocab.cpp
    ${MARIAN_DEV_INCLUDE_DIR}/common/fastopt.cpp
    ${MARIAN_DEV_INCLUDE_DIR}/common/logging.cpp
)

# Create minimal marian data static library
add_library(marian-data STATIC ${MARIAN_DATA_SOURCES})

# Set properties for marian-data
set_target_properties(marian-data PROPERTIES
    CXX_STANDARD 17
    CXX_STANDARD_REQUIRED ON
    POSITION_INDEPENDENT_CODE ON
)

# Link include directories
target_link_libraries(marian-data PUBLIC third_party_includes)

# Add compile options
target_compile_options(marian-data PRIVATE
    -Wno-unused-parameter
    -Wno-unused-variable
    -Wno-unused-value
    -Wno-deprecated-declarations
    -fPIC
)

# Link marian-data to bergamot-translator
target_link_libraries(bergamot-translator PUBLIC marian-data)

# Note: bergamot-translator also depends on full marian and ssplit libraries
# The original bergamot-translator CMakeLists.txt links: marian ssplit
# We're building a minimal marian-data library for essential symbols like Word::ZERO.
# If more marian symbols are needed, the full marian library will need to be built.

