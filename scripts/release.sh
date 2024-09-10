#!/usr/bin/env bash

VERSION=$(cat build.zig.zon | grep '.version' | sed 's/.*= "\(.*\)",/\1/')

git tag v${VERSION} -a -m "release ${VERSION}"
git push origin --tags
