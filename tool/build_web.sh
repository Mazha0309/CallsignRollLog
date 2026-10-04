#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

rust_toolchain="${OPENLOGTOOL_WEB_RUST_TOOLCHAIN:-nightly-2026-07-26}"

for command_name in flutter flutter_rust_bridge_codegen rustup wasm-pack; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Missing required command: $command_name" >&2
    exit 1
  fi
done

if ! rustup run "$rust_toolchain" rustc --version >/dev/null 2>&1; then
  echo "Rust toolchain $rust_toolchain is not installed." >&2
  echo "Run: rustup toolchain install $rust_toolchain --profile minimal --component rust-src --target wasm32-unknown-unknown" >&2
  exit 1
fi

if ! rustup component list --toolchain "$rust_toolchain" --installed |
  grep -q '^rust-src'; then
  echo "rust-src is missing for $rust_toolchain." >&2
  echo "Run: rustup component add rust-src --toolchain $rust_toolchain" >&2
  exit 1
fi

if ! rustup target list --toolchain "$rust_toolchain" --installed |
  grep -qx 'wasm32-unknown-unknown'; then
  echo "wasm32-unknown-unknown is missing for $rust_toolchain." >&2
  echo "Run: rustup target add wasm32-unknown-unknown --toolchain $rust_toolchain" >&2
  exit 1
fi

# flutter_rust_bridge moves asynchronous Rust calls to Web Workers. Its
# workers instantiate the same module with shared memory, so Rust, SQLite's C
# object and wasm-bindgen must all be built with matching thread features.
# sqlite-wasm-rs uses C23's standard attribute syntax (for example
# `[[noreturn]]`). Debian Bookworm still ships Clang 14, whose default C mode
# rejects that syntax. Keep the GNU C23 dialect explicit: the GNU feature
# macros are also required by sqlite-wasm-rs' bundled musl headers. The
# non-Emscripten WASM backend only supports local-exec TLS, which is exactly
# what these per-worker SQLite shims need.
export CFLAGS_wasm32_unknown_unknown="${CFLAGS_wasm32_unknown_unknown:-} -std=gnu2x -ftls-model=local-exec -matomics -mbulk-memory"
wasm_rustflags='-C target-feature=+atomics,+bulk-memory,+mutable-globals'
wasm_rustflags+=' -C link-arg=--shared-memory'
wasm_rustflags+=' -C link-arg=--max-memory=1073741824'
wasm_rustflags+=' -C link-arg=--import-memory'
wasm_rustflags+=' -C link-arg=--export=__heap_base'
wasm_rustflags+=' -C link-arg=--export=__wasm_init_tls'
wasm_rustflags+=' -C link-arg=--export=__tls_size'
wasm_rustflags+=' -C link-arg=--export=__tls_align'
wasm_rustflags+=' -C link-arg=--export=__tls_base'

flutter_rust_bridge_codegen build-web \
  --release \
  --rust-root rust \
  --output ../web \
  --wasm-pack-rustup-toolchain "$rust_toolchain" \
  "--wasm-pack-rustflags=$wasm_rustflags"

test -s web/pkg/openlogtool_core.js
test -s web/pkg/openlogtool_core_bg.wasm
grep -Fq 'shared:true' web/pkg/openlogtool_core.js

# Flutter copies Web assets incrementally and does not remove files that were
# deleted from web/. Recreate only the generated Web output so a retired
# runtime (such as the old Dart SQLite worker) cannot leak into a release.
rm -rf build/web
flutter build web --release --no-wasm-dry-run "$@"

test -s build/web/index.html
test -s build/web/update.html
test -s build/web/update.js
cmp web/update.html build/web/update.html
cmp web/update.js build/web/update.js
test -s build/web/pkg/openlogtool_core.js
test -s build/web/pkg/openlogtool_core_bg.wasm

echo "WebClient built at $repo_root/build/web"
