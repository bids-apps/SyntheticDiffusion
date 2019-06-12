#!/bin/bash
set -e






# first argument, bids_dir
bids_dir=$1

# second argument output_dir
output_dir=$2

# third argument, participant or group
analysis_type=$3

# fourth optional argument, participant label(s)
if [ $# -ge 4 ]; then
  fourth_argument=$4

  if [ "$fourth_argument" != "--participant_label" ]; then
    echo "Fourth argument must be '--participant_label'"
    exit 1
  fi
fi

if [ $# -eq 4 ]; then
  echo "participant_label cannot be empty!"
  exit 1
fi

# Analyze some subjects
if [ $# -ge 5 ]; then
  # Get participant label(s)
  temp="${@:5}"
  participants=()
  string=${temp[$((0))]}
  participants+=($string)
  num_subjects=`echo ${#participants[@]}`
  # Analyze all subjects
else
  num_subjects=`cat ${bids_dir}/participants.tsv  | wc -l`
  #((num_subjects--))
  participants=()
  for s in $(seq 1 ${num_subjects}); do
    if [ "$s" -lt "10" ] ; then
      participants+=(0$s)
    else
      participants+=($s)
    fi
  done
fi

echo -e "\nbids_dir is ${bids_dir}, output_dir is ${output_dir}, analysis type is ${analysis_type}, participants are ${participants[@]}, number of subjects is ${num_subjects} \n"

((num_subjects--))
for s in $(seq 0 ${num_subjects}); do
  subject=sub-${participants[$((s))]}
  echo -e "\n\nAnalyzing subject ${subject}\n\n"

  if [ -e "${bids_dir}/${subject}/anat/${subject}_T1w.nii.gz" ] && [ -e "${bids_dir}/${subject}/dwi/${subject}_dwi.nii.gz" ]; then
    echo "Subject has both T1 and dwi..."
    mkdir -p $output_dir/$subject
    mkdir -p $output_dir/$subject/anat
    mkdir -p $output_dir/$subject/dwi
    mkdir -p $output_dir/$subject/cyclegan

    T1=$bids_dir/$subject/anat/${subject}_T1w.nii.gz
    T1_brain=$output_dir/${subject}/anat/${subject}_T1w_brain.nii.gz
    T1_brain_cyclegan=$output_dir/${subject}/cyclegan/${subject}_T1w_brain.nii.gz
    cyclegan_model=$output_dir/${subject}/cyclegan/G_A2B_weights.hdf5
    FA_synthetic_cyclegan=$output_dir/${subject}/cyclegan/${subject}_FA_synthetic.nii.gz
    FA_synthetic=$output_dir/${subject}/dwi/${subject}_FA_synthetic.nii.gz
    dwi=$bids_dir/${subject}/dwi/${subject}_dwi.nii.gz
    dwi_brain=$output_dir/${subject}/dwi/sub
    dwi_brain_eddy_corrected=$output_dir/${subject}/dwi/${subject}_dwi_brain_eddy_corrected.nii.gz
    dwi2T1_brain_eddy_corrected=$output_dir/${subject}/dwi/${subject}_dwi2T1_brain_eddy_corrected.nii.gz
    dwi2T1_brain_mask=$output_dir/${subject}/dwi/${subject}_dwi2T1_brain_mask.nii.gz
    dwi2T1_FA=$output_dir/${subject}/dwi/${subject}_dwi2T1_FA.nii.gz
    dwi2T12synthetic_FA=$output_dir/${subject}/dwi/${subject}_dwi2T12synthetic_FA.nii.gz
    b0_brain=$output_dir/${subject}/dwi/${subject}_b0_brain.nii.gz
    b02T1=$output_dir/${subject}/dwi/b02T1
    bval=$bids_dir/${subject}/dwi/${subject}_dwi.bval
    bvec=$bids_dir/${subject}/dwi/${subject}_dwi.bvec

    echo "Bet T1 brain..."
    bet $T1 $T1_brain

    echo "Generate synthetic FA..."
    curl -Ls https://www.dropbox.com/sh/jujqd6wqpy2i8t5/AABPQ_v0zIGTiVN7RYqm7SQGa?dl=0 > $output_dir/$subject/cyclegan/download.zip
    unzip -oq $output_dir/$subject/cyclegan/download.zip -x / -d $output_dir/$subject/cyclegan
    rm -rf $output_dir/$subject/cyclegan/download.zip
    mkdir -p $output_dir/${subject}/anat/temp
    fslsplit $T1_brain $output_dir/${subject}/anat/temp/${subject}_T1w_brain_slice_ -z
    fslmerge -t $T1_brain_cyclegan $output_dir/${subject}/anat/temp/${subject}_T1w_brain_slice_* 2> $output_dir/${subject}/temp.txt
    rm -rf $output_dir/${subject}/anat/temp
    cd /home
    normalization_factor_X=$(fslstats $T1_brain -P 99)
    python3.6 runCycleGAN.py $cyclegan_model $T1_brain_cyclegan $FA_synthetic_cyclegan $normalization_factor_X > $output_dir/${subject}/temp.txt
    mkdir -p $output_dir/${subject}/cyclegan/temp
    fslsplit $FA_synthetic_cyclegan $output_dir/${subject}/cyclegan/temp/${subject}_FA_synthetic_volume_ -t
    fslmerge -z $FA_synthetic $output_dir/${subject}/cyclegan/temp/${subject}_FA_synthetic_volume_*
    rm -rf $output_dir/${subject}/cyclegan/temp

    echo "Eddy and head motion correction..."
    bet $dwi $dwi_brain -f 0.2 -F
    eddy_correct $dwi_brain $dwi_brain_eddy_corrected 0 > $output_dir/${subject}/temp.txt

    echo "Register dwi to T1..."
    fslroi $dwi_brain $b0_brain 0 1
    epi_reg --epi=$b0_brain --t1=$T1 --t1brain=$T1_brain --out=$b02T1 > $output_dir/${subject}/temp.txt
    flirt -in $dwi_brain_eddy_corrected -ref $T1_brain -applyxfm -init ${b02T1}.mat -out $dwi2T1_brain_eddy_corrected

    echo "DTI fit..."
    bet $dwi2T1_brain_eddy_corrected $output_dir/${subject}/dwi/${subject}_dwi2T1_brain -f 0.2 -n -m
    dtifit --data=$dwi2T1_brain_eddy_corrected --out=$output_dir/${subject}/dwi/${subject}_dwi2T1 --mask=$dwi2T1_brain_mask --bvals=$bval --bvecs=$bvec > $output_dir/${subject}/dwi/temp.txt

    echo "Register FA to FA synthetic..."
    fnirt --ref=$FA_synthetic --in=$dwi2T1_FA --iout=$dwi2T12synthetic_FA --config=/usr/local/fsl/etc/flirtsch/FA_2_FMRIB58_1mm.cnf

    rm -f $output_dir/${subject}/temp.txt

  elif [ -e "${bids_dir}/${subject}/anat/${subject}_T1w.nii.gz" ]; then
    echo "Subject has only T1..."
    mkdir -p $output_dir/$subject
    mkdir -p $output_dir/$subject/anat
    mkdir -p $output_dir/$subject/dwi
    mkdir -p $output_dir/$subject/cyclegan

    T1=$bids_dir/$subject/anat/${subject}_T1w.nii.gz
    T1_brain=$output_dir/${subject}/anat/${subject}_T1w_brain.nii.gz
    T1_brain_cyclegan=$output_dir/${subject}/cyclegan/${subject}_T1w_brain.nii.gz
    cyclegan_model=$output_dir/${subject}/cyclegan/G_A2B_weights.hdf5
    FA_synthetic_cyclegan=$output_dir/${subject}/cyclegan/${subject}_FA_synthetic.nii.gz
    FA_synthetic=$output_dir/${subject}/dwi/${subject}_FA_synthetic.nii.gz
    dwi=$bids_dir/${subject}/dwi/${subject}_dwi.nii.gz
    dwi_brain=$output_dir/${subject}/dwi/sub
    dwi_brain_eddy_corrected=$output_dir/${subject}/dwi/${subject}_dwi_brain_eddy_corrected.nii.gz
    dwi2T1_brain_eddy_corrected=$output_dir/${subject}/dwi/${subject}_dwi2T1_brain_eddy_corrected.nii.gz
    dwi2T1_brain_mask=$output_dir/${subject}/dwi/${subject}_dwi2T1_brain_mask.nii.gz
    dwi2T1_FA=$output_dir/${subject}/dwi/${subject}_dwi2T1_FA.nii.gz
    dwi2T12synthetic_FA=$output_dir/${subject}/dwi/${subject}_dwi2T12synthetic_FA.nii.gz
    b0_brain=$output_dir/${subject}/dwi/${subject}_b0_brain.nii.gz
    b02T1=$output_dir/${subject}/dwi/b02T1
    bval=$bids_dir/${subject}/dwi/${subject}_dwi.bval
    bvec=$bids_dir/${subject}/dwi/${subject}_dwi.bvec

    echo "Bet T1 brain..."
    bet $T1 $T1_brain

    echo "Generate synthetic FA..."
    curl -Ls https://www.dropbox.com/sh/jujqd6wqpy2i8t5/AABPQ_v0zIGTiVN7RYqm7SQGa?dl=0 > $output_dir/$subject/cyclegan/download.zip
    unzip -oq $output_dir/$subject/cyclegan/download.zip -x / -d $output_dir/$subject/cyclegan
    rm -rf $output_dir/$subject/cyclegan/download.zip
    mkdir -p $output_dir/${subject}/anat/temp
    fslsplit $T1_brain $output_dir/${subject}/anat/temp/${subject}_T1w_brain_slice_ -z
    fslmerge -t $T1_brain_cyclegan $output_dir/${subject}/anat/temp/${subject}_T1w_brain_slice_* 2> $output_dir/${subject}/temp.txt
    rm -rf $output_dir/${subject}/anat/temp
    cd /home
    python3.6 runCycleGAN.py $cyclegan_model $T1_brain_cyclegan $FA_synthetic_cyclegan > $output_dir/${subject}/temp.txt
    mkdir -p $output_dir/${subject}/cyclegan/temp
    fslsplit $FA_synthetic_cyclegan $output_dir/${subject}/cyclegan/temp/${subject}_FA_synthetic_volume_ -t
    fslmerge -z $FA_synthetic $output_dir/${subject}/cyclegan/temp/${subject}_FA_synthetic_volume_*
    rm -rf $output_dir/${subject}/cyclegan/temp
    rm -f $output_dir/${subject}/temp.txt

  else
    echo "Subject has no T1 or dwi, nothing to do..."
  fi

done
