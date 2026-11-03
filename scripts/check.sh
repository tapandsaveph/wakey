#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build
xcrun swiftc -parse-as-library -swift-version 6 Sources/Power.swift Tests/PowerChecks.swift -o .build/PowerChecks
.build/PowerChecks
./scripts/build.sh --check
