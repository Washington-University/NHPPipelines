#!/bin/bash

bindir=/home/moises/PTX2/bin
scriptsdir=/home/moises/Tractography_gpu_scripts
cuda_queue=dque_gpu

#this is specific for WashU cluster
#export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/home/moises/PTX2/lib:/export/cuda-6.0/lib64

if [ "$2" == "" ];then
    echo ""
    echo "usage: $0 <StudyFolder> <Subject>"
    echo ""
    exit 1
fi

StudyFolder=$1          # "$1" #Path to Generic Study folder
Subject=$2              # "$2" #SubjectID

Nsamples=3000
TemplateFolder=${StudyFolder}/91282_Greyordinates
OutFileName="Conn3.dconn.nii"

ResultsFolder="$StudyFolder"/"$Subject"/MNINonLinear/Results/Tractography
RegFolder="$StudyFolder"/"$Subject"/MNINonLinear/xfms
ROIsFolder="$StudyFolder"/"$Subject"/MNINonLinear/ROIs
if [ ! -e ${ResultsFolder} ] ; then
  mkdir ${ResultsFolder}
fi

#Use BedpostX samples
BedpostxFolder="$StudyFolder"/"$Subject"/T1w/Diffusion.bedpostX
DtiMask=$BedpostxFolder/nodif_brain_mask


rm -rf $ResultsFolder/stop
rm -rf $ResultsFolder/volseeds
rm -rf $ResultsFolder/wtstop
rm -f $ResultsFolder/Mat3_targets


#Temporarily here, should be in Prepare_Seeds
echo $ResultsFolder/CIFTI_STRUCTURE_ACCUMBENS_LEFT >> $ResultsFolder/volseeds
echo $ResultsFolder/CIFTI_STRUCTURE_ACCUMBENS_RIGHT >> $ResultsFolder/volseeds
echo $ResultsFolder/CIFTI_STRUCTURE_AMYGDALA_LEFT >> $ResultsFolder/volseeds
echo $ResultsFolder/CIFTI_STRUCTURE_AMYGDALA_RIGHT >> $ResultsFolder/volseeds
echo $ResultsFolder/CIFTI_STRUCTURE_BRAIN_STEM >> $ResultsFolder/volseeds
echo $ResultsFolder/CIFTI_STRUCTURE_CAUDATE_LEFT >> $ResultsFolder/volseeds
echo $ResultsFolder/CIFTI_STRUCTURE_CAUDATE_RIGHT >> $ResultsFolder/volseeds
echo $ResultsFolder/CIFTI_STRUCTURE_CEREBELLUM_LEFT >> $ResultsFolder/volseeds
echo $ResultsFolder/CIFTI_STRUCTURE_CEREBELLUM_RIGHT >> $ResultsFolder/volseeds
echo $ResultsFolder/CIFTI_STRUCTURE_DIENCEPHALON_VENTRAL_LEFT >> $ResultsFolder/volseeds
echo $ResultsFolder/CIFTI_STRUCTURE_DIENCEPHALON_VENTRAL_RIGHT >> $ResultsFolder/volseeds
echo $ResultsFolder/CIFTI_STRUCTURE_HIPPOCAMPUS_LEFT >> $ResultsFolder/volseeds
echo $ResultsFolder/CIFTI_STRUCTURE_HIPPOCAMPUS_RIGHT >> $ResultsFolder/volseeds
echo $ResultsFolder/CIFTI_STRUCTURE_PALLIDUM_LEFT >> $ResultsFolder/volseeds
echo $ResultsFolder/CIFTI_STRUCTURE_PALLIDUM_RIGHT >> $ResultsFolder/volseeds
echo $ResultsFolder/CIFTI_STRUCTURE_PUTAMEN_LEFT >> $ResultsFolder/volseeds
echo $ResultsFolder/CIFTI_STRUCTURE_PUTAMEN_RIGHT >> $ResultsFolder/volseeds
echo $ResultsFolder/CIFTI_STRUCTURE_THALAMUS_LEFT >> $ResultsFolder/volseeds
echo $ResultsFolder/CIFTI_STRUCTURE_THALAMUS_RIGHT >> $ResultsFolder/volseeds

#Define Generic Options
generic_options=" --loopcheck --forcedir --fibthresh=0.01 -c 0.2 --sampvox=2 --randfib=1 -P ${Nsamples} -S 2000 --steplength=0.5"
oG=" -s $BedpostxFolder/merged -m $DtiMask --meshspace=caret"

#Define Seed
Seed=$ROIsFolder/Whole_Brain_Trajectory_ROI_2
StdRef=$FSLDIR/data/standard/MNI152_T1_2mm_brain_mask
oG=" $oG -x $Seed --seedref=$StdRef"
oG=" $oG --xfm=`echo $RegFolder/standard2acpc_dc` --invxfm=`echo $RegFolder/acpc_dc2standard`"

