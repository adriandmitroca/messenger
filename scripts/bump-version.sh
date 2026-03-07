#!/usr/bin/env bash
set -euo pipefail

VERSION="$1"

sed -i '' "s/MARKETING_VERSION: .*/MARKETING_VERSION: \"$VERSION\"/" project.yml

OLD_BUILD=$(grep 'CURRENT_PROJECT_VERSION' project.yml | head -1 | sed 's/.*: *"\(.*\)"/\1/')
NEW_BUILD=$((OLD_BUILD + 1))
sed -i '' "s/CURRENT_PROJECT_VERSION: .*/CURRENT_PROJECT_VERSION: \"$NEW_BUILD\"/" project.yml

echo "Bumped to v$VERSION (build $NEW_BUILD)"
