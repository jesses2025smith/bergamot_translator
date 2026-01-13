# Third-party library CMake configuration and policies

# Suppress CMake warnings from third-party libraries
# Set policy to suppress exec_program deprecation warning (CMP0153)
# This is needed because FindSSE.cmake uses exec_program
if(POLICY CMP0153)
    cmake_policy(SET CMP0153 OLD)
endif()

# Enable SentencePiece support (required for .spm vocab files)
# This must be set before including bergamot-translator subdirectories
if(NOT DEFINED USE_SENTENCEPIECE)
    set(USE_SENTENCEPIECE ON CACHE BOOL "Enable SentencePiece support for .spm vocab files")
endif()

# Ensure USE_STATIC_LIBS is set so SentencePiece is built as static library
if(NOT DEFINED USE_STATIC_LIBS)
    set(USE_STATIC_LIBS ON CACHE BOOL "Link statically against non-system libs")
endif()

# Set CMake policy to allow older cmake_minimum_required versions
# SentencePiece requires CMake 3.1, but newer CMake versions have removed compatibility with < 3.5
# Setting CMAKE_POLICY_VERSION_MINIMUM to 3.5 allows the subdirectory to configure
set(CMAKE_POLICY_VERSION_MINIMUM 3.5)

# Set USE_INTGEMM option before adding subdirectory (required for intgemm to be built)
# Reference: marian-dev/CMakeLists.txt line 87: set(USE_INTGEMM ON)
# This must be set before add_subdirectory so that intgemm library is built
set(USE_INTGEMM ON CACHE BOOL "Use INTGEMM" FORCE)

# Set USE_RUY option before adding subdirectory (required for ruy library to be built)
# RUY library is already in include path (third_party/bergamot-translator/3rd_party/marian-dev/src/3rd_party/ruy)
# This must be set before add_subdirectory so that ruy library is built
# Reference: 3rd_party/CMakeLists.txt line 19: if(USE_RUY) ... add_subdirectory(ruy EXCLUDE_FROM_ALL)
set(USE_RUY ON CACHE BOOL "Use RUY library" FORCE)

# Set USE_RUY_SGEMM option before adding subdirectory (required for CPU matrix multiplication)
# This enables the use of RUY library for optimized float matrix multiplication on CPU
# This must be set before add_subdirectory so that marian library uses RUY for sgemm
set(USE_RUY_SGEMM ON CACHE BOOL "Use RUY SGEMM for CPU matrix multiplication" FORCE)

# Set SentencePiece-specific options before adding subdirectory (matching original Android project)
# regardless of -DUSE_STATIC_LIBS setting always build sentencepiece statically
set(SPM_ENABLE_SHARED OFF CACHE BOOL "Builds shared libaries in addition to static libraries." FORCE)

