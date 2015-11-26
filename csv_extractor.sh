#!/bin/bash
echo "Affinity, Balancing, Interleave, Run, Opti,Time" > results.csv
grep "Time in seconds" -Rn ./*/ | sed -e \
    's/.\/\(.*\)\/\(.*\)\/\(.*\)\/run-\(.*\)\/\(.*\).log:[^=]*=\s*\([0-9\.]*\)$/\1,\2,\3,\4,\5,\6/'\
    >> results.csv
