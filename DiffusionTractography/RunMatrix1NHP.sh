#!/bin/bash

#bindir=/home/moises/PTX2/bin
#scriptsdir=/home/moises/Tractography_gpu_scripts
#cuda_queue=dque_gpu
bindir=/mnt/pub/devel/PROBTRACKX2/CentOS6.5
scriptsdir=/mnt/pub/devel/NHPHCPPipeline/Tractography
cuda_queue=cuda.q

#this is specific for WashU cluster
#export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/home/moises/PTX2/lib:/export/cuda-6.0/lib64
export LD_LIBRARY_PATH=/opt/glibc-2.14/lib:/usr/local/cuda-6.5/lib64  # valid for compass-s in RIKEN

if [ "$2" == "" ];then
    echo ""
    echo "usage: $0 <StudyFolder> <Subject>"
    echo ""
    echo " Export SPECIES to either of Human, Macaque and Macaque_MNI before running this script"
    echo " Run PreTractograhyNHP.sh before running this script"
    echo ""
    exit 1
fi

StudyFolder=$1          # "$1" #Path to Generic Study folder
Subject=$2              # "$2" #SubjectID

if [ "$SPECIES" = "Human" ] || [ "$SPECIES" = "" ] ; then
	HCPPIPEDIR=/mnt/pub/devel/NHPHCPPipeline
	. $HCPPIPEDIR/Examples/Scripts/SetUpHCPPipelineNHP.sh
	TemplateFolder="${HCPPIPEDIR_Templates}/91282_Greyordinates"
	StdRef=$FSLDIR/data/standard/MNI152_T1_2mm_brain_mask
elif [ "$SPECIES" = "Macaque_MNI" ] ; then
        #HCPPIPEDIR=/usr/local/NHPHCP/NHPHCPPipelinesFairGroup
	#echo yes1
        #. $HCPPIPEDIR/Examples/Scripts/SetUpHCPPipelineNHP.sh
	#echo yes2
	TemplateFolder="$SurfaceAtlasDIR" #"${HCPPIPEDIR_Templates}/standard_mesh_atlases_macaque_MNI"
	StdRef=$T1wTemplate
	if [ "$StdRef" = "" ] ; then
		echo "ERROR: T1wTemplate not yet exported"; exit 1
	fi
elif [ "$SPECIES" = "Macaque" ] || [ "$SPECIES" = "Marmoset" ] ; then
       HCPPIPEDIR=/mnt/pub/devel/NHPHCPPipeline
       . $HCPPIPEDIR/Examples/Scripts/SetUpHCPPipelineNHP.sh
	TemplateFolder="$SurfaceAtlasDIR" #"${HCPPIPEDIR_Templates}/standard_mesh_atlases_macaque"
	StdRef=$T1wTemplate
	if [ "$StdRef" = "" ] ; then
		echo "ERROR: T1wTemplate not yet exported"; exit 1
	fi
else
	echo "ERROR: $SPECIES not yet supported"; exit 1
fi

Nsamples=10000
#TemplateFolder=${StudyFolder}/91282_Greyordinates
OutFileName="Conn1.dconn.nii"

ResultsFolder="$StudyFolder"/"$Subject"/MNINonLinear/Results/Tractography
RegFolder="$StudyFolder"/"$Subject"/MNINonLinear/xfms
ROIsFolder="$StudyFolder"/"$Subject"/MNINonLinear/ROIs
if [ ! -e ${ResultsFolder} ] ; then
  mkdir -p ${ResultsFolder}
fi

#Use BedpostX samples
BedpostxFolder="$StudyFolder"/"$Subject"/T1w/Diffusion.bedpostX
DtiMask=$BedpostxFolder/nodif_brain_mask
#Or RubiX samples
#BedpostxFolder="$StudyFolder"/"$Subject"/T1w/Diffusion.rubiX
#DtiMask=$BedpostxFolder/HRbrain_mask

rm -rf $ResultsFolder/stop
rm -rf $ResultsFolder/wtstop
rm -rf $ResultsFolder/volseeds
rm -rf $ResultsFolder/Mat1_seeds

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

