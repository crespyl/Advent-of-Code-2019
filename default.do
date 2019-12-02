if [ -e "$1/$1.cr" ]; then
  redo-ifchange "lib/intcode.cr"
  redo-ifchange "$1/$1.cr"
  crystal build "$1/$1.cr" -o "bin/debug/$1"
else
    echo "$0: Couldn't find source file for $1" >&2
    exit 99
fi
