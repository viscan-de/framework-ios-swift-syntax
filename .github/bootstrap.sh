#!/bin/bash

SWIFT_SYNTAX_VERSION=$1
SWIFT_SYNTAX_NAME="swift-syntax"
SWIFT_SYNTAX_REPOSITORY_URL="https://github.com/apple/$SWIFT_SYNTAX_NAME.git"
SEMVER_PATTERN="^[0-9]+\.[0-9]+\.[0-9]+$"
WRAPPER_NAME="SwiftSyntaxWrapper"
CONFIGURATION="Release"
DERIVED_DATA_PATH="$PWD/derivedData"

#
# Verify input
#

if [ -z "$SWIFT_SYNTAX_VERSION" ]; then
    echo "Swift syntax version (git tag) must be supplied as the first argument"
    exit 1
fi

if ! [[ $SWIFT_SYNTAX_VERSION =~ $SEMVER_PATTERN ]]; then
    echo "The given version ($SWIFT_SYNTAX_VERSION) does not have the right format (expected X.Y.Z)."
    exit 1
fi

#
# Print input
#

cat << EOF

Input:
swift-syntax version to build:  $SWIFT_SYNTAX_VERSION

EOF

set -eux

#
# Clone package
#

git clone --branch $SWIFT_SYNTAX_VERSION --single-branch $SWIFT_SYNTAX_REPOSITORY_URL

#
# Add static wrapper product
#

sed -i '' -E "s/(products: \[)$/\1\n    .library(name: \"${WRAPPER_NAME}\", type: .static, targets: [\"${WRAPPER_NAME}\"]),/g" "$SWIFT_SYNTAX_NAME/Package.swift"

#
# Add target for wrapper product
#

sed -i '' -E "s/(targets: \[)$/\1\n    .target(name: \"${WRAPPER_NAME}\", dependencies: [\"SwiftCompilerPlugin\", \"SwiftSyntax\", \"SwiftSyntaxBuilder\", \"SwiftSyntaxMacros\", \"SwiftSyntaxMacrosTestSupport\"]),/g" "$SWIFT_SYNTAX_NAME/Package.swift"

# for swift 600.x.y
sed -i '' 's/, .version("6")//g' "$SWIFT_SYNTAX_NAME/Package.swift"

#
# Add exported imports to wrapper target
#

WRAPPER_TARGET_SOURCES_PATH="$SWIFT_SYNTAX_NAME/Sources/$WRAPPER_NAME"

mkdir -p $WRAPPER_TARGET_SOURCES_PATH

tee $WRAPPER_TARGET_SOURCES_PATH/ExportedImports.swift <<EOF
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

PLATFORMS=(
    # xcodebuild destination    XCFramework folder name
    "macos"                     "macos_"
    "iOS Simulator"             "ios_simulator"
    "iOS"                       "ios_"
)

XCODEBUILD_LIBRARIES=""
PLATFORMS_OUTPUTS_PATH="$PWD/outputs"

cd $SWIFT_SYNTAX_NAME

