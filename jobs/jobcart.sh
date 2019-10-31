#!/bin/bash
#SBATCH -c 10                              # Request ten cores, might be overkill
#SBATCH -N 1                               # Request one node (if you request more than one core with -c, also using
                                           # -N 1 means all cores will be on the same node)
#SBATCH -t 0-12:00                         # Runtime in D-HH:MM format
#SBATCH -p short                           # Partition to run in
#SBATCH --mem=10000                          # Memory total in MB (for all cores)



cd ..
bash runcart.sh raw_000

cartresolution=352
DCM_CTR=1
IMG=img_cartesian
ID=1

matlab -nodesktop -r "saveyourbartasCARTESIANdicom('$cartresolution', '$DCM_CTR', '$IMG', '$ID')"
