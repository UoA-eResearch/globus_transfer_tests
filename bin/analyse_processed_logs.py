#!/usr/bin/env python
import sys
from os import access, R_OK
from os.path import isfile
import pandas as pd
import numpy as np

# verify at least one logfile has been provided as argument on command-line
if len(sys.argv) < 2:
  print("Syntax: %s <logfile>..." % sys.argv[0])
  sys.exit(1)

# verify logfiles exist and are readable
for filename in sys.argv[1:]:
  if not (isfile(filename) and access(filename, R_OK)):
    print("File '{}' doesn't exist or isn't readable".format(filename))
    sys.exit(1)

# load each logfile into a data frame and concatenate into one data frame
dfs = [ pd.read_csv(filename, sep='|') for filename in sys.argv[1:] ]
df = pd.concat(dfs, axis=0, ignore_index=True)

# change unit from Bytes/s to MegaBits/s
df['transfer_rate'] = df['transfer_rate'].apply(lambda x: round((x*8)/1000/1000))

# group by columns, run aggregate functions, and print result
grouped = df.groupby(['src_and_dest', 'transfer_options', 'folder', 'label'])
agg = grouped['transfer_rate'].agg([np.mean, np.std, np.min, np.max, np.size])
print(agg)
