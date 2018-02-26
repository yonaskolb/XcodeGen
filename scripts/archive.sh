#!/bin/bash
TMP=$(mktemp -d)/${TOOL_NAME:?}
BINDIR=$TMP/bin
SHAREDIR=$TMP/share
ZIPFILE=$TMP/${TOOL_NAME_LOWER:?}.zip
INSTALLSH=scripts/install.sh

# copy

mkdir -p $BINDIR
cp -f .build/release/$TOOL_NAME_LOWER $BINDIR

mkdir -p $SHAREDIR
cp -R SettingPresets $SHAREDIR/SettingPresets

cp $INSTALLSH $TMP

# zip

(cd $TMP/..; zip -r $ZIPFILE $TOOL_NAME)

# print sha

SHA=$(cat $ZIPFILE | shasum -a 256 | sed 's/ .*//')
echo "SHA: $SHA"
mv $ZIPFILE .

# cleanup

rm -rf $TMP
