#!/bin/sh
# Build a production release and copy it to the root directory
swift build -c release
mv .build/release/seev .