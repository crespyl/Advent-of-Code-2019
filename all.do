DAYS="day*"
for DAY in $DAYS; do
    echo "bin/debug/$DAY"
done | xargs redo-ifchange

# also redo tools
TOOLS="disasm debugger"
for TOOL in $TOOLS; do
    echo "bin/debug/$TOOL"
done | xargs redo-ifchange
