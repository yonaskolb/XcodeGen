#!/bin/bash
set -e

swift run xcodegen --spec Tests/Fixtures/TestProject/project.yml
cd Tests/Fixtures/TestProject
./build.sh
