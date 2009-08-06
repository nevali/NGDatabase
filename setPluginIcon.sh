#! /bin/sh

icon="$SCRIPT_INPUT_FILE_0"
target="$SCRIPT_OUTPUT_FILE_0"

REZ=/Developer/usr/bin/Rez
SETFILE=/Developer/usr/bin/SetFile

cp "$icon" ${CONFIGURATION_TEMP_DIR}/icon-resource.icns || exit $?
echo "read 'icns' (-16455) \"icon-resource.icns\";" > ${CONFIGURATION_TEMP_DIR}/icon-resource.r
ifile="`printf \"$target/Icon\r\"`"
$REZ -o "$ifile" ${CONFIGURATION_TEMP_DIR}/icon-resource.r || exit $?
rm -f ${CONFIGURATION_TEMP_DIR}/icon-resource.icns
rm -f ${CONFIGURATION_TEMP_DIR}/icon-resource.r
$SETFILE -a C "$target"
$SETFILE -a V "$ifile"

