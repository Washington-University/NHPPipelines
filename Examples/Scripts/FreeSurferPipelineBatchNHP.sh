#!/bin/bash 
set -e
#Subjlist="M126 M128 M129 M131 M132" #Space delimited list of subject IDs
#StudyFolder="/media/myelin/brainmappers/Connectome_Project/InVivoMacaques" #Location of Subject folders (named by subjectID)
#EnvironmentScript="/media/2TBB/Connectome_Project/Pipelines/Examples/Scripts/SetUpHCPPipeline.sh" #Pipeline environment script

# Requirements for this script
#  installed versions of: FSL5.0.2 or higher , FreeSurfer (version 5.2 or higher) , gradunwarp (python code from MGH)
#  environment: FSLDIR , FREESURFER_HOME , HCPPIPEDIR , CARET7DIR , PATH (for gradient_unwarp.py)

usage () {
echo "Usage: $0 <StudyFolder> <SubjectID1@SubjectID2@SubjectID3...> <RunMode>"
echo "    Runmode: 0 - 8"
exit 1
}
[ "$1" = "" ] && usage

StudyFolder=$1
Subjlist=$2
RunMode=$3

#Set up pipeline environment variables and software
#. ${EnvironmentScript}

# Log the originating call
echo "$@"

#if [ X$SGE_ROOT != X ] ; then
#    QUEUE="-q long.q"
#fi

PRINTCOM=""
#PRINTCOM="echo"

########################################## INPUT




########################################## 

#Scripts called by this script do assume they run on the outputs of the PreFreeSurfer Pipeline

######################################### DO WORK ##########################################

