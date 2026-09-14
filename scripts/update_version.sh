#!/bin/bash

# Exit the script if any statement returns a non-true return value
set -e

# Project ${PRODUCT_NAME}-Info.plist
PROJECT_INFOPLIST_PATH="${PROJECT_DIR}/${INFOPLIST_FILE}"

# Read the version and the build number from git.
#
# Both are best-effort. This repository carries no tags at all, so
# `git describe` has nothing to describe, and `.git` is a directory in a clone
# but a file in a worktree, so its file type says nothing about whether git is
# usable here. Neither is a reason to fail the build: a value git cannot supply
# is left as it already stands in the Info.plist.
CURRENT_VERSION=""
CURRENT_BUILD_NUMBER=""

if git -C "${PROJECT_DIR}" rev-parse --git-dir > /dev/null 2>&1; then
	CURRENT_VERSION=`git -C "${PROJECT_DIR}" describe --abbrev=0 --tags 2>/dev/null || true`
	CURRENT_BUILD_NUMBER=`git -C "${PROJECT_DIR}" rev-list HEAD --count 2>/dev/null || true`
fi

# Version
if [ -n "${CURRENT_VERSION}" ]; then
	/usr/libexec/PlistBuddy -c "Set CFBundleShortVersionString $CURRENT_VERSION" "${PROJECT_INFOPLIST_PATH}"
fi

# Build Number
if [ -n "${CURRENT_BUILD_NUMBER}" ]; then
	/usr/libexec/PlistBuddy -c "Set CFBundleVersion $CURRENT_BUILD_NUMBER" "${PROJECT_INFOPLIST_PATH}"
fi
