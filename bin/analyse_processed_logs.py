#!/usr/bin/env python
import sys
from os import access, R_OK
from os.path import isfile
import pandas as pd
import numpy as np

# verify at least one logfile has been provided as command-line arguments
if len(sys.argv) < 2:
  print("Syntax: %s <logfile>..." % sys.argv[0])
  sys.exit(1)

# verify logfiles exist and are readable
for filename in sys.argv[1:]:
  if not (isfile(filename) and access(filename, R_OK)):
    print("File '{}' doesn't exist or isn't readable".format(filename))
    sys.exit(1)

# load each logfile into a data frame
li = []

for filename in sys.argv[1:]:
  tmp = pd.read_csv(filename, sep='|') 
  li.append(tmp)

# concatenate data frames into one
df = pd.concat(li, axis=0, ignore_index=True)

# group by columns
grouped = df.groupby(['src_and_dest', 'transfer_options', 'folder', 'label'])

# aggregate and print
agg = grouped['transfer_rate'].agg([np.mean, np.std, np.min, np.max, np.size])
print(agg)
