#!/bin/bash
set -e

if [[ `git status --porcelain Tests/Fixtures/TestProject` ]]; then
  echo ""
  echo "⚠️  Generated TestProject has changed."
  echo "⚠️  If this is a valid change please run the tests and commit the updated TestProject."
  echo ""
  git --no-pager diff --color=always Tests/Fixtures/TestProject
  exit 1
else
  echo "✅  Generated TestProject has not changed."
fi
