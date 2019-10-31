#!/bin/bash
#SBATCH -c 10
#SBATCH --mem=2G
#SBATCH -t 00:30:00
#SBATCH -p gpu
#SBATCH --gres=gpu:teslaV100:1                   # require 2 gpus in the near future !

# Measure Runtime in seconds
START=$(date +%s)

dir=$(pwd)

## 2. Load the following modules
module load gcc/6.2.0
module load openmpi/2.0.1
module load lapacke/3.6.1
module load libpng/1.6.26
module load openblas/0.2.19
module load fftw/3.3.7
module load python/3.6.0 # not mandatory
module load cuda/10.0 # GPU only

export CFLAGS="-I/n/app/fftw/3.3.7/include -I/n/app/lapacke/3.6.1/include -I/n/app/openblas/0.2.19/include -I/n/app/libpng/1.6.26/include -I/n/app/gcc/6.2.0/include -I/n/app/cuda/10.0/include"
export LDFLAGS="-L/n/app/fftw/3.3.7/lib -L/n/app/lapacke/3.6.1/lib -L/n/app/openblas/0.2.19/lib -L/n/app/libpng/1.6.26/include -L/n/app/gcc/6.2.0 -L/n/app/cuda/10.0/include"

# GPU only
export CUDA=1
export CUDA_BASE=/n/app/cuda/10.0
export USE_CUDA=1

export PARALLEL=1
export DEBUG=1

echo 'actual folder :' $(pwd)
source ~/.bashrc
echo 'actual folder :' $(pwd)
cd $dir
cd ..
echo $dir

# # SETUP THE 3 PARAMETERS of radial recon and the 3 params of the DICOM output:
	rawfile=raw_001
	TFE=12
	TURNS=5
	# options for hyperparam optim
	Wavelet=0.00001
	TV=0.001

	cartresolution=352
	DCM_CTR=1
	IMG=img_radial
	ID=1
# #

#source runradial.sh raw_001 TFEfactor TURNS
source runradial.sh $rawfile $TFE $TURNS $Wavelet $TV

# Measure Runtime
END=$(date +%s)
runtime=$(($END-$START))
echo the runtime is $runtime seconds. > runtime.txt

# bart array to DICOM image. This step needs a setup for "saveyourmatlabasdicom.m"
matlab -nodesktop -r "saveyourbartasRADIALdicom('$cartresolution', '$DCM_CTR', '$IMG', $ID)"
