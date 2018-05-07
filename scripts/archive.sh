#!/bin/bash
PACKAGE_NAME=${EXECUTABLE_NAME:?}
TMP=$(mktemp -d)/$PACKAGE_NAME
BINDIR=$TMP/bin
SHAREDIR=$TMP/share/$PACKAGE_NAME
ZIPFILE=$TMP/${EXECUTABLE_NAME:?}.zip
INSTALLSH=scripts/install.sh
LICENSE=LICENSE

# copy

mkdir -p $BINDIR
cp -f .build/release/$EXECUTABLE_NAME $BINDIR

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
