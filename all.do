DAYS="day*"
for d in $DAYS; do
    redo-ifchange $d
done
