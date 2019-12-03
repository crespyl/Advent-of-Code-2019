# 1 is the artifact name we're trying to build, this will usually be
# bin/debug/dayN

# chop the bin/ and /dayNN bits to get either debug or release
MODE=${1#bin/}
MODE=${MODE%%/*}
SRC=${1#bin/$MODE/}

# find the source file (eg day2/day2.cr)
if [ -e $SRC/$SRC.cr ]; then
  redo-ifchange $SRC/$SRC.cr

  # quick hack to get the list of local deps from the file
  deps=$(egrep -o '^require "../lib/.+"' $SRC/$SRC.cr | sed -rn 's/require\s+"..\/(.+)"/\1/p')
  echo $deps | xargs redo-ifchange

  crystal build --$MODE -Dpreview_mt $SRC/$SRC.cr -o $3
else
    echo "$0: Couldn't find source file for $SRC" >&2
    exit 99
fi
