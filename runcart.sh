
#This script allows you to recon the cartesian data, named raw_000


# Get your BART
cd ~/ProgramsAndSoftware/bart_HMS; source startup.sh; cd -

#--- Raw data ---
# bart paradiseread -c raw_000 _k idx
bart paradiseread -c $1 _k idx
# Dimensions of index:
# [1 1 1 1 1 1 1 1 1 1 3421 20 1 12 1 1]
# idx.cfl contains the pointers to the readouts/datapoints of the coils of the kspace ordered in slices (slices: dimension 13 = 12).
#	--> each of the 3421 pointers (of every Slice) points to Sample #1/312 of Coil#1/23
# These datapoints are in the same format as the raw.list file (the first column of the list file has been taken out).
# The dimensions 10 ( = 3421 ) and 11 (= 20) span the space of the list file.
# The list file has 20 columns (the 1st col is discarded) and 3421 entries/observations.
# Analoguous to the raw.list, each observation of idx is pointing to a memory address. The memory address contains all the samples (e.g. 320) of all 23 coils of a single readout.
# 	--> You can verify this with the following calculus:
#	(#datapoints per readout) * (length of a complex float) * (# coils)  == (address of the following pointer)
# Additionally, the raw.list file has 23 times more valid entries than the idx.cfl file, as the different coils are reffered to with the same idx.cfl pointer
#	--> There should be 23*3421 (valid) rows in raw.list.

# Dimensions of _k:
# [312 1 1 23 1 1 1 1 1 1 3421 1 1 12 1 1]
# _k.cfl contains the k-space readout-data of the patient, saved as complex floats.
# In the raw.raw file, the kspace readouts are written in a single dimension, in the order prescribed by the raw.list file.
# Opposingly, the data in _k.cfl is spanned across 5 dimensions.
#
#	- The dimension 0 contains the 312 Samples of each ReadOut

#       - The dimension 1 contains the ky-space readouts (e.g 156) of each frame.
#               - This dimension has not yet been mapped to, which will be performed during the following binnng steps.

#	- The dimension 3 contains the  23 Coils of each ReadOut

#	- The dimension 10 contains the Time.
#		- The 3421 ReadOuts of the scan are still in this dimension, as these ReadOuts have not yet been binned neither in the ky direction nor in Time itself.
#		- After successful binning, the Time dimension will have a length of 20 (= 20 Timeframes per slice).

#	- The dimension 13 contains the 12 Slices of the Heart.


# In a nutshell:
#	- The idx.cfl file is analoguous to the raw.list file, as it contains the pointers of the different readouts in the same chronological order, but with the coils stacked together.
#	- The _k.cfl file is analoguous to the raw.raw file, as it contains the read out data of the scan. Opposingly to the raw.raw file, the data in _k.cfl is attributed to different dimensions, namely to the Samples, the ky-ReadOuts,  the Coils, the Time and the Slices.
#	- The samples, the coils and the slices are already ordered/binned.
#	- The ReadOuts need to be binned/sorted in the time dimension and in the right readout order for the ky-space, so that every set of readouts represents the kspace of the right space image.


CPHASES=20 # Number of Cardiac Phases #Later interpolated to 30 DICOM frames.
SLICES=$(bart show -d13 _k)
RO=$(bart show -d0 _k)	#Readouts
DIMS=$((2*$RO)) # = RO * scaling factor (2 in our case)
FR=$(bart show -d10 _k)
N_COILS=$(bart show -d3 _k)


bart slice 11 8 idx idx1
# Dimensions of idx1:
# [1 1 1 1 1 1 1 1 1 1 3421 1 1 12 1 1]
# This command corresponds to the following command in python:
#	idx1 = idx[:,:,:,:,:,:,:,:,:,:,:,8,...]
# Remember the 11th dimension of idx.cfl from above ? It contains the same 20 columns as the raw.list file. We are extracting the raw.list column that contains the number of the timeframe of each of the 3421 ReadOuts.
# This allows us to later on bin the different ReadOuts to their respective timeframe


