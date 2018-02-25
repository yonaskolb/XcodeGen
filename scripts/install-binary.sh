#!/bin/bash
PREFIX=${1:-/usr/local}

### NOTE: Stripped or replaced by archive.sh from this line
ZIPFILE=xcodegen.zip
if [ ! -f $ZIPFILE ];then echo $ZIPFILE not found; exit 1; fi
unzip -o xcodegen.zip
BASE_DIR=XcodeGen
### to this line.

cp -r $BASE_DIR/share "${PREFIX}"
cp -r $BASE_DIR/bin "${PREFIX}"
