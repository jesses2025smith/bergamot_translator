# Third-party library CMake configuration and policies

# Detect Android platform
if(ANDROID)
    message(STATUS "Configuring for Android platform")
    
    # Disable threads to avoid FindThreads issues on Android
    # Reference: offline-translator sets USE_THREADS OFF
    set(USE_THREADS OFF CACHE BOOL "Use threads" FORCE)
    
    # Disable CPU auto-detection to avoid -march=native issues
    # Reference: offline-translator sets AUTO_CPU_DETECT OFF
    set(AUTO_CPU_DETECT OFF CACHE BOOL "Disable CPU feature detection" FORCE)
    
    # Enable SIMD utils for ARM platform (required for NEON support)
    # Reference: marian-dev/CMakeLists.txt line 78: set(USE_SIMD_UTILS ON) for ARM
    # This enables simd_utils.h which provides NEON implementations of _mm_* functions
    set(USE_SIMD_UTILS ON CACHE BOOL "Enable simde to target instruction sets" FORCE)
    
    # Disable WASM compatible sources (required for proper ARM/NEON support)
    # Reference: offline-translator sets USE_WASM_COMPATIBLE_SOURCES OFF
    set(USE_WASM_COMPATIBLE_SOURCES OFF CACHE BOOL "Enable the minimal marian sources that compile to wasm" FORCE)
    
    # Ensure ANDROID_ARM_NEON is enabled for ARM platforms
    # Reference: bergamot-translator/.github/workflows/arm.yml line 80: -DANDROID_ARM_NEON=TRUE
    # This ensures __ARM_NEON or __ARM_NEON__ macros are defined by the compiler
    if(ANDROID_ABI MATCHES "arm")
        set(ANDROID_ARM_NEON TRUE CACHE BOOL "Enable ARM NEON support" FORCE)
        message(STATUS "Enabling ARM NEON support for Android ABI ${ANDROID_ABI}")
    endif()
    
    # Force CMAKE_TARGET_ARCHITECTURE_CODE to "arm" for Android ARM platforms
    # This ensures marian-dev's CMakeLists.txt correctly detects ARM and enables USE_SIMD_UTILS
    # Reference: marian-dev/CMakeLists.txt line 68: if(${CMAKE_TARGET_ARCHITECTURE_CODE} MATCHES "arm")
    if(ANDROID_ABI MATCHES "arm")
        # Set CMAKE_TARGET_ARCHITECTURE_CODE before marian-dev's CMakeLists.txt processes it
        # This is a workaround for cross-compilation where TargetArch.cmake may not work correctly
        set(CMAKE_TARGET_ARCHITECTURE_CODE "arm" CACHE STRING "Target architecture code" FORCE)
        message(STATUS "Setting CMAKE_TARGET_ARCHITECTURE_CODE to 'arm' for Android ABI ${ANDROID_ABI}")
        
        # Add global compile definitions for ARM, FMA, and SSE
        # This ensures simd_utils.h uses NEON instead of x86 intrinsics
        # Reference: marian-dev/CMakeLists.txt line 96: add_compile_definitions(ARM FMA SSE) for ARM
        add_compile_definitions(ARM FMA SSE)
        message(STATUS "Adding global ARM FMA SSE compile definitions for Android ARM platform")
    endif()

    # Android uses UTF-8 for filesystem encoding in practice; avoid iconv/nl_langinfo dependencies in pathie-cpp.
    # This needs to be GLOBAL (not per-target) because marian-dev builds its own `pathie-cpp` target.
    add_compile_definitions(PATHIE_ASSUME_UTF8_ON_UNIX)
    message(STATUS "Adding global PATHIE_ASSUME_UTF8_ON_UNIX compile definition for Android")
    
    # Use internal PCRE2 for ssplit-cpp (required for Android)
    # Reference: offline-translator sets SSPLIT_USE_INTERNAL_PCRE2 ON
    set(SSPLIT_USE_INTERNAL_PCRE2 ON CACHE BOOL "Use internal PCRE2 instead of system PCRE2" FORCE)
    
    # Disable building unnecessary targets (matching offline-translator)
    # Reference: offline-translator sets COMPILE_LIBRARY_ONLY ON
    set(COMPILE_LIBRARY_ONLY ON CACHE BOOL "Build only the Marian library and exclude all executables" FORCE)
    set(COMPILE_UNIT_TESTS OFF CACHE BOOL "Compile unit tests" FORCE)
    set(COMPILE_EXAMPLES OFF CACHE BOOL "Compile examples" FORCE)
    set(COMPILE_SERVER OFF CACHE BOOL "Compile marian-server" FORCE)
    set(ENABLE_CACHE_STATS OFF CACHE BOOL "Enable stats on cache" FORCE)
    set(USE_MKL OFF CACHE BOOL "Compile with MKL support" FORCE)
    
    # Override BUILD_ARCH for Android - cannot use 'native' in cross-compilation
    # Reference: offline-translator sets BUILD_ARCH based on ANDROID_ABI
    if(NOT DEFINED BUILD_ARCH)
        if(ANDROID_ABI STREQUAL "arm64-v8a")
            set(BUILD_ARCH "armv8-a" CACHE STRING "Build architecture" FORCE)
        elseif(ANDROID_ABI STREQUAL "armeabi-v7a")
            set(BUILD_ARCH "armv7-a" CACHE STRING "Build architecture" FORCE)
        elseif(ANDROID_ABI MATCHES "x86_64")
            set(BUILD_ARCH "x86-64" CACHE STRING "Build architecture" FORCE)
        elseif(ANDROID_ABI MATCHES "x86")
            set(BUILD_ARCH "i686" CACHE STRING "Build architecture" FORCE)
        else()
            # Default to generic ARM if ABI is unknown
            set(BUILD_ARCH "armv8-a" CACHE STRING "Build architecture" FORCE)
        endif()
        message(STATUS "Setting BUILD_ARCH to ${BUILD_ARCH} for Android ABI ${ANDROID_ABI}")
    endif()
    
    # Android-specific thread configuration (as fallback if USE_THREADS is enabled elsewhere)
    # Android NDK has pthread support built-in, but CMake's FindThreads needs hints
    set(CMAKE_HAVE_THREADS_LIBRARY 1 CACHE INTERNAL "Android has threads support")
    set(CMAKE_USE_WIN32_THREADS_INIT 0 CACHE INTERNAL "Do not use Win32 threads on Android")
    set(CMAKE_USE_PTHREADS_INIT 1 CACHE INTERNAL "Use pthreads on Android")
    set(THREADS_PREFER_PTHREAD_FLAG ON CACHE INTERNAL "Prefer pthread flag on Android")
    set(Threads_FOUND TRUE CACHE INTERNAL "Threads are available on Android")
endif()

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

# Set USE_INTGEMM option before adding subdirectory (controls whether intgemm is built)
# IMPORTANT: intgemm is x86/SSE-centric and includes <emmintrin.h>. For Android ARM (arm64-v8a/armeabi-v7a)
# this causes compilation failures ("emmintrin.h only meant for x86/x64").
# Align behavior with marian-dev upstream: ARM builds should use RUY/NEON paths instead of intgemm.
if(ANDROID AND ANDROID_ABI MATCHES "arm")
    set(USE_INTGEMM OFF CACHE BOOL "Use INTGEMM" FORCE)
    message(STATUS "Disabling USE_INTGEMM for Android ARM ABI ${ANDROID_ABI}")
else()
    set(USE_INTGEMM ON CACHE BOOL "Use INTGEMM" FORCE)
endif()

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

