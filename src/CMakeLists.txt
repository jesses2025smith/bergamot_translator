# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(bergamot_translator_library VERSION 0.0.1 LANGUAGES CXX)

# Include third-party library configurations
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/../third_party third_party)

add_library(bergamot_translator SHARED
  "bergamot_translator.cpp"
)

set_target_properties(bergamot_translator PROPERTIES
  PUBLIC_HEADER bergamot_translator.h
  OUTPUT_NAME "bergamot_translator"
)

# Set C++ standard to C++17 (required by bergamot-translator)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

target_compile_definitions(bergamot_translator PUBLIC DART_SHARED_LIB)

# Link third-party include directories and libraries
# Note: bergamot-translator must come before other libraries to ensure proper symbol resolution
target_link_libraries(bergamot_translator PRIVATE 
    bergamot-translator
    third_party_includes
    cld2
    yaml-cpp
    marian-data
)

# Add compile options to suppress warnings
target_compile_options(bergamot_translator PRIVATE
    -Wno-unused-value  # Suppress "expression result unused" warnings
    -Wno-deprecated-declarations  # Suppress deprecated iterator warnings from yaml-cpp
)

if (ANDROID)
  # Support Android 15 16k page size
  target_link_options(bergamot_translator PRIVATE "-Wl,-z,max-page-size=16384")
endif()
