#!/bin/bash
set -e






# first argument, bids_dir
bids_dir=$1

# second argument output_dir
output_dir=$2

# third argument, participant or group
analysis_type=$3

echo -e "\n\nAnalyzing sub-01\n\n"

T1=$bids_dir/sub-01/anat/sub-01_T1w.nii.gz
T1_brain=$output_dir/sub-01/anat/sub-01_T1w_brain.nii.gz
T1_brain_cyclegan=$output_dir/sub-01/cyclegan/sub-01_T1w_brain.nii.gz
cyclegan_model=$bids_dir/sub-01/cyclegan/G_A2B_weights.hdf5
FA_synthetic_cyclegan=$output_dir/sub-01/cyclegan/sub-01_FA_synthetic.nii.gz
FA_synthetic=$output_dir/sub-01/dwi/sub-01_FA_synthetic.nii.gz
dwi=$bids_dir/sub-01/dwi/sub-01_dwi.nii.gz
dwi_brain=$output_dir/sub-01/dwi/sub
dwi_brain_eddy_corrected=$output_dir/sub-01/dwi/sub-01_dwi_brain_eddy_corrected.nii.gz
dwi2T1_brain_eddy_corrected=$output_dir/sub-01/dwi/sub-01_dwi2T1_brain_eddy_corrected.nii.gz
dwi2T1_brain_mask=$output_dir/sub-01/dwi/sub-01_dwi2T1_brain_mask.nii.gz
dwi2T1_FA=$output_dir/sub-01/dwi/sub-01_dwi2T1_FA.nii.gz
dwi2T12synthetic_FA=$output_dir/sub-01/dwi/sub-01_dwi2T12synthetic_FA.nii.gz
b0_brain=$output_dir/sub-01/dwi/sub-01_b0_brain.nii.gz
b02T1=$output_dir/sub-01/dwi/b02T1
bval=$bids_dir/sub-01/dwi/sub-01_dwi.bval
bvec=$bids_dir/sub-01/dwi/sub-01_dwi.bvec

echo "bet T1 brain..." 
bet $T1 $T1_brain


fslroi $T1 $T1 0 144 0 174 0 144
fslroi $T1_brain $T1_brain 0 144 0 174 0 144
fslroi $dwi $dwi 0 144 0 168 0 110

echo "Prepare cyclegan T1..."
mkdir -p $bids_dir/sub-01/anat/temp
fslsplit $T1_brain $bids_dir/sub-01/anat/temp/sub-01_T1w_brain_slice_ -z
fslmerge -t $T1_brain_cyclegan $bids_dir/sub-01/anat/temp/sub-01_T1w_brain_slice_*
rm -rf $bids_dir/sub-01/anat/temp

echo "Generate synthetic FA..."
cd /home
python3.6 runCycleGAN.py $cyclegan_model $T1_brain_cyclegan $FA_synthetic_cyclegan

echo "Convert cyclegan FA to regular..."
mkdir -p $output_dir/sub-01/cyclegan/temp
fslsplit $FA_synthetic_cyclegan $output_dir/sub-01/cyclegan/temp/sub-01_FA_synthetic_volume_ -t
fslmerge -z $FA_synthetic $output_dir/sub-01/cyclegan/temp/sub-01_FA_synthetic_volume_*
rm -rf $output_dir/sub-01/cyclegan/temp

echo "eddy correct..."
bet $dwi $dwi_brain -f 0.2 -F
eddy_correct $dwi_brain $dwi_brain_eddy_corrected 0

echo "Register dwi to T1..."
fslroi $dwi_brain $b0_brain 0 1
epi_reg --epi=$b0_brain --t1=$T1 --t1brain=$T1_brain --out=$b02T1
flirt -in $dwi_brain_eddy_corrected -ref $T1_brain -applyxfm -init ${b02T1}.mat -out $dwi2T1_brain_eddy_corrected

echo "DTI fit..."
bet $dwi2T1_brain_eddy_corrected $output_dir/sub-01/dwi/sub-01_dwi2T1_brain -f 0.2 -n -m
dtifit --data=$dwi2T1_brain_eddy_corrected --out=$output_dir/sub-01/dwi/sub-01_dwi2T1 --mask=$dwi2T1_brain_mask --bvals=$bval --bvecs=$bvec

echo "Register FA to FA synthetic..."
fnirt --ref=$FA_synthetic --in=$dwi2T1_FA --iout=$dwi2T12synthetic_FA --config=/usr/local/fsl/etc/flirtsch/FA_2_FMRIB58_1mm.cnf
