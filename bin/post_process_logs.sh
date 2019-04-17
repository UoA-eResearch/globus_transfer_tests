#!/bin/bash

# Extract information from log files and print in a more analysis-friendly way

if [ $# -lt "1" ]; then
    echo "Syntax: $0 <log file>..."
    exit 1
fi

nesi2uoa='3064bb28-e940-11e8-8caa-0a1d4c5c824a|e7f6aaae-fe52-11e8-9345-0e3d676669f4'
nesi2uoa_subst='NeSI --> UoA'
uoa2nesi='e7f6aaae-fe52-11e8-9345-0e3d676669f4|3064bb28-e940-11e8-8caa-0a1d4c5c824a'
uoa2nesi_subst='UoA --> NeSI'

echo "date|src_and_dest|folder|transfer_rate|transfer_options|label" 

for f in $@; do
  cat ${f} | grep RESULT | cut -d\| -f1,4,6,8,10,11,12 | \
     sed "s/${nesi2uoa}/${nesi2uoa_subst}/g" | \
     sed "s/${uoa2nesi}/${uoa2nesi_subst}/g" | \
     sed "s;MB/s;;g"
done

