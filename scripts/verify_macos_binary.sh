#!/usr/bin/env bash
#
# Asserts what a built macOS binary actually claims, rather than what the build scripts
# meant to claim.
#
# This exists because the two drifted apart unnoticed. `scripts/build_release.sh` passed
# `-target ...macos26.0` while the release runner was `macos-14`, and swiftc accepts a
# deployment target newer than its SDK without complaining. Every release from that period
# shipped `minos 26.0, sdk 14.5`: an app that refused to launch below macOS 26, yet was
# linked against the macOS 14 SDK so it never received Liquid Glass either. CI was green
# throughout, because nothing ever looked at the binary.
#
# Usage: verify_macos_binary.sh <binary> <expected-deployment-target> <expected-sdk-major> [--universal]

set -euo pipefail

BINARY="${1:?usage: verify_macos_binary.sh <binary> <deployment-target> <sdk-major> [--universal]}"
EXPECTED_TARGET="${2:?missing expected deployment target, e.g. 14.0}"
EXPECTED_SDK_MAJOR="${3:?missing expected SDK major, e.g. 26}"
REQUIRE_UNIVERSAL="${4:-}"

if [[ ! -f "$BINARY" ]]; then
    echo "::error::Binary not found: $BINARY"
    exit 1
fi

ARCHS="$(lipo -archs "$BINARY")"
echo "Binary : $BINARY"
echo "Archs  : $ARCHS"

if [[ "$REQUIRE_UNIVERSAL" == "--universal" ]]; then
    for required in arm64 x86_64; do
        if [[ " $ARCHS " != *" $required "* ]]; then
            echo "::error::Expected a universal binary containing $required, got: $ARCHS"
            exit 1
        fi
    done
fi

failed=0

for arch in $ARCHS; do
    # Read the slice's own load command. A universal binary can disagree with itself, and
    # only one slice being wrong is exactly the kind of thing a whole-file check misses.
    build_info="$(vtool -arch "$arch" -show-build "$BINARY" 2>/dev/null || true)"

    minos="$(awk '/minos/ {print $2; exit}' <<<"$build_info")"
    sdk="$(awk '/sdk/ {print $2; exit}' <<<"$build_info")"

    if [[ -z "$minos" || -z "$sdk" ]]; then
        echo "::error::$arch: could not read LC_BUILD_VERSION"
        failed=1
        continue
    fi

    printf '  %-8s minos %-8s sdk %s\n' "$arch" "$minos" "$sdk"

    if [[ "$minos" != "$EXPECTED_TARGET" ]]; then
        echo "::error::$arch: deployment target is $minos, expected $EXPECTED_TARGET."
        echo "::error::A minos above the supported floor makes the app refuse to launch on older macOS."
        failed=1
    fi

    if [[ "${sdk%%.*}" != "$EXPECTED_SDK_MAJOR" ]]; then
        echo "::error::$arch: built against SDK $sdk, expected ${EXPECTED_SDK_MAJOR}.x."
        echo "::error::Liquid Glass is granted by the SDK linked against, so an older SDK silently ships the old look."
        failed=1
    fi
done

if [[ "$failed" -ne 0 ]]; then
    exit 1
fi

echo "OK: deployment target $EXPECTED_TARGET, SDK ${EXPECTED_SDK_MAJOR}.x on every slice."
