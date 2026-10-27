# queues

Benchmarks comparing concurrent FIFO queues (lock-based vs. lock-free) in C++20.
Standard library and pthreads only. Builds on macOS (Apple clang) and Linux x86-64
(GCC or Clang).

> **Status:** bare scaffold. Only the build system, the layout and the lab
> notebook exist. There is no C++ yet; benchmark code and scripts will be added
> when they are needed.

## Layout

```
CMakeLists.txt  Makefile  .gitignore
include/queues/   queue headers (header-only)
tests/            test programs
notes/            lab-notebook.md
results/          CSV output (kept in git)
figures/          plots
```

## Build and test

```
make          # release build in build/   (-O2 -g -fno-omit-frame-pointer; -march=native on Linux x86-64)
make tsan     # ThreadSanitizer build in build-tsan/   (-O1 -g -fsanitize=thread)
make stats    # release + QUEUE_STATS=ON in build-stats/   (CAS/FAA counters)
make test     # builds, then runs ctest in both build/ and build-tsan/
make clean    # removes build*/
```

The same commands work on macOS and Linux. Each target reconfigures first, so the
`GIT_HASH` embedded in the executable tracks `HEAD` (it is `unknown` outside a git
checkout).

**Adding source files:** edit the block marked `EDIT THESE` at the top of
[CMakeLists.txt](CMakeLists.txt), which follows the usual makefile-template layout:

| Variable | What it holds |
|---|---|
| `EXECUTABLE` | name of the executable (`bench`) |
| `CMPL_SRCS` | its `.cpp` files |
| `TEST_SRCS` | one `.cpp` per test program; each becomes its own executable and a ctest test |
| `HEADER_FILES` | optional; headers are found via the include path, listing them only helps IDEs |
| `SPECIAL_FLAGS` | extra compile flags for every target |
| `LIBS` | extra libraries to link (pthreads is already linked) |

The lists ship empty (the entries are commented out), so nothing is built until you
add files. Source directories other than `include/` must be added to the include path
in `CMakeLists.txt` (see `queues_configure`) if headers are shared across them.

## Decisions

- **Build types are `release` and `tsan` only.** `CMAKE_BUILD_TYPE` is lowercased
  and anything else is rejected. The flags are exactly as specified, so
  `NDEBUG` is *not* defined and `assert` stays active in release builds.
- **`_GNU_SOURCE` is defined on Linux** for `pthread_setaffinity_np` and
  `sched_getcpu`, and `CMAKE_CXX_EXTENSIONS` is off (`-std=c++20`).
- **File lists live in `CMakeLists.txt`, explicit, no globbing.** The Makefile
  stays a thin wrapper, so there is one source of truth. A listed file that does
  not exist is a configure error, never silently skipped. `GIT_HASH` is defined
  for the executable only, so a new commit does not rebuild the tests.
- **`make test` uses `--no-tests=ignore`** so it succeeds while no tests exist.
