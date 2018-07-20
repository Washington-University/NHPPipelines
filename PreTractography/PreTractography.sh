#!/bin/bash

scriptsdir=/HCP/scratch/diffusion/Tractography_scripts_03_12_13/PreTractography_14

if [ "$3" == "" ];then
    echo ""
    echo "usage: $0 <StudyFolder> <Subject> <MSMflag>"
    echo "       T1w and MNINonLinear folders are expected within <StudyFolder>/<Subject>"
    echo "       MSMflag=0 uses the default surfaces, MSMflag=1 uses the MSM surfaces defined in MakeTrajectorySpace_MNI.sh" 
    echo ""
    exit 1
fi

StudyFolder=$1
Subject=$2  
MSMflag=$3

WholeBrainTrajectoryLabels=${scriptsdir}/config/WholeBrainFreeSurferTrajectoryLabelTableLut.txt
LeftCerebralTrajectoryLabels=${scriptsdir}/config/LeftCerebralFreeSurferTrajectoryLabelTableLut.txt 
RightCerebralTrajectoryLabels=${scriptsdir}/config/RightCerebralFreeSurferTrajectoryLabelTableLut.txt
FreeSurferLabels=${scriptsdir}/config/FreeSurferAllLut.txt


T1wDiffusionFolder="${StudyFolder}/${Subject}/T1w/Diffusion"
DiffusionResolution=`${FSLDIR}/bin/fslval ${T1wDiffusionFolder}/data pixdim1`
DiffusionResolution=`printf "%0.2f" ${DiffusionResolution}`
LowResMesh=32
StandardResolution="2"

#Needed for making the fibre connectivity file in Diffusion space
${scriptsdir}/MakeTrajectorySpace.sh \
    --path="$StudyFolder" --subject="$Subject" \
    --wholebrainlabels="$WholeBrainTrajectoryLabels" \
    --leftcerebrallabels="$LeftCerebralTrajectoryLabels" \
    --rightcerebrallabels="$RightCerebralTrajectoryLabels" \
   --diffresol="${DiffusionResolution}" \
    --freesurferlabels="${FreeSurferLabels}"

${scriptsdir}/MakeWorkbenchUODFs.sh --path="${StudyFolder}" --subject="${Subject}" --lowresmesh="${LowResMesh}" --diffresol="${DiffusionResolution}"


#Create lots of files in MNI space used in tractography
${scriptsdir}/MakeTrajectorySpace_MNI.sh \
    --path="$StudyFolder" --subject="$Subject" \
    --wholebrainlabels="$WholeBrainTrajectoryLabels" \
    --leftcerebrallabels="$LeftCerebralTrajectoryLabels" \
    --rightcerebrallabels="$RightCerebralTrajectoryLabels" \
    --standresol="${StandardResolution}" \
    --freesurferlabels="${FreeSurferLabels}" \
    --lowresmesh="${LowResMesh}" \
    --msmflag="${MSMflag}"