for Subject in `echo $Subjlist | sed -e 's/@/ /g'` ; do

  #Input Variables
  SubjectID="$Subject" #FreeSurfer Subject ID Name
  SubjectDIR="${StudyFolder}/${Subject}/T1w" #Location to Put FreeSurfer Subject's Folder
  T1wImage="${StudyFolder}/${Subject}/T1w/T1w_acpc_dc_restore.nii.gz" #T1w FreeSurfer Input (Full Resolution)
  T1wImageBrain="${StudyFolder}/${Subject}/T1w/T1w_acpc_dc_restore_brain.nii.gz" #T1w FreeSurfer Input (Full Resolution)
  T2wImage="${StudyFolder}/${Subject}/T1w/T2w_acpc_dc_restore.nii.gz" #T2w FreeSurfer Input (Full Resolution)
  FSLinearTransform="${HCPPIPEDIR_Templates}/fs_xfms/eye.xfm" #Identity
  T2wFlag="${T2wFlag:=T2w}" # T2w, FLAIR or NONE. Default is T2w
  #GCAdir="${HCPPIPEDIR_Templates}/MacaqueYerkes19" #Template Dir with FreeSurfer NHP GCA and TIF files
  #RescaleVolumeTransform="${HCPPIPEDIR_Templates}/fs_xfms/Macaque_rescale" #Transforms to undo the effects of faking the dimensions to 1mm
  ############################################### Modified from here by Takuya Hayashi Nov 4th 2015 - Nov 2017.
  if [ -e "$SubjectDIR"/"$SubjectID"_1mm ] ; then
    if [ -e "$SubjectDIR"/"$SubjectID" ] ; then rm -r "$SubjectDIR"/"$SubjectID"; fi
    mv "$SubjectDIR"/"$SubjectID"_1mm "$SubjectDIR"/"$SubjectID"
  fi
  WmEdit="NONE";ControlPoints="NONE";AsegEdit="NONE";
  if [ "$RunMode" = "2" ] ; then

	if [ -e "$SubjectDIR"/"$SubjectID"/mri/brainmask.edit.mgz ] ; then
   		mkdir -p ${SubjectDIR}/${Subject}_edits
		cp "$SubjectDIR"/"$SubjectID"/mri/brainmask.edit.mgz "$SubjectDIR"/"$SubjectID"_edits/		
	fi

  elif [ "$RunMode" = "3" ] ; then

  	if [ -e ${SubjectDIR}/${Subject}/mri/aseg.edit.mgz ] ; then
   		mkdir -p ${SubjectDIR}/${Subject}_edits
   		mv ${SubjectDIR}/${Subject}/mri/aseg.edit.mgz ${SubjectDIR}/${Subject}_edits/;
   		AsegEdit="${SubjectDIR}/${Subject}_edits/aseg.edit.mgz"
      	else
		echo "WARNING: cannot find ${SubjectDIR}/${Subject}/mri/aseg.edit.mgz. About to run FSaseg";
       fi
   	if [ -e ${SubjectDIR}/${Subject}/mri/wm.edit.mgz ] ; then
   		mv ${SubjectDIR}/${Subject}/mri/wm.edit.mgz ${SubjectDIR}/${Subject}_edits/
   	fi
   	WmEdit="NONE"
   	ControlPoints="NONE"

  elif [ "$RunMode" = "4" ] ; then
  	if [ -e ${SubjectDIR}/${Subject}/tmp/control.dat ] ; then
   		mkdir -p ${SubjectDIR}/${Subject}_edits   
   		mv ${SubjectDIR}/${Subject}/tmp/control.dat ${SubjectDIR}/${Subject}_edits/
   		ControlPoints="${SubjectDIR}/${Subject}_edits/control.dat"
   		if [ -e ${SubjectDIR}/${Subject}/mri/wm.edit.mgz ] ; then
   			mv ${SubjectDIR}/${Subject}/mri/wm.edit.mgz ${SubjectDIR}/${Subject}_edits/
   		fi
  		AsegEdit="NONE"
   		WmEdit="NONE"
	else
		echo "WARNING: cannot find ${SubjectDIR}/${Subject}/tmp/control.dat. About to run FSnormalize2"; 
  	fi
  elif [ "$RunMode" = "5" ] ; then
  	if [ -e ${SubjectDIR}/${Subject}/mri/wm.edit.mgz ] ; then
   		mkdir -p ${SubjectDIR}/${Subject}_edits   
   		mv ${SubjectDIR}/${Subject}/mri/wm.edit.mgz ${SubjectDIR}/${Subject}_edits/;
   		WmEdit="${SubjectDIR}/${Subject}_edits/wm.edit.mgz"
   		ControlPoints="NONE"
   		AsegEdit="NONE"
	else
		echo "WARNING: cannot find ${SubjectDIR}/${Subject}/mri/wm.edit.mgz. About to run FSwhite"; 
  	fi
  fi
  Seed="1234"
  ############################################### Modified until here by Takuya Hayashi Nov 4th 2015.

     ${HCPPIPEDIR}/FreeSurfer/FreeSurferPipelineNHP.sh \
      --subject="$Subject" \
      --subjectDIR="$SubjectDIR" \
      --t1="$T1wImage" \
      --t1brain="$T1wImageBrain" \
      --t2="$T2wImage" \
      --fslinear="$FSLinearTransform" \
      --gcadir="$GCAdir" \
      --rescaletrans="$RescaleVolumeTransform" \
      --asegedit="$AsegEdit" \
      --controlpoints="$ControlPoints" \
      --wmedit="$WmEdit" \
      --t2wflag="$T2wFlag" \
      --species="$SPECIES" \
      --runmode="$RunMode" \
      --seed="$Seed" \
      --printcom="$PRINTCOM"
      
  # The following lines are used for interactive debugging to set the positional parameters: $1 $2 $3 ...

  echo "set -- --subject="$Subject" \
      --subjectDIR="$SubjectDIR" \
      --t1="$T1wImage" \
      --t1brain="$T1wImageBrain" \
      --t2="$T2wImage" \
      --fslinear="$FSLinearTransform" \
      --gcadir="$GCAdir" \
      --rescaletrans="$RescaleVolumeTransform" \
     --asegedit="$AsegEdit" \
      --controlpoints="$ControlPoints" \
      --wmedit="$WmEdit" \
      --t2wflag="$T2wFlag" \
      --species="$SPECIES" \
      --runmode="$RunMode" \
      --printcom=$PRINTCOM "

  echo ". ${EnvironmentScript}"

done

