#!/bin/bash
set -e
. /usr/local/NHPHCP/NHPHCPPipelinesFairGroup/global/scripts/log.shlib
. /usr/local/NHPHCP/NHPHCPPipelinesFairGroup/Examples/Scripts/SetUpHCPPipeline_RIKEN.sh

if [ "$2" == "" ];then
    echo ""
    echo "usage: $0 <StudyFolder> <Subject>"
    echo "       T1w and MNINonLinear folders are expected within <StudyFolder>/<Subject>"
    echo "       Set SPECIES beforehand to either of Human, Macaque or Marmoset"
    echo ""
    exit 1
fi
########################################## SUPPORT FUNCTIONS #####################################################
# function for parsing options
getopt1() {
    sopt="$1"
    shift 1
    for fn in $@ ; do
	if [ `echo $fn | grep -- "^${sopt}=" | wc -w` -gt 0 ] ; then
	    echo $fn | sed "s/^${sopt}=//"
	    return 0
	fi
    done
}

defaultopt() {
    echo $1
}

################################################## OPTION PARSING ###################################################
# Input Variables
StudyFolder=`getopt1 "--path" $@`                # "$1" #Path to Generic Study folder
Subject=`getopt1 "--subject" $@`                 # "$2" #SubjectID
LowResMesh=`getopt1 "--lowresmesh" $@`                 # "$2" #SubjectID
StandardResolution=`getopt1 "--standardresolution" $@`
StudyFolder=$1
Subject=$2  

WholeBrainTrajectoryLabels=${HCPPIPEDIR_Config}/WholeBrainFreeSurferTrajectoryLabelTableLut.txt
LeftCerebralTrajectoryLabels=${HCPPIPEDIR_Config}/LeftCerebralFreeSurferTrajectoryLabelTableLut.txt 
RightCerebralTrajectoryLabels=${HCPPIPEDIR_Config}/RightCerebralFreeSurferTrajectoryLabelTableLut.txt
FreeSurferLabels=${HCPPIPEDIR_Config}/FreeSurferAllLut.txt


T1wDiffusionFolder="${StudyFolder}/${Subject}/T1w/Diffusion"
DiffusionResolution=`${FSLDIR}/bin/fslval ${T1wDiffusionFolder}/data pixdim1`
DiffusionResolution=`printf "%0.2f" ${DiffusionResolution}`

if [ "$SPECIES" != Marmoset ] ; then
	LowResMesh=32
else
	LowResMesh=10
fi

#StandardResolution="2"
StandardResolution=`${FSLDIR}/bin/fslval ${StudyFolder}/${Subject}/MNINonLinear/T1w_restore pixdim1`
StandardResolution=`printf "%0.2f" ${StandardResolution}`

#Needed for making the fibre connectivity file in Diffusion space
log_Msg "MakeTrajectorySpace"
${HCPPIPEDIR_dMRITract}/MakeTrajectorySpace.sh \
    --path="$StudyFolder" --subject="$Subject" \
    --wholebrainlabels="$WholeBrainTrajectoryLabels" \
    --leftcerebrallabels="$LeftCerebralTrajectoryLabels" \
    --rightcerebrallabels="$RightCerebralTrajectoryLabels" \
    --diffresol="${DiffusionResolution}" \
    --freesurferlabels="${FreeSurferLabels}"

log_Msg "MakeWorkbenchUODFs"
${HCPPIPEDIR_dMRITract}/MakeWorkbenchUODFs.sh --path="${StudyFolder}" --subject="${Subject}" --lowresmesh="${LowResMesh}" --diffresol="${DiffusionResolution}"


#Create lots of files in MNI space used in tractography
log_Msg "MakeTrajectorySpace_MNI"
${HCPPIPEDIR_dMRITract}/MakeTrajectorySpace_MNINHP.sh \
    --path="$StudyFolder" --subject="$Subject" \
    --wholebrainlabels="$WholeBrainTrajectoryLabels" \
    --leftcerebrallabels="$LeftCerebralTrajectoryLabels" \
    --rightcerebrallabels="$RightCerebralTrajectoryLabels" \
    --standresol="${StandardResolution}" \
    --freesurferlabels="${FreeSurferLabels}" \
    --lowresmesh="${LowResMesh}"

log_Msg "Completed"
