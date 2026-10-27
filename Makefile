# Thin wrapper around CMake. Each target reconfigures first (cheap) so the
# embedded GIT_HASH always matches HEAD.

CMAKE ?= cmake
JOBS  ?= $(shell getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)

.PHONY: all tsan stats test clean

all:
	$(CMAKE) -S . -B build -DCMAKE_BUILD_TYPE=release
	$(CMAKE) --build build -j $(JOBS)

tsan:
	$(CMAKE) -S . -B build-tsan -DCMAKE_BUILD_TYPE=tsan
	$(CMAKE) --build build-tsan -j $(JOBS)

stats:
	$(CMAKE) -S . -B build-stats -DCMAKE_BUILD_TYPE=release -DQUEUE_STATS=ON
	$(CMAKE) --build build-stats -j $(JOBS)

# Runs the tests in both the release and the tsan build.
test: all tsan
	ctest --test-dir build --output-on-failure --no-tests=ignore
	ctest --test-dir build-tsan --output-on-failure --no-tests=ignore

clean:
	rm -rf build build-tsan build-stats
