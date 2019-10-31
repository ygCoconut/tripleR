#!/usr/bin/env bash

# To run this file, check if:
# TFE is set right
# TURNS is set right (should be 20)
# filename raw is set right (e.g. raw001 or raw010 )
# The pics ( parallel imaging compressed sensing ) hyperparams are set to good values


# Get your BART
cd ~/ProgramsAndSoftware/bart_HMS; source startup.sh; cd -

#--- Raw data ---
# bart paradiseread -c raw_001 _k idx
bart paradiseread -c $1 _k idx # Dimensions [RO, 1, 1, COILS, 1, 1, 1, 1, 1, 1, TIME, 1, 1, SLICES, 1, 1]

# --- Variables ---
TFE=$2
TURNS=$3
Wavelet=$4
TotalVariation=$5
CPHASES=20 # Number of Cardiac Phases

SLICES=$(bart show -d13 _k)
RO=$(bart show -d0 _k) #Readouts
DIMS=$((2 * $RO)) # = RO * scaling factor (2 in our case)
FR=$(bart show -d10 _k)
N_COILS=$(bart show -d3 _k)
echo TFE factor $TFE
echo Turns $TURNS
echo Wavelet $Wavelet
echo Total Variation $TotalVariation
echo Number of slices $SLICES
echo Readouts $RO
echo Dimensions $DIMS
echo FR $FR
echo Number of coils $N_COILS

# RO to dimension 1
bart transpose 0 1 _k k # Dimensions [1, RO, ...]


# Get angles
#python3 ~/Programs/Python/Other/paradise_angle.py -a --tfe $TFE --turns $TURNS idx angle_full
#python3 ~/Programs/Python/Other/paradise_angle.py -g $CPHASES idx gate_full
python3 /src/paradise_angle.py -a --tfe $TFE --turns $TURNS idx angle_full
python3 /src/paradise_angle.py -g $CPHASES idx gate_full


# here we ll add:
#bart fftmod $(bart bitmask 10) k k1 #k becomes k1 in the following code
#echo fftmoddone

#--- Slice by slice reco ---
echo slice by slice reco
for ((slice=0; slice<$SLICES; slice++)); do

  #slice=5 # demo

  # Get one slice
  bart slice 13 $slice k _ks1
  bart slice 1 $slice angle_full angle
  bart slice 1 $slice gate_full _gate

  # Trajectory
  bart traj -x$RO -y$FR -C angle -r -c _t
  bart transpose 2 10 _t _t1

  # B0 correction
  python3 /src/b0cor.py _ks1 _t1 _kcor

  # Coil compression
  n_coils=13
  bart cc -p$n_coils -A _kcor _ks

  # ---- NOT NEEDED WHEN B0 CORRECTION IS PERFORMED ---
  # #-- Gradient Delay ---
  # bart resize 10 50 _ks __gdk
  # bart resize 10 50 _t1 __gdt
  # bart transpose 2 10 __gdk __gdk1
  # bart transpose 2 10 __gdt __gdt1
  # GD=$(bart estdelay -R -r3 __gdt1 __gdk1)
  # echo $GD
  #
  # bart traj -x$RO -y$FR -C angle -r -c -q $GD -O _gdt
  # bart transpose 2 10 _gdt _gdt1

  #-- Get coil sensitivities using nlinv (or ESPIRiT?!) --

# Improvement option : instead of taking 200 spokes, take the highest amount of spokes to improve cs maps.
  bart resize 10 200 _ks __k
  # bart resize 10 200 _gdt1 __t  #only if  GDcor
  bart resize 10 200 _t1 __t
  bart transpose 2 10 __k __k1
  bart transpose 2 10 __t __t1
  echo resizingdone

  # Increase FOV
  bart scale 2 __t1{,x}
  bart nufft -a -d$DIMS:$DIMS:1 __t1x __k1 _nufft
  bart fft -u $(bart bitmask 0 1) _nufft _k_grid

  echo increasFOVdone

  # Grid pattern
  bart pattern __k1 pat
  bart ones 16 $(echo 1; for ((i=1; i<16; i++)); do echo $(bart show -d$i __t1x); done) _ones
  bart fmac _ones pat _ones1
  bart nufft -a -d$DIMS:$DIMS:1 __t1x _ones1 _pat
  bart fft -u $(bart bitmask 0 1) _pat _psf1
  bart scale 0.005 _psf1 _psf #This scaling factor is important for bug fixing !

  echo griddingdone

  # NLINV
  bart nlinv -d5 -i11 -g -p _psf _k_grid _rec _sens # -g to run on gpu
  bart resize -c 0 $RO 1 $RO _sens sens

  # Binning
  bart transpose 0 10 _gate _gate1
  bart bin -l2 _gate1 _ks kbin # Put spokes that belong to a specific label to dimension 2
  #bart scale 2 _gdt1 _t2 # This line will resolve a bug about the resolution
  #bart bin -l2 _gate1 _gdt1 tbin # Put spokes that belong to a specific label to dimension 2
  bart bin -l2 _gate1 _t1 tbin # Put spokes that belong to a specific label to dimension 2


  #-- CS --
  bart pattern kbin patk
  count=0
  #for W in 0.0001 0.001 0.01 0.1 1; do
  #for T in 0.0001 0.001 0.01 0.1 1; do
  # for W in 0.0005 ; do
  #   for T in 0.005; do
  for W in $Wavelet ; do
      for T in $TotalVariation; do
      echo $count "/ 25"
      W2=$W #save values for later
      T2=$T #save values for later
      bart pics -d5 -p patk -t tbin -g -S -i150 -R W:$(bart bitmask 0 1):0:$W -R T:$(bart bitmask 10):0:$T kbin sens pics_W${W}_T${T}_slice${slice} # -g to run on gpu
      count=$(($count + 1))
    done
  done
# end of first for loop:
done

# join together all the slices
#bart join 13 "pics_W0.0005_T0.005_slice"$(seq -s " pics_W0.005_T0.05_slice" 0 $(($SLICES-1))) pics_W0.0005_T0.005
bart join 13 pics_W"$W2"_T"$T2"_slice$(seq -s " pics_W"$W2"_T""$T2""_slice" 0 $(($SLICES-1))) img_radial
#echo "pics_W0.001_T0.01_slice"$(seq -s " pics_W""$W2""_T""$T2""_slice" 0 $(($SLICES-1))) "pics_W""$W2"_T"$T2"
echo img_radial recon with success
