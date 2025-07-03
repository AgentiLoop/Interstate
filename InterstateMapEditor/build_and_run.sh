#!/bin/bash

echo "Building Interstate Map Editor..."
swift build -c release

if [ $? -eq 0 ]; then
    echo "Build successful!"
    echo "Running Interstate Map Editor..."
    ./.build/release/InterstateMapEditor
else
    echo "Build failed!"
    exit 1
fi 