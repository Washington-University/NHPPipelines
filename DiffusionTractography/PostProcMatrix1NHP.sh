#!/bin/bash
set -e
echo -e "\n START: PostProcMatrix1"

Caret7_command=${CARET7DIR}/wb_command

if [ "$4" == "" ];then
    echo ""
    echo "usage: $0 <StudyFolder> <Subject> <GrayOrdinates_Templatedir> <OutFileName> [-l]"
    echo "Converts the merged.dot file to .dconn.nii"
    echo "Option -l calculates both conn and length" 
    echo ""
    exit 1
fi

StudyFolder=$1          # "$1" #Path to Generic Study folder
Subject=$2              # "$2" #SubjectID
TemplateFolder=$3
OutFileName=$4             # How many dot files existed
if [ "$5" != "-l" ] ; then
	lengths=0
else
	lengths=1
fi

ResultsFolder="${StudyFolder}"/"${Subject}"/MNINonLinear/Results/Tractography

Mat1Conn () {
#${Caret7_command} -probtrackx-dot-convert ${ResultsFolder}/merged_matrix1.dot ${ResultsFolder}/Mat1.dconn.nii -row-cifti ${TemplateFolder}/91282_Greyordinates.dscalar.nii COLUMN -col-cifti ${TemplateFolder}/91282_Greyordinates.dscalar.nii COLUMN
#${Caret7_command} -probtrackx-dot-convert ${ResultsFolder}/merged_matrix1.dot ${ResultsFolder}/Mat1.dconn.nii -row-cifti ${ResultsFolder}/Atlas_Greyordinates.dscalar.nii COLUMN -col-cifti ${ResultsFolder}/Atlas_Greyordinates.dscalar.nii COLUMN
${Caret7_command} -probtrackx-dot-convert ${ResultsFolder}/fdt_matrix1.dot ${ResultsFolder}/Mat1.dconn.nii -row-cifti ${ResultsFolder}/Atlas_Greyordinates.dscalar.nii COLUMN -col-cifti ${ResultsFolder}/Atlas_Greyordinates.dscalar.nii COLUMN
${Caret7_command} -cifti-transpose ${ResultsFolder}/Mat1.dconn.nii ${ResultsFolder}/Mat1_transp.dconn.nii
${Caret7_command} -cifti-average ${ResultsFolder}/${OutFileName} -cifti ${ResultsFolder}/Mat1.dconn.nii -cifti ${ResultsFolder}/Mat1_transp.dconn.nii
if [ -s  $ResultsFolder/Conn1.dconn.nii ]; then
    rm -f ${ResultsFolder}/Mat1.dconn.nii
    rm -f ${ResultsFolder}/Mat1_transp.dconn.nii
    #rm -f ${ResultsFolder}/fdt_matrix1.dot
fi  

##Create RowSum of dconn to check gyral bias
OutFileTemp=`echo ${OutFileName//".dconn.nii"/""}`
${Caret7_command} -cifti-reduce ${ResultsFolder}/${OutFileName} SUM  ${ResultsFolder}/${OutFileTemp}_sum.dscalar.nii
mv $ResultsFolder/waytotal $ResultsFolder/${OutFileTemp}_waytotal

#gzip $ResultsFolder/${OutFileName} --fast
}

Mat1Lengths () {

${Caret7_command} -probtrackx-dot-convert ${ResultsFolder}/fdt_matrix1_lengths.dot ${ResultsFolder}/Mat1_lengths.dconn.nii -row-cifti ${ResultsFolder}/Atlas_Greyordinates.dscalar.nii COLUMN -col-cifti ${ResultsFolder}/Atlas_Greyordinates.dscalar.nii COLUMN
${Caret7_command} -cifti-transpose ${ResultsFolder}/Mat1_lengths.dconn.nii ${ResultsFolder}/Mat1_lengths_transp.dconn.nii

OutFileTemp=`echo ${OutFileName//".dconn.nii"/""}`
${Caret7_command} -cifti-average ${ResultsFolder}/${OutFileTemp}_lengths.dconn.nii -cifti ${ResultsFolder}/Mat1_lengths.dconn.nii -cifti ${ResultsFolder}/Mat1_lengths_transp.dconn.nii
if [ -s  $ResultsFolder/Conn1_lengths.dconn.nii ]; then
    rm -f ${ResultsFolder}/Mat1_lengths.dconn.nii
    rm -f ${ResultsFolder}/Mat1_lengths_transp.dconn.nii
    #rm -f ${ResultsFolder}/fdt_matrix1_lengths.dot 
fi

}

main () {
if [ $lengths != 1 ] ; then
	Mat1Conn
else
	Mat1Conn	
	Mat1Lengths
fi
}

main

echo -e "\n END: PostProcMatrix1"
