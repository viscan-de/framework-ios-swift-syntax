#!/bin/bash

SWIFT_SYNTAX_VERSION=$1
SWIFT_SYNTAX_NAME="swift-syntax"
WRAPPER_NAME="SwiftSyntaxWrapper"
CONFIGURATION="Release"
DERIVED_DATA_PATH="$PWD/derivedData"

#
# Verify input
#

if [[ -z "$SWIFT_SYNTAX_VERSION" ]]; then
    echo "Swift syntax version (git tag) must be supplied as the first argument"
    exit 1
fi

if ! [[ $SWIFT_SYNTAX_VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "The given version ($SWIFT_SYNTAX_VERSION) does not have the right format (expected X.Y.Z)."
    exit 1
fi

echo ""
echo "Building swift-syntax $SWIFT_SYNTAX_VERSION → $WRAPPER_NAME.xcframework"
echo ""

set -euxo pipefail

#
# Clone and patch package
#

git clone --branch "$SWIFT_SYNTAX_VERSION" --single-branch "https://github.com/apple/$SWIFT_SYNTAX_NAME.git"

# Remove Swift 6 language version requirement present in 600.x.y
sed -i '' 's/, .version("6")//g' "$SWIFT_SYNTAX_NAME/Package.swift"

# Append the wrapper product and target. Package is a class so its properties
# are mutable after construction — the same pattern swift-syntax itself uses
# for the SwiftSyntax-all target. Works regardless of Package.swift structure.
cat >> "$SWIFT_SYNTAX_NAME/Package.swift" << EOF
package.products.append(.library(name: "$WRAPPER_NAME", type: .static, targets: ["$WRAPPER_NAME"]))
package.targets.append(.target(name: "$WRAPPER_NAME", dependencies: ["SwiftCompilerPlugin", "SwiftSyntax", "SwiftSyntaxBuilder", "SwiftSyntaxMacros", "SwiftSyntaxMacrosTestSupport"]))
EOF

# Add exported imports source file for the wrapper target
mkdir -p "$SWIFT_SYNTAX_NAME/Sources/$WRAPPER_NAME"
cat > "$SWIFT_SYNTAX_NAME/Sources/$WRAPPER_NAME/ExportedImports.swift" << EOF
public import SwiftCompilerPlugin
public import SwiftSyntax
public import SwiftSyntaxBuilder
public import SwiftSyntaxMacros
EOF

MODULES=(
    "SwiftBasicFormat"
    "SwiftCompilerPlugin"
    "SwiftCompilerPluginMessageHandling"
    "SwiftDiagnostics"
    "SwiftOperators"
    "SwiftParser"
    "SwiftParserDiagnostics"
    "SwiftSyntax"
    "SwiftSyntaxBuilder"
    "SwiftSyntaxMacroExpansion"
    "SwiftSyntaxMacros"
    "SwiftSyntaxMacrosTestSupport"
    "SwiftSyntaxMacrosGenericTestSupport"
    "SwiftIDEUtils"
    "_SwiftSyntaxGenericTestSupport"
    "$WRAPPER_NAME"
)

# Parallel arrays: xcodebuild destination name → XCFramework platform folder prefix
PLATFORMS_XCODE=("macos"  "iOS Simulator"  "iOS")
PLATFORMS_XCFW=( "macos_" "ios_simulator"  "ios_")

XCODEBUILD_LIBRARIES=""
PLATFORMS_OUTPUTS_PATH="$PWD/outputs"
LIBRARY_NAME="lib${WRAPPER_NAME}.a"

cd "$SWIFT_SYNTAX_NAME"

for ((i = 0; i < ${#PLATFORMS_XCODE[@]}; i++)); do
    XCODEBUILD_PLATFORM="${PLATFORMS_XCODE[$i]}"
    XCFW_PLATFORM="${PLATFORMS_XCFW[$i]}"
    OUTPUTS_PATH="$PLATFORMS_OUTPUTS_PATH/$XCFW_PLATFORM"

    mkdir -p "$OUTPUTS_PATH"

    # `swift build` cannot be used as it doesn't support building for iOS directly
    xcodebuild clean build \
        -scheme "$WRAPPER_NAME" \
        -configuration "$CONFIGURATION" \
        -destination "generic/platform=$XCODEBUILD_PLATFORM" \
        -derivedDataPath "$DERIVED_DATA_PATH" \
        SKIP_INSTALL=NO \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        | xcbeautify

    # Copy .swiftinterface files per architecture
    for MODULE in "${MODULES[@]}"; do
        for ARCH_DIR in "$DERIVED_DATA_PATH/Build/Intermediates.noindex/$SWIFT_SYNTAX_NAME.build/$CONFIGURATION"*/"$MODULE.build/Objects-normal/"/*/; do
            ARCH=$(basename "$ARCH_DIR")
            INTERFACE="$DERIVED_DATA_PATH/Build/Intermediates.noindex/$SWIFT_SYNTAX_NAME.build/$CONFIGURATION"*/"$MODULE.build/Objects-normal/$ARCH/$MODULE.swiftinterface"
            mkdir -p "$OUTPUTS_PATH/$ARCH"
            cp $INTERFACE "$OUTPUTS_PATH/$ARCH/"
        done
    done

    # Package object files into per-arch .a libraries, then lipo into a fat library.
    # Merge .swiftinterface files, stripping the arch-specific target triple so the
    # merged interface is usable from any architecture.
    LIPOFILES=""
    for ARCH_DIR in "$OUTPUTS_PATH"/*/; do
        ARCH=$(basename "$ARCH_DIR")
        ar -crs "$OUTPUTS_PATH/$ARCH/$LIBRARY_NAME" \
            "$DERIVED_DATA_PATH/Build/Intermediates.noindex/$SWIFT_SYNTAX_NAME.build/$CONFIGURATION"*/*.build/Objects-normal/"$ARCH"/*.o
        LIPOFILES="$LIPOFILES $OUTPUTS_PATH/$ARCH/$LIBRARY_NAME"

        for INPUTFILE in "$OUTPUTS_PATH/$ARCH/"*.swiftinterface; do
            BASENAME=$(basename "$INPUTFILE")
            OUTPUTFILE="$OUTPUTS_PATH/$BASENAME"
            if [[ -f "$OUTPUTFILE" ]]; then
                sed "s|// swift-module-flags: -target [^ ]* -|// swift-module-flags: -|" \
                    "$OUTPUTFILE" > "$OUTPUTS_PATH/tmp_$BASENAME"
                mv "$OUTPUTS_PATH/tmp_$BASENAME" "$OUTPUTFILE"
            else
                cp "$INPUTFILE" "$OUTPUTFILE"
            fi
        done
    done

    lipo $LIPOFILES -create -output "$OUTPUTS_PATH/$LIBRARY_NAME"
    XCODEBUILD_LIBRARIES="$XCODEBUILD_LIBRARIES -library $OUTPUTS_PATH/$LIBRARY_NAME"
done

cd ..

#
# Create XCFramework
#

XCFRAMEWORK_NAME="$WRAPPER_NAME.xcframework"

xcodebuild -quiet -create-xcframework \
    $XCODEBUILD_LIBRARIES \
    -output "$XCFRAMEWORK_NAME" >/dev/null

for ARCH_DIR in "$XCFRAMEWORK_NAME"/*/; do
    ARCH=$(basename "$ARCH_DIR")
    PLATFORM_PREFIX="$(echo "$ARCH" | cut -d'-' -f 1)_$(echo "$ARCH" | cut -d'-' -f 3)"
    cp "$PLATFORMS_OUTPUTS_PATH/$PLATFORM_PREFIX/"*.swiftinterface "$XCFRAMEWORK_NAME/$ARCH/"
done

zip --quiet --recurse-paths "$XCFRAMEWORK_NAME.zip" "$XCFRAMEWORK_NAME"

#
# Generate Package.swift pointing to the released binary
#

CHECKSUM=$(swift package compute-checksum "$XCFRAMEWORK_NAME.zip")
URL="$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/releases/download/$SWIFT_SYNTAX_VERSION/$XCFRAMEWORK_NAME.zip"

cat > Package.swift << EOF
// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "$WRAPPER_NAME",
    products: [
        .library(name: "$WRAPPER_NAME", targets: ["$WRAPPER_NAME"]),
    ],
    targets: [
        .binaryTarget(
            name: "$WRAPPER_NAME",
            url: "$URL",
            checksum: "$CHECKSUM"
        ),
    ]
)
EOF
