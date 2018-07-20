#!/bin/bash

bindir=/home/moises/ptx2
scriptsdir=/home/moises/Tractography_gpu_scripts
Caret7_command=/home/stam/workbench_rh_linux64_latest/bin_rh_linux64/wb_command

if [ "$4" == "" ];then
    echo ""
    echo "usage: $0 <StudyFolder> <Subject> <GrayOrdinates_Templatedir> <OutFileName>"
    echo "Convert the merged.dot file to .dconn.nii"
    exit 1
fi

StudyFolder=$1          # "$1" #Path to Generic Study folder
Subject=$2              # "$2" #SubjectID
TemplateFolder=$3
OutFileName=$4

ResultsFolder="$StudyFolder"/"$Subject"/MNINonLinear/Results/Tractography

${Caret7_command} -probtrackx-dot-convert ${ResultsFolder}/fdt_matrix1.dot ${ResultsFolder}/Mat1.dconn.nii -row-cifti ${TemplateFolder}/91282_Greyordinates.dscalar.nii COLUMN -col-cifti ${TemplateFolder}/91282_Greyordinates.dscalar.nii COLUMN
${Caret7_command} -cifti-transpose ${ResultsFolder}/Mat1.dconn.nii ${ResultsFolder}/Mat1_transp.dconn.nii
${Caret7_command} -cifti-average ${ResultsFolder}/${OutFileName} -cifti ${ResultsFolder}/Mat1.dconn.nii -cifti ${ResultsFolder}/Mat1_transp.dconn.nii

if [ -s  $ResultsFolder/${OutFileName} ]; then
   rm -f ${ResultsFolder}/Mat1.dconn.nii
   rm -f ${ResultsFolder}/Mat1_transp.dconn.nii
   rm -f ${ResultsFolder}/fdt_matrix1.dot
fi  

##Create RowSum of dconn to check gyral bias
OutFileTemp=`echo ${OutFileName//".dconn.nii"/""}`
${Caret7_command} -cifti-reduce ${ResultsFolder}/${OutFileName} SUM  ${ResultsFolder}/${OutFileTemp}_sum.dscalar.nii
mv $ResultsFolder/waytotal $ResultsFolder/${OutFileTemp}_waytotal

gzip $ResultsFolder/${OutFileName} --fast
