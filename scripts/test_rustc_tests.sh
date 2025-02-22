#!/usr/bin/env bash
set -e

cd $(dirname "$0")/../

source ./scripts/setup_rust_fork.sh

echo "[TEST] Test suite of rustc"
pushd rust

command -v rg >/dev/null 2>&1 || cargo install ripgrep

rm -r tests/ui/{unsized-locals/,lto/,linkage*} || true
for test in $(rg --files-with-matches "lto" tests/{codegen-units,ui,incremental}); do
  rm $test
done

# should-fail tests don't work when compiletest is compiled with panic=abort
for test in $(rg --files-with-matches "//@ should-fail" tests/{codegen-units,ui,incremental}); do
  rm $test
done

for test in $(rg -i --files-with-matches "//(\[\w+\])?~[^\|]*\s*ERR|//@ error-pattern:|//@(\[.*\])? build-fail|//@(\[.*\])? run-fail|-Cllvm-args" tests/ui); do
  rm $test
done

git checkout -- tests/ui/issues/auxiliary/issue-3136-a.rs # contains //~ERROR, but shouldn't be removed
git checkout -- tests/ui/proc-macro/pretty-print-hack/
git checkout -- tests/ui/entry-point/auxiliary/bad_main_functions.rs
rm tests/ui/parser/unclosed-delimiter-in-dep.rs # submodule contains //~ERROR

# missing features
# ================

# vendor intrinsics
rm tests/ui/asm/x86_64/evex512-implicit-feature.rs # unimplemented AVX512 x86 vendor intrinsic

# exotic linkages
rm tests/incremental/hashes/function_interfaces.rs
rm tests/incremental/hashes/statics.rs

# variadic arguments
rm tests/ui/abi/mir/mir_codegen_calls_variadic.rs # requires float varargs
rm tests/ui/abi/variadic-ffi.rs # requires callee side vararg support
rm -r tests/run-make/c-link-to-rust-va-list-fn # requires callee side vararg support
rm tests/ui/delegation/fn-header.rs

# unsized locals
rm -r tests/run-pass-valgrind/unsized-locals

# misc unimplemented things
rm tests/ui/target-feature/missing-plusminus.rs # error not implemented
rm -r tests/run-make/repr128-dwarf # debuginfo test
rm -r tests/run-make/split-debuginfo # same
rm -r tests/run-make/target-specs # i686 not supported by Cranelift
rm -r tests/run-make/mismatching-target-triples # same
rm tests/ui/asm/x86_64/issue-96797.rs # const and sym inline asm operands don't work entirely correctly
rm tests/ui/asm/x86_64/goto.rs # inline asm labels not supported

# requires LTO
rm -r tests/run-make/cdylib
rm -r tests/run-make/issue-64153
rm -r tests/run-make/codegen-options-parsing
rm -r tests/run-make/lto-*
rm -r tests/run-make/reproducible-build-2
rm -r tests/run-make/issue-109934-lto-debuginfo
rm -r tests/run-make/no-builtins-lto
rm -r tests/run-make/reachable-extern-fn-available-lto

# coverage instrumentation
rm tests/ui/consts/precise-drop-with-coverage.rs
rm tests/ui/issues/issue-85461.rs
rm -r tests/ui/instrument-coverage/

# optimization tests
# ==================
rm tests/ui/codegen/issue-28950.rs # depends on stack size optimizations
rm tests/ui/codegen/init-large-type.rs # same
rm tests/ui/issues/issue-40883.rs # same
rm -r tests/run-make/fmt-write-bloat/ # tests an optimization

# backend specific tests
# ======================
rm tests/incremental/thinlto/cgu_invalidated_when_import_{added,removed}.rs # requires LLVM
rm -r tests/run-make/cross-lang-lto # same
rm -r tests/run-make/sepcomp-inlining # same
rm -r tests/run-make/sepcomp-separate # same
rm -r tests/run-make/sepcomp-cci-copies # same
rm -r tests/run-make/volatile-intrinsics # same
rm -r tests/run-make/llvm-ident # same
rm -r tests/run-make/no-builtins-attribute # same
rm -r tests/run-make/pgo-gen-no-imp-symbols # same
rm tests/ui/abi/stack-protector.rs # requires stack protector support
rm -r tests/run-make/emit-stack-sizes # requires support for -Z emit-stack-sizes
rm -r tests/run-make/optimization-remarks-dir # remarks are LLVM specific
rm -r tests/run-make/print-to-output # requires --print relocation-models

