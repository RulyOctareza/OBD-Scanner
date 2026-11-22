#!/usr/bin/env bash
# Builds an APK or AAB whose Dart code is provably the current source, and
# fails otherwise.
#
# The project path contains a space, which breaks the Flutter Gradle plugin's
# depfile parsing: after Dart-only edits Gradle can package the previous
# app.so. Each build here compiles in a unique SRC_REV (commit + time; lib/app.dart
# logs "AutoCare SRC_REV=<value>" at start), which forces the Dart compile, and
# every packaged libapp.so is checked for it.
#
# Usage: tool/build_verified.sh <apk|appbundle> [flutter build args...]
#   tool/build_verified.sh apk --release --split-per-abi
#   tool/build_verified.sh appbundle --release
# Last line of output: SRC_REV=<value>, to quote in QA evidence.
set -euo pipefail

kind=${1:?usage: tool/build_verified.sh <apk|appbundle> [flutter build args...]}
shift
# /usr/bin/git can stop on an Xcode license prompt on macOS.
git_bin=git
[[ -x /opt/homebrew/bin/git ]] && git_bin=/opt/homebrew/bin/git

commit=$("$git_bin" rev-parse --short HEAD)
dirty=$("$git_bin" status --porcelain --untracked-files=no -- lib pubspec.yaml pubspec.lock android | head -1)
src_rev="${commit}${dirty:+-dirty}-$(date +%Y%m%d%H%M%S)"

marker=$(mktemp)
trap 'rm -f "$marker"' EXIT
flutter build "$kind" "$@" --dart-define=SRC_REV="$src_rev"

outputs=$(find build/app/outputs -newer "$marker" \( -name '*.apk' -o -name '*.aab' \))
if [[ -z "$outputs" ]]; then
  echo "build_verified: no new APK/AAB found under build/app/outputs" >&2
  exit 1
fi
while IFS= read -r out; do
  libs=$(unzip -Z1 "$out" | grep '/libapp\.so$' || true)
  if [[ -z "$libs" ]]; then
    echo "build_verified: $out has no libapp.so" >&2
    exit 1
  fi
  while IFS= read -r lib; do
    # Not grep -q: an early exit would SIGPIPE strings and fail under pipefail.
    if ! unzip -p "$out" "$lib" | strings | grep -F "$src_rev" > /dev/null; then
      echo "build_verified: STALE Dart code in $out ($lib lacks SRC_REV $src_rev)" >&2
      exit 1
    fi
  done <<< "$libs"
  echo "build_verified: $out OK"
done <<< "$outputs"
echo "SRC_REV=$src_rev"
