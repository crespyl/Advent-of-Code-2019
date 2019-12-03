DAY=$(basename -s .release $1)
if [ -e "$DAY/$DAY.cr" ]; then
  redo-ifchange "lib/intcode.cr"
  redo-ifchange "$DAY/$DAY.cr"
  crystal build "$DAY/$DAY.cr" -o "bin/release/$DAY" --release
else
    echo "$0: Couldn't find source file for $1" >&2
    exit 99
fi