# Tuned options based on monkey exvivo study (Donahue et al JNS 2016) - Takuya Hayashi
DiffRes=`${FSLDIR}/bin/fslval ${BedpostxFolder}/mean_f1samples pixdim1`
DiffRes=`printf "%0.2f" ${DiffRes}`
STEPLENGTH=`echo $DiffRes / 4 | bc -l | awk '{printf "%0.2f", $1}'`
PATHLENGTH=200  # Maximum length in mm for macaque according to Donahue et al
NSTEPS=`echo "$PATHLENGTH / $STEPLENGTH" | bc`
CURV=0

#Define Generic Options (added --opd --ompl, Takuya Hayashi to generate length)
generic_options=" --loopcheck --forcedir --fibthresh=0.01 -c ${CURV} --sampvox=2 --randfib=1 -P ${Nsamples} -S ${NSTEPS} --steplength=${STEPLENGTH} --opd --ompl"
o=" -s $BedpostxFolder/merged -m $DtiMask --meshspace=caret"

#Define Seed
echo $ResultsFolder/white.L.asc >> $ResultsFolder/Mat1_seeds
echo $ResultsFolder/white.R.asc >> $ResultsFolder/Mat1_seeds
cat $ResultsFolder/volseeds >> $ResultsFolder/Mat1_seeds
Seed="$ResultsFolder/Mat1_seeds"
#StdRef=$FSLDIR/data/standard/MNI152_T1_2mm_brain_mask

o=" $o -x $Seed --seedref=$StdRef"
o=" $o --xfm=`echo $RegFolder/standard2acpc_dc` --invxfm=`echo $RegFolder/acpc_dc2standard`"

#Define Termination and Waypoint Masks
echo $ResultsFolder/pial.L.asc >> $ResultsFolder/stop      #Pial Surface as Stop Mask
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
o=" $o --stop=${ResultsFolder}/stop --wtstop=$ResultsFolder/wtstop --forcefirststep"  #Should we include an exclusion along the midsagittal plane (without the CC and the commisures)?
#o=" $o --waypoints=${ROIsFolder}/Whole_Brain_Trajectory_ROI_2"       #Use a waypoint to exclude streamlines that go through CSF
TrajRes=`${FSLDIR}/bin/fslval $StdRef pixdim1`
TrajRes=`printf "%0.2f" ${TrajRes}`
o=" $o --waypoints=${ROIsFolder}/Whole_Brain_Trajectory_ROI_$TrajRes"       #Use a waypoint to exclude streamlines that go through CSF

#Define Targets
o=" $o --omatrix1"

rm -rf $ResultsFolder/commands_Mat1.txt
rm -rf $ResultsFolder/Mat1_logs
mkdir -p $ResultsFolder/Mat1_logs

out=" --dir=$ResultsFolder"
echo $bindir/probtrackx2_gpu $generic_options $o $out  >> $ResultsFolder/commands_Mat1.txt

#Do Tractography
#N100: ~5h, 35GB RAM
echo "Queueing Probtrackx"

# USING SGE-FMRIB
#ptx_id=`fsl_sub -T 720 -R 40000 -Q $cuda_queue -l $ResultsFolder/Mat1_logs -N ptx2_Mat1 -t $ResultsFolder/commands_Mat1.txt`

# USING PBS-WASHU
#torque_command="qsub -q $cuda_queue -V -l nodes=1:ppn=1:gpus=1,walltime=12:00:00 -N ptx2_Mat1 -o $ResultsFolder/Mat1_logs  -e $ResultsFolder/Mat1_logs "
#ptx2_id=`exec $torque_command $ResultsFolder/commands_Mat1.txt | awk '{print $1}' | awk -F. '{print $1}'`

# RIKEN
ptx_id=`fsl_sub -T 720 -q $cuda_queue -l $ResultsFolder/Mat1_logs -N ptx_Mat1 -t $ResultsFolder/commands_Mat1.txt`
echo "$ptx_id"
sleep 10

#Create CIFTI file=Mat1+Mat1_transp (1.5 hours, 36 GB)
#fsl_sub -T 180 -R 40000 -j $ptx2_id -l $ResultsFolder/Mat1_logs -N Mat1_conn $scriptsdir/PostProcMatrix1.sh $StudyFolder $Subject $TemplateFolder ${OutFileName}
fsl_sub -T 180 -j $ptx_id -l $ResultsFolder/Mat1_logs -N Mat1_conn $scriptsdir/PostProcMatrix1_RIKEN.sh $StudyFolder $Subject $TemplateFolder ${OutFileName} -l
