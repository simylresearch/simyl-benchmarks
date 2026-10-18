cmake_minimum_required(VERSION 3.22)
project(simyl_cachebench LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif()

# Pinned sources. The hashes are of the GitHub archive of each commit, so the
# build is reproducible without a git checkout. Override ALEPH_SRC/CPPCACHE_SRC
# to point at local extracted copies (same commits) to skip the download.
set(ALEPH_COMMIT    "d37658bf9ad0a64f19717687bee16b4b7c618472")
set(ALEPH_SHA256    "487c8d9128f3a6922f05b0523d8b51c8d294910b7f613c0461d2e9bd155633c9")
set(CPPCACHE_COMMIT "5bfaf38d328a799ba94f8ce64f61155df18d06ee")
set(CPPCACHE_SHA256 "fba93c3be749dbf67dcb67c06c0106ec187e6445cc32d1abdda57584b71bb310")

include(FetchContent)
set(BUILD_TESTS OFF CACHE BOOL "Aleph-w tests" FORCE)
set(BUILD_EXAMPLES OFF CACHE BOOL "Aleph-w examples" FORCE)
set(BUILD_OPTIMIZED ON CACHE BOOL "Aleph-w optimized build" FORCE)

if(ALEPH_SRC)
  FetchContent_Declare(aleph SOURCE_DIR "${ALEPH_SRC}")
else()
  FetchContent_Declare(aleph
    URL "https://github.com/lrleon/Aleph-w/archive/${ALEPH_COMMIT}.tar.gz"
    URL_HASH "SHA256=${ALEPH_SHA256}")
endif()
if(CPPCACHE_SRC)
  FetchContent_Declare(cppcache SOURCE_DIR "${CPPCACHE_SRC}")
else()
  FetchContent_Declare(cppcache
    URL "https://github.com/lrleon/cpp-cache/archive/${CPPCACHE_COMMIT}.tar.gz"
    URL_HASH "SHA256=${CPPCACHE_SHA256}")
endif()
FetchContent_MakeAvailable(aleph)
FetchContent_Populate(cppcache)   # header-only; no CMake project needed

add_executable(cachebench-cpp src/cachebench.cpp)
target_include_directories(cachebench-cpp PRIVATE "${cppcache_SOURCE_DIR}/include" "${aleph_SOURCE_DIR}")
target_link_libraries(cachebench-cpp PRIVATE Aleph::Aleph pthread)
target_compile_options(cachebench-cpp PRIVATE -O2 -Wall -Wextra)
target_compile_definitions(cachebench-cpp PRIVATE
  CACHEBENCH_VERSION="lrleon/cpp-cache@${CPPCACHE_COMMIT} + lrleon/Aleph-w@${ALEPH_COMMIT}")
