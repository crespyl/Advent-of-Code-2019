DAYS="day*"
for DAY in $DAYS; do
    echo "bin/debug/$DAY"
done | xargs redo-ifchange
