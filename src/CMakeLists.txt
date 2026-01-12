# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(bergamot_translator_library VERSION 0.0.1 LANGUAGES C)

add_library(bergamot_translator SHARED
  "bergamot_translator.c"
)

set_target_properties(bergamot_translator PROPERTIES
  PUBLIC_HEADER bergamot_translator.h
  OUTPUT_NAME "bergamot_translator"
)

target_compile_definitions(bergamot_translator PUBLIC DART_SHARED_LIB)

if (ANDROID)
  # Support Android 15 16k page size
  target_link_options(bergamot_translator PRIVATE "-Wl,-z,max-page-size=16384")
endif()