# INTERMEDIATE QUESTIONS
# How to plot idx and idx1 ? ( i dont have spider .. is there a way without readcfl ?)
#does it matter here if i look at idx or idx1 with paradise_angle.py ?
# YES IT DOES ! I JUST HAVE FRAME NUMBERS IN IDX1.CFL
# go through text underneath with Basti to ask if it is right.
python3 ~/ProgramsAndSoftware/paradise_angle.py --floor -g $CPHASES idx gate_full_floor
python3 ~/ProgramsAndSoftware/paradise_angle.py --round -g $CPHASES idx gate_full_round
python3 ~/ProgramsAndSoftware/paradise_angle.py --ceil -g $CPHASES idx gate_full_ceil
# This command allows us to extract from idx the gating pattern of the readouts with respect to the ky axis. We are attributing to each ReadOuts its ky-position between -76 and 75.
# This ky-position is saved in gate_full.


#ARE THE FOLLOWING SLICING STEPS NECESSARY ? CANT I JUST BIN ACCROSS ALL DIMS AT ONCE ?
# 	- No, you cannot. The binning algorithm is not supporting that feature, consider it part of a Beta version. For this reason you need to first extract (bart slice) the dimension you want to bin, then bin it and finally stack (bart join) the binned slices back together.

# IS IDX SLICING NECESSARY ? I SHOULD HAVE EVERYTHING I NEED INSIDE K AND ITS BINNED FORMS NO ?
# 	- Yes, Index slicing is necessary. The idx1 file is only mapping to the right ky, but is ordered in the same order than gate_full. This means that you need to bin the k-space in time with gate_full, then bin idx1 in time with gate_full until you can finally bin the time-binned k-space with the time-binned idx1.

#no need to preserve different temporary slices at different timepoints in the for-loops
#	- only need to keep the result slices (_k_fullbin_sliceX_TX, _k_fullbin_sliceX) and then join them.
#	- once the result slices are joined ( to obtain k.hdr and k.cfl ), they are deleted to save memory.
for gating_type in _floor _round _ceil  #file ending strings that will be attached to gate and k
do
  mv gate_full"$gating_type".hdr _gate_full.hdr
  mv gate_full"$gating_type".cfl _gate_full.cfl

  echo
  echo Binning the k-space for the gating-type "$gating_type"
  for (( slice=0; slice<$SLICES; slice++ ))
  do
  # slice=0
  # #at first run loop for one slice to make sure it works.

    bart slice 1 $slice _gate_full _gate_presliced
    # extract gate slice you want to bin. heart slices are in dim 1
    bart transpose 0 10 _gate_presliced _gate_sliced
    # We then need to transpose the timeframes from dim 0 to dim 10 to match with the _k and _idx1. Otherwhise we cannot bin properly.
    # DIMS: [3421 12-->1] --> [1 1 1 1 1 1 1 1 1 1 3421 1 1 1 1 1]

    bart slice 13 $slice _k _k_sliced
    # extract _k slice you want to bin. heart slices are in dim 13
    # DIMS: [312 1 1 23 1 1 1 1 1 1 3421 1 1 12-->1 1 1]

    bart slice 13 $slice idx1 _idx1_sliced
    # extract timeframe index slice you want to bin. heart slices are in dim 13
    # DIMS: [1 1 1 1 1 1 1 1 1 1 3421 1 1 12-->1 1 1]

    echo Binning the timeframes of the k-space and idx1 for Slice "$slice"
    bart bin -l1 _gate_sliced _k_sliced _k_tbin_sliced1
    # DIMS: [312 3421/20 1 23 1 1 1 1 1 1 20 1 ... 1]
    bart bin -l1 _gate_sliced _idx1_sliced _idx1_tbin_sliced1
    # DIMS: [1 3421/20 1 ... 1 20 1 ... 1]
    # QUESTION: Why is dim1 in fact 228 and not ca. 3421/20 = 172 ???
    #	--> This is because of the zero-filling of all the rows of dim1 to the same max size.


    echo Binning the ky-frames of the time-binned k-space..
    for (( t=0; t<$CPHASES; t++ ))
    do
    # only slice 0
    # t=19
    	bart slice 10 $t _k_tbin_sliced1 _k_tbin_sliced2
    	# DIMS: [312 3421/20 1 23 1 ... 1 20-->1 1 ... 1]

    	bart slice 10 $t _idx1_tbin_sliced1 _idx1_tbin_sliced2
    	# DIMS: [1 3421/20 1 ... 1 20-->1 1 ... 1]

    	bart bin -l12 _idx1_tbin_sliced2 _k_tbin_sliced2 _k_fullbin_tmp
    	# DIMS: [312 #ky=152 1 23 1 ... 1 1 1 1 3421/20/#ky ... 1]

    	# QUESTION: dim12 of _k_fullbin_sliceX_TX is very inconsistent with values between ~59 and ~62. What should I do ?
    	#	- This is due to the fact that many ky lines are present more than once in the data.
    	#	- Additionally, the k-space is zerofilled during the binning.
    	#	- Therefore, the ky-lines that are present once in the data are to find in the 0th out of ca. 61 entries in the 12th dimension.
    	#	--> we will now proceed to extract this ky-data that we want to reconstruct.
    	bart slice 12 0 _k_fullbin_tmp _k_fullbin_tmp2
    	rm _k_tbin_sliced2* _k_fullbin_tmp.*	#save memory, these two files are huge bc the dim12 has ca. 60 entries instead of 1
    	#####
    	# THIS PROCEDURE DOES NOT FULLY WORK YET !!! _K_FULLBIN_tmp STILL IS A HUGE FILE, AS WELL AS K_TBIN_SLICED1 (AT LEAST FOR PATIENT F18)

    	bart resize 1 $(($RO/2)) _k_fullbin_tmp2 _k_fullbin_slice"$slice"_T"$t"
    	# I believe this is wrong ! We should have way more information in every ky !!

