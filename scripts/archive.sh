#!/bin/bash
PACKAGE_NAME=${TOOL_NAME_LOWER:?}
TMP=$(mktemp -d)/$PACKAGE_NAME
BINDIR=$TMP/bin
SHAREDIR=$TMP/share
ZIPFILE=$TMP/${TOOL_NAME_LOWER:?}.zip
INSTALLSH=scripts/install.sh
LICENSE=LICENSE

# copy

mkdir -p $BINDIR
cp -f .build/release/$TOOL_NAME_LOWER $BINDIR

mkdir -p $SHAREDIR
cp -R SettingPresets $SHAREDIR/SettingPresets

cp $INSTALLSH $TMP

cp $LICENSE $TMP

# zip

(cd $TMP/..; zip -r $ZIPFILE $PACKAGE_NAME)

# print sha

SHA=$(cat $ZIPFILE | shasum -a 256 | sed 's/ .*//')
echo "SHA: $SHA"
mv $ZIPFILE .

# cleanup

rm -rf $TMP
