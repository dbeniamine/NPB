#!/bin/bash
#echo "Creating plots directories"
#for d in $(\ls -d *.scn)
#do
#    mkdir -vp $d/plots
#done
echo "Removing old csv files"
rm *.csv
echo "Creating result csv file"
./csv_extractor.sh
echo "creating plots"
Rscript -e 'require(knitr); knit2html("analyse.rmd")'