# Deactivate to test T0
    done	#end of the Time for-loop (in which ky-readout lines are binned)

    #cat _k_fullbin_slice7_T1.hdr
    # Dimensions
    #312 150 1 23 1 1 1 1 1 1 1 1 1 1 1 1
    #FRAME 1 has only 150 readouts instead of 152!
    # Are we binning right ?
    #	 --> We bin with a slightly different rounding factor than the scanner. We would need to see how the scanner exactly rounds to avoid the 0 filling. In practice, the zero-filling does not really matter, as adding two 0 filled readout lines to the bottom of the kspace is not much of an information loss compared to having these two k-space readouts. Would the center of our k-space be affected by the loss of information, it would be more significant for the output.
    #	-NB: if you want to see why certain images are not well reconstructed, just check out their k-space ! ($view k)

    # Join the 20 Timeframes of each slice:
    nameroot=_k_fullbin_slice"$slice"_T	#nameroot is just for the cosmetic of bart join
    bart join 10 "$nameroot"$(seq -s " $nameroot" 0 $(($CPHASES-1))) _k_fullbin_slice"$slice"
    rm "$nameroot"*
    # Replace for loop with t=0
    # mv _k_fullbin_slice"$slice"_T"$t".hdr _k_fullbin_slice"$slice".hdr
    # mv _k_fullbin_slice"$slice"_T"$t".cfl _k_fullbin_slice"$slice".cfl

  done	#end of the Slice for-loop (in which the timeframes are binned)

  # Join the Slices of the k-space data:
  nameroot=_k_fullbin_slice
  bart join 13 "$nameroot"$(seq -s " $nameroot" 0 $(($SLICES-1))) _k_fullbin
  rm "$nameroot"*
  #
  # # Replace for loop with slice 5
  # mv _k_fullbin_slice"$slice".hdr _k_fullbin.hdr
  # mv _k_fullbin_slice"$slice".cfl _k_fullbin.cfl
  #
  mv _k_fullbin.hdr k"$gating_type".hdr
  mv _k_fullbin.cfl k"$gating_type".cfl
done  #end gating_type Loop

#  View sharing:
python3 ~/ProgramsAndSoftware/view_share.py k_floor k_round k_ceil k

# We can now reconstruct the image.
bart fft -i $(bart bitmask 0 1) k _img0

# The image still needs an fft-shift !
bart fftshift $(bart bitmask 1) _img0 _img1
## QUESTION: 	-Why do we apply the fft-shift to the image space ?
##		-What is actually an fft shift ???


# To obtain an image with coil-intensity weightings, let's do the rss of the coils:
bart rss $(bart bitmask 3) _img1 _img2
## QUESTION: 	-What exactly is RSS doing compared to the IFFT ?

# Flip the patient images into the right view for the M.D.:
bart transpose 0 1 _img2 _img3
bart flip 3 _img3 _img4
bart crop 1 $(($RO/2)) _img4 img_cartesian


echo Successful execution of the code !
echo If you wish to clear up space, run "rm _*"
