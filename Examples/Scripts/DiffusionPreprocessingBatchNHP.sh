#!/bin/bash 

get_batch_options() {
    local arguments=($@)

    unset command_line_specified_study_folder
    unset command_line_specified_subj_list
    unset command_line_specified_run_local

    local index=0
    local numArgs=${#arguments[@]}
    local argument

    while [ ${index} -lt ${numArgs} ]; do
        argument=${arguments[index]}

        case ${argument} in
            --StudyFolder=*)
                command_line_specified_study_folder=${argument/*=/""}
                index=$(( index + 1 ))
                ;;
            --Subjlist=*)
                command_line_specified_subj_list=${argument/*=/""}
                index=$(( index + 1 ))
                ;;
            --runlocal)
                command_line_specified_run_local="TRUE"
                index=$(( index + 1 ))
                ;;
        esac
    done
}

get_batch_options $@

#StudyFolder="/mnt/FAI1/MRI/Human/HCP-RIKEN" #Location of Subject folders (named by subjectID)
#Subjlist="" #Space delimited list of subject IDs
EnvironmentScript="/mnt/FAI1/devel/NHPHCPPipeline/Examples/Scripts/SetUpHCPPipelineNHP.sh" #Pipeline environment script

if [ -n "${command_line_specified_study_folder}" ]; then
    StudyFolder="${command_line_specified_study_folder}"
fi

if [ -n "${command_line_specified_subj_list}" ]; then
    Subjlist="${command_line_specified_subj_list}"
fi

# Requirements for this script
#  installed versions of: FSL (version 5.0.6), FreeSurfer (version 5.3.0-HCP) , gradunwarp (HCP version 1.0.2)
#  environment: FSLDIR , FREESURFER_HOME , HCPPIPEDIR , CARET7DIR , PATH (for gradient_unwarp.py)

#Set up pipeline environment variables and software
. ${EnvironmentScript}

# Log the originating call
echo "$@"

#Assume that submission nodes have OPENMP enabled (needed for eddy - at least 8 cores suggested for HCP data)
#if [ X$SGE_ROOT != X ] ; then
#    QUEUE="-q verylong.q"
    QUEUE="-q hcp_priority.q"
#fi

PRINTCOM=""


########################################## INPUTS ########################################## 

#Scripts called by this script do assume they run on the outputs of the PreFreeSurfer Pipeline,
#which is a prerequisite for this pipeline

#Scripts called by this script do NOT assume anything about the form of the input names or paths.
#This batch script assumes the HCP raw data naming convention, e.g.

#	${StudyFolder}/${Subject}/unprocessed/3T/Diffusion/${SubjectID}_3T_DWI_dir95_RL.nii.gz
#	${StudyFolder}/${Subject}/unprocessed/3T/Diffusion/${SubjectID}_3T_DWI_dir96_RL.nii.gz
#	${StudyFolder}/${Subject}/unprocessed/3T/Diffusion/${SubjectID}_3T_DWI_dir97_RL.nii.gz
#	${StudyFolder}/${Subject}/unprocessed/3T/Diffusion/${SubjectID}_3T_DWI_dir95_LR.nii.gz
#	${StudyFolder}/${Subject}/unprocessed/3T/Diffusion/${SubjectID}_3T_DWI_dir96_LR.nii.gz
#	${StudyFolder}/${Subject}/unprocessed/3T/Diffusion/${SubjectID}_3T_DWI_dir97_LR.nii.gz

#Change Scan Settings: Echo Spacing and PEDir to match your images
#These are set to match the HCP Protocol by default

#If using gradient distortion correction, use the coefficents from your scanner
#The HCP gradient distortion coefficents are only available through Siemens
#Gradient distortion in standard scanners like the Trio is much less than for the HCP Skyra.

######################################### DO WORK ##########################################

for Subject in $Subjlist ; do
  echo $Subject

  #Input Variables
  SubjectID="$Subject" #Subject ID Name
  if [ -e ${StudyFolder}/${Subject}/RawData/hcppipe_conf.txt ] ; then
   . $StudyFolder/$SubjectID/RawData/hcppipe_conf.txt
  else
   echo "Cannot find hcppipe_conf.txt in ${SubjectID}/RawData";
   echo "Exiting without processing.";
   exit 1;
  fi
  # Data with positive Phase encoding direction. Up to N>=1 series (here N=3), separated by @. (RL in HCP data, PA in 7T HCP data)
  # PosData="${RawDataDir}/${SubjectID}_3T_DWI_dir95_RL.nii.gz@${RawDataDir}/${SubjectID}_3T_DWI_dir96_RL.nii.gz@${RawDataDir}/${SubjectID}_3T_DWI_dir97_RL.nii.gz"
  PosData=""
  for i in `echo $DmrilistPositive | sed -e 's/@/ /g'`; do
   PosData="`imglob -extension $StudyFolder/$SubjectID/RawData/${i}`@${PosData}"
  done
  NegData=""
  for i in `echo $DmrilistNegative | sed -e 's/@/ /g'` ; do
   NegData="`imglob -extension $StudyFolder/$SubjectID/RawData/${i}`@${NegData}"
  done
 
  # Data with negative Phase encoding direction. Up to N>=1 series (here N=3), separated by @. (LR in HCP data, AP in 7T HCP data)
  # If corresponding series is missing (e.g. 2 RL series and 1 LR) use EMPTY.
  #NegData="${RawDataDir}/${SubjectID}_3T_DWI_dir95_LR.nii.gz@${RawDataDir}/${SubjectID}_3T_DWI_dir96_LR.nii.gz@${RawDataDir}/${SubjectID}_3T_DWI_dir97_LR.nii.gz"

  #Scan Setings
  #EchoSpacing=0.78 #Echo Spacing or Dwelltime of dMRI image, set to NONE if not used. Dwelltime = 1/(BandwidthPerPixelPhaseEncode * # of phase encoding samples): DICOM field (0019,1028) = BandwidthPerPixelPhaseEncode, DICOM field (0051,100b) AcquisitionMatrixText first value (# of phase encoding samples).  On Siemens, iPAT/GRAPPA factors have already been accounted for.
  #PEdir=1 #Use 1 for Left-Right Phase Encoding, 2 for Anterior-Posterior

  #Config Settings
  # Gdcoeffs="${HCPPIPEDIR_Config}/coeff_SC72C_Skyra.grad" #Coefficients that describe spatial variations of the scanner gradients. Use NONE if not available.
  Gdcoeffs="NONE" # Set to NONE to skip gradient distortion correction

  if [ -n "${command_line_specified_run_local}" ] ; then
      echo "About to run ${HCPPIPEDIR}/DiffusionPreprocessing/DiffPreprocPipeline.sh"
      queuing_command=""
  else
      echo "About to use fsl_sub to queue or run ${HCPPIPEDIR}/DiffusionPreprocessing/DiffPreprocPipeline.sh"
      queuing_command="${FSLDIR}/bin/fsl_sub ${QUEUE}"
  fi

  # Added --cnr_maps for RIKEN
  # Added --combine-data-flag for RIKEN

  ${HCPPIPEDIR}/DiffusionPreprocessing/DiffPreprocPipelineNHP.sh \
      --posData="${PosData}" --negData="${NegData}" \
      --path="${StudyFolder}" --subject="${SubjectID}" \
      --echospacing="${EchoSpacing}" --PEdir=${PEdir} \
      --gdcoeffs="${Gdcoeffs}" \
      --extra-eddy-arg="--cnr_maps" \
      --combine-data-flag="2" \
      --printcom=$PRINTCOM

done

