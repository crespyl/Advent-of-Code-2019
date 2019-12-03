DAYS="day*"
for DAY in $DAYS; do
    echo "bin/release/$DAY"
done | xargs redo-ifchange
