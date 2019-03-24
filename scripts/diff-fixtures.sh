#!/bin/bash
set -e

if [[ `git status --porcelain Tests/Fixtures` ]]; then
  echo ""
  echo "⚠️  Generated fixturess have changed."
  echo "⚠️  If this is a valid change please run the tests and commit the updates."
  echo ""
  git --no-pager diff --color=always Tests/Fixtures
  exit 1
else
  echo "✅  Generated fixtures have not changed."
fi
