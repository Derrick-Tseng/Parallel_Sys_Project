cmake_minimum_required(VERSION 3.20)
project(queues LANGUAGES CXX)

# ============================ EDIT THESE ====================================
# Paths are relative to this directory. Lists are explicit (no globbing), so a
# file you forget to list, or list wrongly, is an error rather than silently
# ignored. Reconfigure is automatic: `make` re-runs CMake every time.

#               The name of the benchmark executable
set(EXECUTABLE   bench)

#               Source (.cpp) files of the benchmark executable
#               Add your program source files here.
set(CMPL_SRCS
    # bench/main.cpp
    # bench/harness.cpp
)

#               Test programs: each .cpp here becomes its own executable
#               (named after the file) and is registered with ctest.
set(TEST_SRCS
    # tests/fifo_test.cpp
    # tests/stress_test.cpp
)

#               Header (.h/.hpp) files. Optional: headers are found through the
#               include path regardless; listing them only makes IDEs show them.
set(HEADER_FILES
)

#               Any special compile flags for every target, e.g. -DNAME
set(SPECIAL_FLAGS)

#               Any additional libraries to link in (pthreads is already linked)
set(LIBS)
# ============================================================================

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# --- Build types: release (default) and tsan ---------------------------------
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE release CACHE STRING "Build type: release or tsan" FORCE)
endif()
string(TOLOWER "${CMAKE_BUILD_TYPE}" _build_type)
if(NOT _build_type MATCHES "^(release|tsan)$")
  message(FATAL_ERROR "CMAKE_BUILD_TYPE must be 'release' or 'tsan' (got '${CMAKE_BUILD_TYPE}')")
endif()
set(CMAKE_BUILD_TYPE "${_build_type}" CACHE STRING "Build type: release or tsan" FORCE)

set(CMAKE_CXX_FLAGS_RELEASE "-O2 -g -fno-omit-frame-pointer")
if(CMAKE_SYSTEM_NAME STREQUAL "Linux" AND CMAKE_SYSTEM_PROCESSOR MATCHES "^(x86_64|AMD64)$")
  string(APPEND CMAKE_CXX_FLAGS_RELEASE " -march=native")
endif()
set(CMAKE_CXX_FLAGS_TSAN "-O1 -g -fsanitize=thread")
set(CMAKE_EXE_LINKER_FLAGS_TSAN "-fsanitize=thread")

add_compile_options(-Wall -Wextra -Wpedantic)
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
  add_compile_definitions(_GNU_SOURCE)  # pthread_setaffinity_np, sched_getcpu
endif()

# --- Options -----------------------------------------------------------------
option(QUEUE_STATS "Count CAS / FAA operations (STAT_* macros)" OFF)
if(QUEUE_STATS)
  add_compile_definitions(QUEUE_STATS)
endif()

# Embedded at configure time. The Makefile reconfigures on every build, so the
# hash tracks HEAD; it is "unknown" outside a git checkout.
execute_process(
  COMMAND git rev-parse --short HEAD
  WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
  OUTPUT_VARIABLE GIT_HASH
  OUTPUT_STRIP_TRAILING_WHITESPACE
  RESULT_VARIABLE _git_rc
  ERROR_QUIET)
if(NOT _git_rc EQUAL 0 OR GIT_HASH STREQUAL "")
  set(GIT_HASH "unknown")
endif()
message(STATUS "queues: build=${CMAKE_BUILD_TYPE} stats=${QUEUE_STATS} git=${GIT_HASH}")

find_package(Threads REQUIRED)

# --- Targets -----------------------------------------------------------------
# Header-only queues.
add_library(queues_headers INTERFACE)
target_include_directories(queues_headers INTERFACE "${CMAKE_SOURCE_DIR}/include")
target_link_libraries(queues_headers INTERFACE Threads::Threads)

# The lists at the top decide what is built. Empty lists build nothing, so the
# scaffold configures cleanly before any sources are written.
enable_testing()

# Settings shared by the benchmark and the tests.
function(queues_configure target)
  target_link_libraries(${target} PRIVATE queues_headers ${LIBS})
  target_compile_options(${target} PRIVATE ${SPECIAL_FLAGS})
  if(HEADER_FILES)
    target_sources(${target} PRIVATE ${HEADER_FILES})
  endif()
endfunction()

if(CMPL_SRCS)
  add_executable(${EXECUTABLE} ${CMPL_SRCS})
  queues_configure(${EXECUTABLE})
  # Only this target sees GIT_HASH, so a new commit does not rebuild the tests.
  target_compile_definitions(${EXECUTABLE} PRIVATE GIT_HASH="${GIT_HASH}")
endif()

foreach(_src IN LISTS TEST_SRCS)
  get_filename_component(_test "${_src}" NAME_WE)
  add_executable(${_test} ${_src})
  queues_configure(${_test})
  add_test(NAME ${_test} COMMAND ${_test})
endforeach()
