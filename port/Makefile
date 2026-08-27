# Build and verification pipeline for the Rust port.
#
#   make oracle   build the reference engine harness from the C++ sources
#   make tables   regenerate the Rust tables from the C++ binary
#   make sweep    exhaustive plus random differential sweep
#   make soak     large random corpus over the full option matrix
#   make golden   re-freeze the golden hashes (reviewed changes only)
#   make test     cargo test, needs no C++ build
#
SRC      := ../src
INCLUDES := -I$(SRC)/ukengine -I$(SRC)/ukinterface -I$(SRC)/vnconv -I$(SRC)/byteio
# Two accommodations the sources need. They predate the C++11 narrowing
# rules, and they call _tempnam, which is an MSVC name that neither libc
# here provides, so it is redirected to the standard spelling.
#
# clang spells the narrowing flag -Wno-c++11-narrowing and gcc spells it
# -Wno-narrowing, and each complains about the other's spelling as soon as
# it has anything else to report, so the right one is chosen here rather
# than passing both.
NARROWING := $(shell $(CXX) --version 2>/dev/null | grep -qi clang \
             && echo -Wno-c++11-narrowing || echo -Wno-narrowing)
PORTABILITY := -w $(NARROWING) -D_tempnam=tempnam
CXXFLAGS := -O1 -std=c++11 $(PORTABILITY)
ENGINE   := $(SRC)/ukengine/ukengine.cpp $(SRC)/ukengine/inputproc.cpp \
            $(SRC)/ukengine/mactab.cpp $(SRC)/ukengine/usrkeymap.cpp \
            $(SRC)/ukengine/macro.cpp $(SRC)/ukengine/stdafx.cpp \
            $(SRC)/vnconv/charset.cpp $(SRC)/vnconv/convert.cpp \
            $(SRC)/vnconv/data.cpp $(SRC)/vnconv/pattern.cpp \
            $(SRC)/vnconv/error.cpp $(SRC)/vnconv/stdafx.cpp \
            $(SRC)/byteio/byteio.cpp $(SRC)/byteio/prehdr.cpp

.PHONY: all oracle oracle-rust ctx-harness tables rust sweep soak macrosweep \
        keymapsweep quicksweep capi-check ctx-check portability verify golden test bench \
        bench-cpp bench-compare clean

all: oracle rust oracle-rust

oracle: oracle/oracle
oracle/oracle: oracle/oracle.cpp $(ENGINE) $(SRC)/ukinterface/unikey.cpp
	$(CXX) $(CXXFLAGS) -o $@ oracle/oracle.cpp $(SRC)/ukinterface/unikey.cpp \
	    $(ENGINE) $(INCLUDES)

# The same harness source, linked against the Rust library through its C
# ABI. Comparing oracle with oracle-rust tests the ABI end to end.
oracle-rust: oracle/oracle_rust
oracle/oracle_rust: oracle/oracle.cpp rust
	$(CXX) -O1 -std=c++11 -w -DRUST_BACKEND -o $@ oracle/oracle.cpp $(INCLUDES) \
	    target/release/libskey.a

# The context based C ABI, driven by a C harness speaking the same
# protocol. It also runs a second engine instance in parallel, so shared
# state would show up as a divergence.
ctx-harness: oracle/ctx_harness
oracle/ctx_harness: oracle/ctx_harness.c rust
	cc -O1 -w -o $@ oracle/ctx_harness.c -Iskey-capi/include \
	    target/release/libskey.a

tablegen/dump: tablegen/dump.cpp $(ENGINE)
	$(CXX) -O0 -std=c++11 $(PORTABILITY) \
	    -o $@ tablegen/dump.cpp $(ENGINE) $(INCLUDES)

tables: tablegen/dump
	./tablegen/dump > tablegen/tables.rs
	cp tablegen/tables.rs skey-core/src/phonetics/tables.rs
	python3 tablegen/gen_lexi.py > tablegen/lexi_consts.rs
	cp tablegen/lexi_consts.rs skey-core/src/phonetics/lexi_consts.rs

rust:
	cargo build --release

sweep: oracle rust
	python3 difftest/sweep.py

soak: oracle rust
	python3 difftest/soak.py

macrosweep: oracle rust
	python3 difftest/macrosweep.py

keymapsweep: oracle rust
	python3 difftest/keymapsweep.py

# Every sweep again, this time driving the Rust engine through the C ABI.
capi-check: oracle oracle-rust
	RUST_BIN=./oracle/oracle_rust python3 difftest/macrosweep.py
	RUST_BIN=./oracle/oracle_rust python3 difftest/keymapsweep.py

# The five OpenKey style options have no reference to compare against, so
# this checks the shape of their effect instead: each must change something
# and the narrow ones must not change much.
quicksweep: rust
	python3 difftest/quicksweep.py

ctx-check: oracle ctx-harness
	python3 difftest/ctxsweep.py

# The build configurations that have to keep working: no allocator at all,
# WebAssembly, and the optional serde derives.
portability:
	cargo build --release -p skey-core --no-default-features
	cargo test  --release -p skey-core --no-default-features --test smoke
	cargo build --release -p skey-core --target wasm32-unknown-unknown
	cargo test  --release -p skey-core --features serde --test smoke

verify: sweep soak macrosweep keymapsweep quicksweep capi-check ctx-check \
        portability test

golden: oracle rust
	./target/release/difftest hashes 20000 > skey-core/tests/golden_hashes.in
	@echo "golden hashes re-frozen; review the diff before committing"

test:
	cargo test --release

bench:
	cargo test --release --test bench -- --nocapture

# The original engine, benchmarked in process on the same corpus with the
# same command mix and round count, so the comparison is the engine and
# not the I/O around it. -O3 -flto -march=native against Rust's release
# profile with lto and target-cpu=native, so neither side is handicapped.
bench/bench_cpp_o3: bench/bench.cpp $(ENGINE) $(SRC)/ukinterface/unikey.cpp
	$(CXX) -O3 -flto -march=native -std=c++11 $(PORTABILITY) \
	    -o $@ bench/bench.cpp \
	    $(SRC)/ukinterface/unikey.cpp $(ENGINE) $(INCLUDES)

bench-cpp: bench/bench_cpp_o3

bench-compare: bench-cpp
	RUSTFLAGS="-C target-cpu=native" cargo build --release
	./target/release/difftest gen 20000 > /tmp/bench_corpus.txt
	python3 bench/compare.py

clean:
	rm -f oracle/oracle oracle/oracle_rust oracle/ctx_harness tablegen/dump \
	      bench/bench_cpp_o3
	cargo clean