for ((i = 0; i < ${#PLATFORMS[@]}; i += 2)); do
    XCODEBUILD_PLATFORM_NAME="${PLATFORMS[i]}"
    XCFRAMEWORK_PLATFORM_NAME="${PLATFORMS[i+1]}"

    OUTPUTS_PATH="${PLATFORMS_OUTPUTS_PATH}/${XCFRAMEWORK_PLATFORM_NAME}"
    LIBRARY_NAME="lib${WRAPPER_NAME}.a"

    mkdir -p "$OUTPUTS_PATH"

    # `swift build` cannot be used as it doesn't support building for iOS directly
    xcodebuild clean build \
        -scheme $WRAPPER_NAME \
        -configuration $CONFIGURATION \
        -destination "generic/platform=$XCODEBUILD_PLATFORM_NAME" \
        -derivedDataPath $DERIVED_DATA_PATH \
        SKIP_INSTALL=NO \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        | xcbeautify

    for MODULE in ${MODULES[@]}; do
        for ARCH in $DERIVED_DATA_PATH/Build/Intermediates.noindex/swift-syntax.build/$CONFIGURATION*/${MODULE}.build/Objects-normal/*/ ; do
            ARCH=$(basename $ARCH)
            INTERFACE_PATH="$DERIVED_DATA_PATH/Build/Intermediates.noindex/swift-syntax.build/$CONFIGURATION*/${MODULE}.build/Objects-normal/$ARCH/${MODULE}.swiftinterface"
            mkdir -p "$OUTPUTS_PATH/$ARCH"
            cp $INTERFACE_PATH "$OUTPUTS_PATH/$ARCH"
        done 
    done

    LIPOFILES=""
    for ARCH in $OUTPUTS_PATH/*/ ; do
        ARCH=$(basename $ARCH)
        # FIXME: figure out how to make xcodebuild output the .a file directly. For now, we package it ourselves.
        ar -crs "$OUTPUTS_PATH/$ARCH/$LIBRARY_NAME" $DERIVED_DATA_PATH/Build/Intermediates.noindex/swift-syntax.build/$CONFIGURATION*/*.build/Objects-normal/$ARCH/*.o
        LIPOFILES="$LIPOFILES $OUTPUTS_PATH/$ARCH/$LIBRARY_NAME"

        for INTERFFILE in $OUTPUTS_PATH/$ARCH/*.swiftinterface; do 
            INTERFFILE=$(basename $INTERFFILE)
            INPUTFILE=$OUTPUTS_PATH/$ARCH/$INTERFFILE
            OUTPUTFILE=$OUTPUTS_PATH/$INTERFFILE
            OUTPUTTMPFILE=$OUTPUTS_PATH/tmp_$INTERFFILE
            if test -f "$OUTPUTFILE"; then
                ARCH1=$(grep -o '\/\/ swift-module-flags: -target [^ ]*' $OUTPUTFILE)
                ARCH1=${ARCH1##* }
                ARCH2=$(grep -o '\/\/ swift-module-flags: -target [^ ]*' $INPUTFILE)
                ARCH2=${ARCH2##* }
                #sed "s/\/\/ swift-module-flags\: -target [^ ]* -/\/\/ swift-module-flags\: -target ${ARCH1} ${ARCH2} -/" "$OUTPUTFILE" > "$OUTPUTTMPFILE"
                sed "s/\/\/ swift-module-flags\: -target [^ ]* -/\/\/ swift-module-flags\: -/" "$OUTPUTFILE" > "$OUTPUTTMPFILE"
                mv "$OUTPUTTMPFILE" "$OUTPUTFILE"
            else
                cp "$INPUTFILE" "$OUTPUTFILE"
            fi
        done
    done 
    lipo $LIPOFILES -create -output $OUTPUTS_PATH/$LIBRARY_NAME
    XCODEBUILD_LIBRARIES="$XCODEBUILD_LIBRARIES -library $OUTPUTS_PATH/$LIBRARY_NAME"
done

cd ..

#
# Create XCFramework
#

XCFRAMEWORK_NAME="$WRAPPER_NAME.xcframework"
XCFRAMEWORK_PATH="$XCFRAMEWORK_NAME"

xcodebuild -quiet -create-xcframework \
    $XCODEBUILD_LIBRARIES \
    -output "${XCFRAMEWORK_PATH}" >/dev/null

for ARCH in $XCFRAMEWORK_PATH/*/ ; do
    ARCH=$(basename $ARCH)
    DEST="$XCFRAMEWORK_PATH/$ARCH"
    SOURCE="${PLATFORMS_OUTPUTS_PATH}/$(echo $ARCH | cut -d'-' -f 1)_$(echo $ARCH | cut -d'-' -f 3)/*.swiftinterface"
    cp  $SOURCE $DEST/
done

zip --quiet --recurse-paths $XCFRAMEWORK_NAME.zip $XCFRAMEWORK_NAME

#
# Create package manifest
#

CHECKSUM=$(swift package compute-checksum $XCFRAMEWORK_NAME.zip)
URL="$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/releases/download/$SWIFT_SYNTAX_VERSION/$XCFRAMEWORK_NAME.zip"

tee Package.swift <<EOF
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