#Define Termination and Waypoint Masks
echo $ResultsFolder/pial.L.asc >> $ResultsFolder/stop                   #Pial Surface as Stop Mask
echo $ResultsFolder/pial.R.asc >> $ResultsFolder/stop

echo $ResultsFolder/CIFTI_STRUCTURE_ACCUMBENS_LEFT >> $ResultsFolder/wtstop    #WM boundary Surface and subcortical volumes as Wt_Stop Masks
echo $ResultsFolder/CIFTI_STRUCTURE_ACCUMBENS_RIGHT >> $ResultsFolder/wtstop   #Exclude Brainstem and diencephalon, otherwise cortico-cerebellar connections are stopped!
echo $ResultsFolder/CIFTI_STRUCTURE_AMYGDALA_LEFT >> $ResultsFolder/wtstop
echo $ResultsFolder/CIFTI_STRUCTURE_AMYGDALA_RIGHT >> $ResultsFolder/wtstop
echo $ResultsFolder/CIFTI_STRUCTURE_CAUDATE_LEFT >> $ResultsFolder/wtstop
echo $ResultsFolder/CIFTI_STRUCTURE_CAUDATE_RIGHT >> $ResultsFolder/wtstop
echo $ResultsFolder/CIFTI_STRUCTURE_CEREBELLUM_LEFT >> $ResultsFolder/wtstop
echo $ResultsFolder/CIFTI_STRUCTURE_CEREBELLUM_RIGHT >> $ResultsFolder/wtstop
echo $ResultsFolder/CIFTI_STRUCTURE_HIPPOCAMPUS_LEFT >> $ResultsFolder/wtstop
echo $ResultsFolder/CIFTI_STRUCTURE_HIPPOCAMPUS_RIGHT >> $ResultsFolder/wtstop
echo $ResultsFolder/CIFTI_STRUCTURE_PALLIDUM_LEFT >> $ResultsFolder/wtstop
echo $ResultsFolder/CIFTI_STRUCTURE_PALLIDUM_RIGHT >> $ResultsFolder/wtstop
echo $ResultsFolder/CIFTI_STRUCTURE_PUTAMEN_LEFT >> $ResultsFolder/wtstop
echo $ResultsFolder/CIFTI_STRUCTURE_PUTAMEN_RIGHT >> $ResultsFolder/wtstop
echo $ResultsFolder/CIFTI_STRUCTURE_THALAMUS_LEFT >> $ResultsFolder/wtstop
echo $ResultsFolder/CIFTI_STRUCTURE_THALAMUS_RIGHT >> $ResultsFolder/wtstop
echo $ResultsFolder/white.L.asc >> $ResultsFolder/wtstop
echo $ResultsFolder/white.R.asc >> $ResultsFolder/wtstop
oG=" $oG --stop=${ResultsFolder}/stop --wtstop=$ResultsFolder/wtstop"  #Should we include an exclusion along the midsagittal plane (without the CC and the commisures)?
oG=" $oG --waypoints=${ROIsFolder}/Whole_Brain_Trajectory_ROI_2"       #Use a waypoint to exclude streamlines that go through CSF 


#Define Targets
echo $ResultsFolder/white.L.asc >> $ResultsFolder/Mat3_targets
echo $ResultsFolder/white.R.asc >> $ResultsFolder/Mat3_targets
cat $ResultsFolder/volseeds >> $ResultsFolder/Mat3_targets
o=" $oG --omatrix3 --target3=$ResultsFolder/Mat3_targets"

rm -f $ResultsFolder/commands_Mat3.txt
rm -rf $ResultsFolder/Mat3_logs
mkdir -p $ResultsFolder/Mat3_logs

out=" --dir=$ResultsFolder"
echo $bindir/probtrackx2_gpu $generic_options $o $out >> $ResultsFolder/commands_Mat3.txt

# USING SGE-FMRIB	  
#ptx2_id=`fsl_sub -T 720 -R 64000 -Q $cuda_queue -l $ResultsFolder/Mat3_logs -N ptx2_Mat3 -t $ResultsFolder/commands_Mat3.txt`

# USING PBS-WASHU
torque_command="qsub -q $cuda_queue -V -l nodes=1:ppn=1:gpus=1,walltime=12:00:00 -N ptx2_Mat3 -o $ResultsFolder/Mat3_logs  -e $ResultsFolder/Mat3_logs "
ptx2_id=`exec $torque_command $ResultsFolder/commands_Mat3.txt | awk '{print $1}' | awk -F. '{print $1}'`
sleep 10 

fsl_sub -T 180 -R 35000 -j $ptx2_id -l $ResultsFolder/Mat3_logs -N Mat3_conn $scriptsdir/PostProcMatrix3.sh $StudyFolder $Subject $TemplateFolder $OutFileName
