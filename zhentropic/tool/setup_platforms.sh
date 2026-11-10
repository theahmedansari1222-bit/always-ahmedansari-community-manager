#!/usr/bin/env bash
# Creates android/ and ios/ if they are missing (the repo only ships Dart code),
# keeps our own files untouched, then applies Zhentropic's permissions,
# Supabase deep link and app name. Safe to run more than once.
set -euo pipefail
cd "$(dirname "$0")/.."

KEEP="lib pubspec.yaml analysis_options.yaml .gitignore README.md"

if [ ! -d android ] || [ ! -d ios ]; then
  tmp="$(mktemp -d)"
  for f in $KEEP; do
    if [ -e "$f" ]; then cp -r "$f" "$tmp/"; fi
  done
  flutter create --platforms=android,ios --org com.zhentropic --project-name zhentropic .
  for f in $KEEP; do
    if [ -e "$tmp/$f" ]; then rm -rf "$f"; cp -r "$tmp/$f" "$f"; fi
  done
  rm -f test/widget_test.dart # the generated sample test refers to a MyApp we do not have
fi

python3 tool/patch_platforms.py