# requires asm, llvm-ir and/or llvm-bc emit support
# =============================================
rm -r tests/run-make/emit-named-files
rm -r tests/run-make/multiple-emits
rm -r tests/run-make/output-type-permutations
rm -r tests/run-make/emit-to-stdout
rm -r tests/run-make/compressed-debuginfo
rm -r tests/run-make/symbols-include-type-name
rm -r tests/run-make/notify-all-emit-artifacts
rm -r tests/run-make/reset-codegen-1

# giving different but possibly correct results
# =============================================
rm tests/ui/mir/mir_misc_casts.rs # depends on deduplication of constants
rm tests/ui/mir/mir_raw_fat_ptr.rs # same
rm tests/ui/consts/issue-33537.rs # same
rm tests/ui/consts/const-mut-refs-crate.rs # same

# doesn't work due to the way the rustc test suite is invoked.
# should work when using ./x.py test the way it is intended
# ============================================================
rm -r tests/run-make/remap-path-prefix-dwarf # requires llvm-dwarfdump
rm -r tests/run-make/compiler-builtins # Expects lib/rustlib/src/rust to contains the standard library source

# genuine bugs
# ============
rm -r tests/run-make/extern-fn-explicit-align # argument alignment not yet supported
rm -r tests/run-make/panic-abort-eh_frame # .eh_frame emitted with panic=abort

# bugs in the test suite
# ======================
rm tests/ui/process/nofile-limit.rs # TODO some AArch64 linking issue
rm -r tests/run-make/const_fn_mir # needs-unwind directive accidentally dropped

rm tests/ui/stdio-is-blocking.rs # really slow with unoptimized libstd

cp ../dist/bin/rustdoc-clif ../dist/bin/rustdoc # some tests expect bin/rustdoc to exist

# prevent $(RUSTDOC) from picking up the sysroot built by x.py. It conflicts with the one used by
# rustdoc-clif
cat <<EOF | git apply -
diff --git a/tests/run-make/tools.mk b/tests/run-make/tools.mk
index ea06b620c4c..b969d0009c6 100644
--- a/tests/run-make/tools.mk
+++ b/tests/run-make/tools.mk
@@ -9,7 +9,7 @@ RUSTC_ORIGINAL := \$(RUSTC)
 BARE_RUSTC := \$(HOST_RPATH_ENV) '\$(RUSTC)'
 BARE_RUSTDOC := \$(HOST_RPATH_ENV) '\$(RUSTDOC)'
 RUSTC := \$(BARE_RUSTC) --out-dir \$(TMPDIR) -L \$(TMPDIR) \$(RUSTFLAGS) -Ainternal_features
-RUSTDOC := \$(BARE_RUSTDOC) -L \$(TARGET_RPATH_DIR)
+RUSTDOC := \$(BARE_RUSTDOC)
 ifdef RUSTC_LINKER
 RUSTC := \$(RUSTC) -Clinker='\$(RUSTC_LINKER)'
 RUSTDOC := \$(RUSTDOC) -Clinker='\$(RUSTC_LINKER)'
diff --git a/src/tools/run-make-support/src/rustdoc.rs b/src/tools/run-make-support/src/rustdoc.rs
index 9607ff02f96..b7d97caf9a2 100644
--- a/src/tools/run-make-support/src/rustdoc.rs
+++ b/src/tools/run-make-support/src/rustdoc.rs
@@ -34,8 +34,6 @@ pub fn bare() -> Self {
     #[track_caller]
     pub fn new() -> Self {
         let mut cmd = setup_common();
-        let target_rpath_dir = env_var_os("TARGET_RPATH_DIR");
-        cmd.arg(format!("-L{}", target_rpath_dir.to_string_lossy()));
         Self { cmd }
     }

EOF

echo "[TEST] rustc test suite"
COMPILETEST_FORCE_STAGE0=1 ./x.py test --stage 0 --test-args=--nocapture tests/{codegen-units,run-make,run-pass-valgrind,ui,incremental}
popd
