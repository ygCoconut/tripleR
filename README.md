# TripleR

This project aims at performing Radial Real-time Reconstructions (triple R) on heavily undersampled free-breathing MRI data.

The tool used to perform the reconstructions is BART (Berkeley Advanced Reconstruction Toolbox)
	- https://github.com/mrirecon/bart

This Project delivers code that allows you to reconstruct radial undersampled and cartesian data from phillips scanners.

## Prerequisites:
	- Install the right bart version (bart_HMS). This version is a homebrew version, so don't expect to get the code running without it! You will need to implement certain functions by yourself as they are not published yet.
		- Phillips sequence reader (bart paradiseread).
	- Also not available on git:
		- paradise_angle.py (src folder content not in git)
		- b0cor.py (src folder content not in git)
	- set up bart for matlab following the instructions of the bart repo( You will need the "readcfl.mat" function of bart )
	- set up bart for python following the instructions of the bart repo ( You will need the "readcfl.py" function of bart )
	- get paradiseangle.py and set up its $PATH and access to bart with $TOOLBOX_PATH
	- (optional) Install the arrayshow matlab viewer or/and the bart viewer.
	- https://github.com/tsumpf/arrShow

## How To:

1) Copy the patient folder to this folder and rename the patient folder accordingly:
Gender_MMDDYYYYTIME (--> no spaces)

2) Options:
	- a) Copy the content of the folder "CopyTheContent" inside the patient folder.
	- b) Copy the files runcart.sh, runradial.sh, saveyourbartasRADIALdicom.mat, saveyourbartasCARTESIANdicom.mat and the folder jobs/ to your patient folder
	- c) source the files mentioned above and only modify the files inside of the jobs folder in your local patient folder.

3) Synchronise (Upload) your patient folder to the O2 cluster.
In WSL or unix with rsync:

$ 	rsync -avP yourpatientfolder/ nw92@transfer.rc.hms.harvard.edu:/home/nw92/RealTimeRecoCSproject/yourpatientfolder/

4) Open the shell script "run.sh" and modify the parameters that are indicated in the top of the shell script:
	- TFE factor
	- TURNS (should be 20)
	- CPHASES (should be 20)
	--> You can find these parameters in the "Radial One Breathhold.txt" (= scan protocol) file, or in the "raw_001.list" file
	- in runradial.sh and runcart.sh, set the path to the file "paradiseangle.py", so that it is accessible to your shell script.

5) Open the matlab script "saveyourbartasdicom.m" and modify the parameters that are indicated in the top of the matlab script:
	- index of first cartesian image (should be 1 or 2)
	- size of cartesian image (can be found in the "SA SSFP" file under "Reconstruction matrix"
	- The matlab file "saveyourbartasdicom.mat" allows you to save, you guess it, your bart output file as a dicom.
	- A whole run should not take more than a couple minutes.
	- To run the matlab code on its own (should not be needed), follow the instructions written in the Matlab code.

6) Run the gpumaster.sh file, which is located inside the folder "jobs/":

$ 	sbatch gpumaster.sh

6) Take care of noting down the runtime for the algorithm.
	- If you care about the runtime, it is written in the file "runtime.txt" inside your patient folder.
	- The runtime should be around 1 hour, likely less.
	- I currently take 4 cores with 10 GB and 1 teslaV100 gpu. Note that different gpus have different speed.

7) Copy your freshly produced radial DICOMs to your local computer (supposing your are in the local patient folder):
$	rsync -avP nw92@transfer.rc.hms.harvard.edu:/home/nw92/RealTimeRecoCSproject/yourpatientfolder/MYIMAGES/ ./MYIMAGES/
$	rsync -avP nw92@transfer.rc.hms.harvard.edu:/home/nw92/RealTimeRecoCSproject/yourpatientfolder/runtime.txt ./

8) Congrats ! You are done. The DICOM can now be read with the circleCVI software of the clinicians .

