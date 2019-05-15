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

uoa2uoa='e7f6aaae-fe52-11e8-9345-0e3d676669f4|e7f6aaae-fe52-11e8-9345-0e3d676669f4'
uoa2uoa_subst='UoA --> UoA'

guam2uoa='6756efae-93a8-11e8-96ac-0a6d4e044368|e7f6aaae-fe52-11e8-9345-0e3d676669f4'
guam2uoa_subst='Guam --> UoA'
uoa2guam='e7f6aaae-fe52-11e8-9345-0e3d676669f4|6756efae-93a8-11e8-96ac-0a6d4e044368'
uoa2guam_subst='UoA --> Guam'

echo "date|src_and_dest|folder|transfer_rate|transfer_options|label" 

for f in $@; do
  cat ${f} | grep RESULT | cut -d\| -f1,4,6,8,10,11,12 | \
     sed "s/${nesi2uoa}/${nesi2uoa_subst}/g" | \
     sed "s/${uoa2nesi}/${uoa2nesi_subst}/g" | \
     sed "s/${uoa2uoa}/${uoa2uoa_subst}/g" | \
     sed "s/${guam2uoa}/${guam2uoa_subst}/g" | \
     sed "s/${uoa2guam}/${uoa2guam_subst}/g" 
done

