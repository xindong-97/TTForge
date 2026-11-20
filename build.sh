#!/bin/sh
set -e
SDK="$1"
if [ -z "$SDK" ]; then SDK="$(xcrun --sdk iphoneos --show-sdk-path)"; fi
clang -arch arm64 -miphoneos-version-min=14.0 -isysroot "$SDK" \
  -dynamiclib -fno-objc-arc -framework UIKit -framework Foundation \
  -undefined dynamic_lookup -o TTForge.dylib TTForge.m
file TTForge.dylib 2>/dev/null || true
