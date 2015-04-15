#!/bin/bash
echo "Runtime, Run, Opti,Time" > results.csv
grep "Time in seconds" -Rn ./*/ | sed -e \
    's/\.\/\([^\/]*\)\/run-\([0-9]*\)\/\(.*\).log:[^=]*=\s*\([0-9\.]*\)$/\1,\2,\3,\4/'\
    >> results.csv
