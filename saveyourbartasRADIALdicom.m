function saveyourbartasRADIALdicom(cartrecosize, firstcartimageidx, namebartimg, IDpatient)
    
% Let s make some dicoms !!

%% %%%%%% INSTRUCTIONS %%%%%%%%%%%
%%% Take care of having set readcfl to the right image !                %%%
%%% The image you want to load is set to 'pics_W0.001_T0.01' by default.
%%% Change the name if your reconstructed image has a different name.   %%%
%%% Note that the comments about the array dimensions correspond to the
%%% array dimensions of patient M5_080920190630_TURNS5

%% 1) define path of bart_HMS/matlab right (has default)
%% 2) pick correct name for bart image to load (has default)
%% 3) check if cartesian images that are loaded in for loop are in the right range. e.g. from 0002 to 0361
%      --> initialize image_counter accordingly.
%% 4) initialize the cartesian image size for the interpolation of the radial recon.
%        --> you can find the size of the Cartesian image in the "SA SSFP"
%        file under "Reconstruction Matrix"
%% 5) the dicoms are ready. Check them out in the folder 'DICOMsRadialRecon'

%% This section allows you to set the cfl file you want to read, the 
% cartesian online recon image size in the bash script that executes this
% function as well as the first index (should be 1 or 2) of /DICOM/IMG_000X
% from the online reco.

bartfile=namebartimg
Cartimgsize = str2num(cartrecosize)
image_counter = str2num(firstcartimageidx) %%counts the images, images have start index IM0002
ID  = IDpatient %% corresponds to the number of the patient in the metadata.

success = 0


%%
% Add important path
addpath('/home/nw92/ProgramsAndSoftware/bart_HMS/matlab')
addpath('/home/nw92/ProgramsAndSoftware/arrShow')
mkdir DICOMsRadialRecon;

%load bart file with the following command into matlab
mybartimage = readcfl(bartfile); % You must not add the '.cfl' tag at
%the end
mysqueezedbartimage=squeeze(mybartimage);

% load('mysqueezedinput')
absinput=abs(mysqueezedbartimage);
%dims = [296 296 20 13] = [W H TF CH]

% normalize the image
norminput1 = absinput/max(absinput(:));
norminput2 = im2uint8(norminput1);

flipinput = flip(norminput2, 1); %put patient head on top of img

% Crop image to half the size, keep central part
% Images double in size when radially acquired ?!
imgsize=length(flipinput)
croppedimage=flipinput(0.25*imgsize+1:0.75*imgsize, 0.25*imgsize+1:0.75*imgsize, :, :);
%dims = [148 148 20 13] % % specify resolution !
% 
% --> specify resolution from dicominfo
% --> interpolate time to 30 frames
% --> interpolate img to cartesian resolution
% 
% % recon from 1.5x1.5x1.5 to .86 instead of .69 when interpolating
% 
% %presentation: 10 heartbeats fr= [W H TF CH]


% interpolate the image to 30 frames per slice with the same pixel resolution
% as the images of the cartesian folder.
% https://www.mathworks.com/help/matlab/math/resample-image-with-gridded-interpolation.html
F = griddedInterpolant(double(croppedimage));
[sx,sy,st,sz] = size(croppedimage);
xq = linspace(1,sx,Cartimgsize); % 148 pixel --> 256 pixel (same as cartesian image)
yq = linspace(1,sx,Cartimgsize); % 148 pixel --> 256 pixel (same as cartesian image)
tq = linspace(1,st,30);   % 20 --> 30 frames
zq = (1:1:sz)';           % keep 13 slices
vq = uint8(F({xq,yq,tq,zq}));   %our interpolated image
%dims = [256 256 30 13] = [W H TF CH]


id5 = dicomuid;  %create new sequence id for the dicom images

original_DICOM_folder_location = 'DICOM/'
final_DICOM_folder_location = 'DICOMsRadialRecon/'


num_slices= size(vq,4)
for ind = 1:num_slices
    for time=1:30
        
        image_counter;
        metadata = dicominfo(strcat(original_DICOM_folder_location, 'IM_', num2str((image_counter).', '%04d'))); %4 digits zero-filled
% %         metadata.SeriesDescription = ['RECON_ ', metadata.SeriesDescription];
%         metadata.ProtocolName = ['RECON_ ',  metadata.ProtocolName];
        metadata.SeriesDescription = strcat(num2str(ID), '_Nils_radial');
        metadata.ProtocolName = ['Radial_Reconstruction'];
        metadata.SeriesInstanceUID = id5;
        
        dicomwrite(vq(:,:,time,ind), strcat(final_DICOM_folder_location, 'IM_', num2str((image_counter).', '%04d')), metadata);
        image_counter = image_counter + 1;
    
    end
end

success = 1