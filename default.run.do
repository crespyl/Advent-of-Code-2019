DAY=$(basename -s .run $1)

if [ -e "$DAY/$DAY.cr" ]; then
  redo-ifchange "lib/intcode.cr"
  redo-ifchange "$DAY/$DAY.cr"
  crystal build "$DAY/$DAY.cr" -o "bin/debug/$DAY"
  bin/debug/$DAY $DAY/input.txt >&2
else
    echo "$0: $DAY is missing either source or input.txt" >&2
    exit 99
fi
