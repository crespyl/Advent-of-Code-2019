DAYS="day*"
for DAY in $DAYS; do
    echo "bin/release/$DAY"
done | xargs redo-ifchange

# also redo tools
TOOLS="disasm"
for TOOL in $TOOLS; do
    echo "bin/release/$TOOL"
done | xargs redo-ifchange
