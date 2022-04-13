#!/bin/bash 
#~ND~FORMAT~MARKDOWN~
#~ND~START~
#
# # PreFreeSurferPipeline.sh
#
# ## Copyright Notice
#
# Copyright (C) 2013-2014 The Human Connectome Project
#
# * Washington University in St. Louis
# * University of Minnesota
# * Oxford University
#
# ## Author(s)
#
# * Matthew F. Glasser, Department of Anatomy and Neurobiology, Washington University in St. Louis
# * Mark Jenkinson, FMRIB Centre, Oxford University
# * Timothy B. Brown, Neuroinformatics Research Group, Washington University in St. Louis
# * Modifications to support General Electric Gradient Echo field maps for readout distortion correction
#   are based on example code provided by Gaurav Patel, Columbia University
#
# ## Product
#
# [Human Connectome Project][HCP] (HCP) Pipelines
#
# ## License
#
# See the [LICENSE](https://github.com/Washington-University/Pipelines/blob/master/LICENSE.md) file
#
# ## Description
#
# This script, PreFreeSurferPipeline.sh, is the first of 3 sub-parts of the
# Structural Preprocessing phase of the [HCP][HCP] Minimal Preprocessing Pipelines.
#
# See [Glasser et al. 2013][GlasserEtAl].
#
# This script implements the PreFreeSurfer Pipeline referred to in that publication.
#
# The primary purposes of the PreFreeSurfer Pipeline are:
#
# 1. To average any image repeats (i.e. multiple T1w or T2w images available)
# 2. To create a native, undistorted structural volume space for the subject
#    * Subject images in this native space will be distortion corrected
#      for gradient and b0 distortions and rigidly aligned to the axes
#      of the MNI space. "Native, undistorted structural volume space"
#      is sometimes shortened to the "subject's native space" or simply
#      "native space".
# 3. To provide an initial robust brain extraction
# 4. To align the T1w and T2w structural images (register them to the native space)
# 5. To perform bias field correction
# 6. To register the subject's native space to the MNI space
#
# ## Prerequisites:
#
# ### Installed Software
#
# * [FSL][FSL] - FMRIB's Software Library (version 5.0.6)
#
# ### Environment Variables
#
# * HCPPIPEDIR
#
#   The "home" directory for the version of the HCP Pipeline Tools product
#   being used. E.g. /nrgpackages/tools.release/hcp-pipeline-tools-V3.0
#
# * HCPPIPEDIR_Global
#
#   Location of shared sub-scripts that are used to carry out some of the
#   steps of the PreFreeSurfer pipeline and are also used to carry out
#   some steps of other pipelines.
#
# * FSLDIR
#
#   Home directory for [FSL][FSL] the FMRIB Software Library from Oxford
#   University
#
# ### Image Files
#
# At least one T1 weighted image and one T2 weighted image are required
# for this script to work.
#
# ### Output Directories
#
# Command line arguments are used to specify the StudyFolder (--path) and
# the Subject (--subject).  All outputs are generated within the tree rooted
# at ${StudyFolder}/${Subject}.  The main output directories are:
#
# * The T1wFolder: ${StudyFolder}/${Subject}/T1w
# * The T2wFolder: ${StudyFolder}/${Subject}/T2w
# * The AtlasSpaceFolder: ${StudyFolder}/${Subject}/MNINonLinear
#
# All outputs are generated in directories at or below these three main
# output directories.  The full list of output directories is:
#
# * ${T1wFolder}/T1w${i}_GradientDistortionUnwarp
# * ${T1wFolder}/AverageT1wImages
# * ${T1wFolder}/ACPCAlignment
# * ${T1wFolder}/BrainExtraction_FNIRTbased
# * ${T1wFolder}/xfms - transformation matrices and warp fields
#
# * ${T2wFolder}/T2w${i}_GradientDistortionUnwarp
# * ${T2wFolder}/AverageT1wImages
# * ${T2wFolder}/ACPCAlignment
# * ${T2wFolder}/BrainExtraction_FNIRTbased
# * ${T2wFolder}/xfms - transformation matrices and warp fields
#
# * ${T2wFolder}/T2wToT1wDistortionCorrectAndReg
# * ${T1wFolder}/BiasFieldCorrection_sqrtT1wXT2w
#
# * ${AtlasSpaceFolder}
# * ${AtlasSpaceFolder}/xfms
#
# Note that no assumptions are made about the input paths with respect to the
# output directories. All specification of input files is done via command
# line arguments specified when this script is invoked.
#
# Also note that the following output directories are created:
#
# * T1wFolder, which is created by concatenating the following three option
#   values: --path / --subject / --t1
# * T2wFolder, which is created by concatenating the following three option
#   values: --path / --subject / --t2
#
# These two output directories must be different. Otherwise, various output
# files with standard names contained in such subdirectories, e.g.
# full2std.mat, would overwrite each other).  If this script is modified,
# then those two output directories must be kept distinct.
#
# ### Output Files
#
# * T1wFolder Contents: TODO
# * T2wFolder Contents: TODO
# * AtlasSpaceFolder Contents: TODO
#
# <!-- References -->
# [HCP]: http://www.humanconnectome.org
# [GlasserEtAl]: http://www.ncbi.nlm.nih.gov/pubmed/23668970
# [FSL]: http://fsl.fmrib.ox.ac.uk
#
#~ND~END~

# ------------------------------------------------------------------------------
#  Code Start
# ------------------------------------------------------------------------------

# -----------------------------------------------------------------------------------
#  Constants for specification of Averaging and Readout Distortion Correction Method
# -----------------------------------------------------------------------------------

NONE_METHOD_OPT="NONE"
FIELDMAP_METHOD_OPT="FIELDMAP"
SIEMENS_METHOD_OPT="SiemensFieldMap"
SPIN_ECHO_METHOD_OPT="TOPUP"
GENERAL_ELECTRIC_METHOD_OPT="GeneralElectricFieldMap"
PHILIPS_METHOD_OPT="PhilipsFieldMap"

# ------------------------------------------------------------------------------
#  Usage Description Function
# ------------------------------------------------------------------------------

script_name=$(basename "${0}")

show_usage() {
  cat <<EOF

${script_name}

Usage: ${script_name} [options]

  --path=<path>                       Path to study data folder (required)
                                      Used with --subject input to create full path to root
                                      directory for all outputs generated as path/subject
  --subject=<subject>                 Subject ID (required)
                                      Used with --path input to create full path to root
                                      directory for all outputs generated as path/subject
  --t1=<T1w images>                   An @ symbol separated list of full paths to T1-weighted
                                      (T1w) structural images for the subject (required)
  --t2=<T2w images>                   An @ symbol separated list of full paths to T2-weighted
                                      (T2w) structural images for the subject (required for 
                                      hcp-style data, can be NONE for legacy-style data, 
                                      see --processing-mode option)
  --t1template=<file path>            MNI T1w template
  --t1templatebrain=<file path>       Brain extracted MNI T1wTemplate
  --t1template2mm=<file path>         MNI 2mm T1wTemplate
  --t2template=<file path>            MNI T2w template
  --t2templatebrain=<file path>       Brain extracted MNI T2wTemplate
  --t2template2mm=<file path>         MNI 2mm T2wTemplate
  --templatemask=<file path>          Brain mask MNI Template
  --template2mmmask=<file path>       Brain mask MNI 2mm Template
  --brainsize=<size value>            Brain size estimate in mm, 150 for humans
  --fnirtconfig=<file path>           FNIRT 2mm T1w Configuration file
  --fmapmag=<file path>               Siemens/Philips Gradient Echo Fieldmap magnitude file
  --fmapphase=<file path>             Siemens/Philips Gradient Echo Fieldmap phase file
  --fmapgeneralelectric=<file path>   General Electric Gradient Echo Field Map file
                                      Two volumes in one file
                                      1. field map in deg
                                      2. magnitude
  --echodiff=<delta TE>               Delta TE in ms for field map or "NONE" if
                                      not used
  --SEPhaseNeg={<file path>, NONE}    For spin echo field map, path to volume with
                                      a negative phase encoding direction (LR in
                                      HCP data), set to "NONE" if not using Spin
                                      Echo Field Maps
  --SEPhasePos={<file path>, NONE}    For spin echo field map, path to volume with
                                      a positive phase encoding direction (RL in
                                      HCP data), set to "NONE" if not using Spin
                                      Echo Field Maps
  --seechospacing=<seconds>           Effective Echo Spacing of Spin Echo Field Map,
                                      (in seconds) or "NONE" if not used
  --seunwarpdir={x,y,NONE}            Phase encoding direction (according to the *voxel* axes)
             or={i,j,NONE}            of the spin echo field map. 
                                      (Only applies when using a spin echo field map.)
  --t1samplespacing=<seconds>         T1 image sample spacing, "NONE" if not used
  --t2samplespacing=<seconds>         T2 image sample spacing, "NONE" if not used
  --unwarpdir={x,y,z,x-,y-,z-}        Readout direction of the T1w and T2w images (according to the *voxel axes)
           or={i,j,k,i-,j-,k-}        (Used with either a gradient echo field map 
                                      or a spin echo field map)
  --gdcoeffs=<file path>              File containing gradient distortion
                                      coefficients, Set to "NONE" to turn off
  --avgrdcmethod=<avgrdcmethod>       Averaging and readout distortion correction method. 
                                      See below for supported values.

      "${NONE_METHOD_OPT}"
         average any repeats with no readout distortion correction

      "${SPIN_ECHO_METHOD_OPT}"
         average any repeats and use Spin Echo Field Maps for readout
         distortion correction

      "${PHILIPS_METHOD_OPT}"
         average any repeats and use Philips specific Gradient Echo
         Field Maps for readout distortion correction

      "${GENERAL_ELECTRIC_METHOD_OPT}"
         average any repeats and use General Electric specific Gradient
         Echo Field Maps for readout distortion correction

      "${SIEMENS_METHOD_OPT}"
         average any repeats and use Siemens specific Gradient Echo
         Field Maps for readout distortion correction

      "${FIELDMAP_METHOD_OPT}"
         equivalent to "${SIEMENS_METHOD_OPT}" (preferred)
         This option value is maintained for backward compatibility.

  --topupconfig=<file path>           Configuration file for topup or "NONE" if not used
  [--bfsigma=<value>]                 Bias Field Smoothing Sigma (optional)
  [--custombrain=(NONE|MASK|CUSTOM)]  If PreFreeSurfer has been run before and you have created a custom
                                      brain mask saved as "<subject>/T1w/custom_acpc_dc_restore_mask.nii.gz", specify "MASK". 
                                      If PreFreeSurfer has been run before and you have created custom structural images, e.g.: 
                                      - "<subject>/T1w/T1w_acpc_dc_restore_brain.nii.gz"
                                      - "<subject>/T1w/T1w_acpc_dc_restore.nii.gz"
                                      - "<subject>/T1w/T2w_acpc_dc_restore_brain.nii.gz"
                                      - "<subject>/T1w/T2w_acpc_dc_restore.nii.gz"
                                      to be used when peforming MNI152 Atlas registration, specify "CUSTOM".
                                      When "MASK" or "CUSTOM" is specified, only the AtlasRegistration step is run.
                                      If the parameter is omitted or set to NONE (the default), 
                                      standard image processing will take place.
                                      If using "MASK" or "CUSTOM", the data still needs to be staged properly by 
                                      running FreeSurfer and PostFreeSurfer afterwards.
                                      NOTE: This option allows manual correction of brain images in cases when they
                                      were not successfully processed and/or masked by the regular use of the pipelines.
                                      Before using this option, first ensure that the pipeline arguments used were 
                                      correct and that templates are a good match to the data.
  [--processing-mode=(HCPStyleData|   Controls whether the HCP acquisition and processing guidelines should be treated as requirements.
               LegacyStyleData)]      "HCPStyleData" (the default) follows the processing steps described in Glasser et al. (2013) 
                                         and requires 'HCP-Style' data acquistion. 
                                      "LegacyStyleData" allows additional processing functionality and use of some acquisitions
                                         that do not conform to 'HCP-Style' expectations.
                                         In this script, it allows not having a high-resolution T2w image.

EOF
}

# Allow script to return a Usage statement, before any other output or checking
if [ "$#" = "0" ]; then
    show_usage
    exit 1
fi

# ------------------------------------------------------------------------------
#  Check that HCPPIPEDIR is defined and Load Function Libraries
# ------------------------------------------------------------------------------

if [ -z "${HCPPIPEDIR}" ]; then
  echo "${script_name}: ABORTING: HCPPIPEDIR environment variable must be set"
  exit 1
fi

source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"         # Debugging functions; also sources log.shlib
source ${HCPPIPEDIR}/global/scripts/opts.shlib                 # Command line option functions
source ${HCPPIPEDIR}/global/scripts/processingmodecheck.shlib  # Check processing mode requirements

opts_ShowVersionIfRequested $@
########################################## OUTPUT DIRECTORIES ########################################## 

## NB: NO assumption is made about the input paths with respect to the output directories - they can be totally different.  All input are taken directly from the input variables without additions or modifications.

# NB: Output directories T1wFolder and T2wFolder MUST be different (as various output subdirectories containing standardly named files, e.g. full2std.mat, would overwrite each other) so if this script is modified, then keep these output directories distinct


# Output path specifiers:
#
# ${StudyFolder} is an input parameter
# ${Subject} is an input parameter

# Main output directories
# T1wFolder=${StudyFolder}/${Subject}/T1w
# T2wFolder=${StudyFolder}/${Subject}/T2w
# AtlasSpaceFolder=${StudyFolder}/${Subject}/MNINonLinear

# All outputs are within the directory: ${StudyFolder}/${Subject}
# The list of output directories are the following

#    T1w/T1w${i}_GradientDistortionUnwarp
#    T1w/AverageT1wImages
#    T1w/ACPCAlignment
#    T1w/BrainExtraction_FNIRTbased
# and the above for T2w as well (s/T1w/T2w/g)

#    T2w/T2wToT1wDistortionCorrectAndReg
#    T1w/BiasFieldCorrection_sqrtT1wXT1w 
#    MNINonLinear

StudyFolder=`opts_GetOpt1 "--path" $@`
Subject=`opts_GetOpt1 "--subject" $@`
T1wInputImages=`opts_GetOpt1 "--t1" $@`
T2wInputImages=`opts_GetOpt1 "--t2" $@`
T1wTemplate=`opts_GetOpt1 "--t1template" $@`
T1wTemplateBrain=`opts_GetOpt1 "--t1templatebrain" $@`
T1wTemplate2mm=`opts_GetOpt1 "--t1template2mm" $@`
T2wTemplate=`opts_GetOpt1 "--t2template" $@`
T2wTemplateBrain=`opts_GetOpt1 "--t2templatebrain" $@`  # This file/argument not used anywhere
T2wTemplate2mm=`opts_GetOpt1 "--t2template2mm" $@`
TemplateMask=`opts_GetOpt1 "--templatemask" $@`
Template2mmMask=`opts_GetOpt1 "--template2mmmask" $@`
BrainSize=`opts_GetOpt1 "--brainsize" $@`
FNIRTConfig=`opts_GetOpt1 "--fnirtconfig" $@`
MagnitudeInputName=`opts_GetOpt1 "--fmapmag" $@`
PhaseInputName=`opts_GetOpt1 "--fmapphase" $@`
GEB0InputName=`opts_GetOpt1 "--fmapgeneralelectric" $@`
TE=`opts_GetOpt1 "--echodiff" $@`
SpinEchoPhaseEncodeNegative=`opts_GetOpt1 "--SEPhaseNeg" $@`
SpinEchoPhaseEncodePositive=`opts_GetOpt1 "--SEPhasePos" $@`
DwellTime=`getopt1 "--echospacing" $@`
SEUnwarpDir=`opts_GetOpt1 "--seunwarpdir" $@`
T1wSampleSpacing=`opts_GetOpt1 "--t1samplespacing" $@`
T2wSampleSpacing=`opts_GetOpt1 "--t2samplespacing" $@`
UnwarpDir=`opts_GetOpt1 "--unwarpdir" $@`
GradientDistortionCoeffs=`opts_GetOpt1 "--gdcoeffs" $@`
AvgrdcSTRING=`opts_GetOpt1 "--avgrdcmethod" $@`
TopupConfig=`opts_GetOpt1 "--topupconfig" $@`
BiasFieldSmoothingSigma=`opts_GetOpt1 "--bfsigma" $@`
RUN=`getopt1 "--printcom" $@`  # use ="echo" for just printing everything and not running the commands (default is to run)
IdentMat=`getopt1 "--identmat" $@` # Do regisration in ACPCAlignment, T2wToT1Reg and AtlasRegistration (NONE) or not (TRUE)
BrainExtractionFnirtBased=`opts_GetOpt1 "--brainextractionfnirt" $@`   # TRUE or NONE, added by Takuya Hayashi 2016/06/18
Defacing=`getopt1 "--defacing" $@`   # TRUE or NONE by TH Jan 2020

log_Msg "StudyFolder: $StudyFolder"
log_Msg "Subject:  $Subject"

########################################## SUPPORT FUNCTIONS ########################################## 

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

# --------------------------------------------------------------------------------
#  Load Function Libraries
# --------------------------------------------------------------------------------

source $HCPPIPEDIR/global/scripts/log.shlib  # Logging related functions
source $HCPPIPEDIR/global/scripts/opts.shlib # Command line option functions

################################################## OPTION PARSING #####################################################

# ------------------------------------------------------------------------------
#  Show Command Line Options
# ------------------------------------------------------------------------------

# Input Variables
StudyFolder=`getopt1 "--path" $@`  # "$1" #Path to subject's data folder
Subject=`getopt1 "--subject" $@`  # "$2" #SubjectID
T1wInputImages=`getopt1 "--t1" $@`  # "$3" #T1w1@T1w2@etc..
T2wInputImages=`getopt1 "--t2" $@`  # "$4" #T2w1@T2w2@etc..
T1wTemplate=`getopt1 "--t1template" $@`  # "$5" #MNI template
T1wTemplateBrain=`getopt1 "--t1templatebrain" $@`  # "$6" #Brain extracted MNI T1wTemphostlate
T1wTemplate2mm=`getopt1 "--t1template2mm" $@`  # "$7" #MNI2mm T1wTemplate
T2wTemplate=`getopt1 "--t2template" $@`  # "${8}" #MNI T2wTemplate
T2wTemplateBrain=`getopt1 "--t2templatebrain" $@`  # "$9" #Brain extracted MNI T2wTemplate
T2wTemplate2mm=`getopt1 "--t2template2mm" $@`  # "${10}" #MNI2mm T2wTemplate
TemplateMask=`getopt1 "--templatemask" $@`  # "${11}" #Brain mask MNI Template
Template2mmMask=`getopt1 "--template2mmmask" $@`  # "${12}" #Brain mask MNI2mm Template 
BrainSize=`getopt1 "--brainsize" $@`  # "${13}" #StandardFOV mask for averaging structurals
FNIRTConfig=`getopt1 "--fnirtconfig" $@`  # "${14}" #FNIRT 2mm T1w Config
MagnitudeInputName=`getopt1 "--fmapmag" $@`  # "${16}" #Expects 4D magitude volume with two 3D timepoints
PhaseInputName=`getopt1 "--fmapphase" $@`  # "${17}" #Expects 3D phase difference volume
TE=`getopt1 "--echodiff" $@`  # "${18}" #delta TE for field map
SpinEchoPhaseEncodeNegative=`getopt1 "--SEPhaseNeg" $@`
SpinEchoPhaseEncodePositive=`getopt1 "--SEPhasePos" $@`
DwellTime=`getopt1 "--echospacing" $@`
SEUnwarpDir=`getopt1 "--seunwarpdir" $@`
T1wSampleSpacing=`getopt1 "--t1samplespacing" $@`  # "${19}" #DICOM field (0019,1018)
T2wSampleSpacing=`getopt1 "--t2samplespacing" $@`  # "${20}" #DICOM field (0019,1018) 
UnwarpDir=`getopt1 "--unwarpdir" $@`  # "${21}" #z appears to be best
GradientDistortionCoeffs=`getopt1 "--gdcoeffs" $@`  # "${25}" #Select correct coeffs for scanner or "NONE" to turn off
AvgrdcSTRING=`getopt1 "--avgrdcmethod" $@`  # "${26}" #Averaging and readout distortion correction methods: "NONE" = average any repeats with no readout correction "FIELDMAP" = average any repeats and use field map for readout correction "TOPUP" = average and distortion correct at the same time with topup/applytopup only works for 2 images currently
TopupConfig=`getopt1 "--topupconfig" $@`  # "${27}" #Config for topup or "NONE" if not used
BiasFieldSmoothingSigma=`getopt1 "--bfsigma" $@`  # "$9"
RUN=`getopt1 "--printcom" $@`  # use ="echo" for just printing everything and not running the commands (default is to run)
IdentMat=`getopt1 "--identmat" $@` # Do regisration in ACPCAlignment, T2wToT1Reg and AtlasRegistration (NONE) or not (TRUE)
BrainExtractionFnirtBased=`getopt1 "--brainextractionfnirt" $@`   # TRUE or NONE, added by Takuya Hayashi 2016/06/18
Defacing=`getopt1 "--defacing" $@`   # TRUE or NONE by TH Jan 2020

log_Msg "StudyFolder: $StudyFolder"
log_Msg "Subject:  $Subject"

# Paths for scripts etc (uses variables defined in SetUpHCPPipeline.sh)
PipelineScripts=${HCPPIPEDIR_PreFS}
GlobalScripts=${HCPPIPEDIR_Global}

# Naming Conventions
T1wImage="T1w"
T1wFolder="T1w" #Location of T1w images
T2wImage="T2w" 
T2wFolder="T2w" #Location of T2w images
AtlasSpaceFolder="MNINonLinear"

# Build Paths
T1wFolder=${StudyFolder}/${Subject}/${T1wFolder} 
T2wFolder=${StudyFolder}/${Subject}/${T2wFolder} 
AtlasSpaceFolder=${StudyFolder}/${Subject}/${AtlasSpaceFolder}

log_Msg "T1wFolder: $T1wFolder"
log_Msg "T2wFolder: $T2wFolder"
log_Msg "AtlasFolder: $AtlasSpaceFolder"

# Unpack List of Images
T1wInputImages=`echo ${T1wInputImages} | sed 's/@/ /g'`
T2wInputImages=`echo ${T2wInputImages} | sed 's/@/ /g'`

log_Msg "T1wInputImages: $T1wInputImages"
log_Msg "T2wInputImages: $T2wInputImages"

# -- Are T2w images available

if [ "${T2wInputImages}" = "NONE" ] ; then
  T2wFolder="NONE"
  T2wFolder_T2wImageWithPath_acpc="NONE"
  T2wFolder_T2wImageWithPath_acpc_brain="NONE"
  T1wFolder_T2wImageWithPath_acpc_dc="NONE"
else
  T2wFolder_T2wImageWithPath_acpc="${T2wFolder}/${T2wImage}_acpc"
  T2wFolder_T2wImageWithPath_acpc_brain="${T2wFolder}/${T2wImage}_acpc_brain"
  T1wFolder_T2wImageWithPath_acpc_dc=${T1wFolder}/${T2wImage}_acpc_dc
fi

if [ ! -e ${T1wFolder}/xfms ] ; then
  log_Msg "mkdir -p ${T1wFolder}/xfms/"
  mkdir -p ${T1wFolder}/xfms/
fi

if [ ! -e ${T2wFolder}/xfms ] && [ ${T2wFolder} != "NONE" ] ; then
  log_Msg "mkdir -p ${T2wFolder}/xfms/"
  mkdir -p ${T2wFolder}/xfms/
fi

if [ ! -e ${AtlasSpaceFolder}/xfms ] ; then
  log_Msg "mkdir -p ${AtlasSpaceFolder}/xfms/"
  mkdir -p ${AtlasSpaceFolder}/xfms/
fi

log_Msg "POSIXLY_CORRECT="${POSIXLY_CORRECT}


########################################## DO WORK ########################################## 

######## LOOP over the same processing for T1w and T2w (just with different names) ########

Modalities="T1w T2w"

for TXw in ${Modalities} ; do

    # set up appropriate input variables
    if [ $TXw = T1w ] ; then
	TXwInputImages="${T1wInputImages}"
	TXwFolder=${T1wFolder}
	TXwImage=${T1wImage}
	TXwTemplate=${T1wTemplate}
	TXwTemplate2mm=${T1wTemplate2mm}
	TXwTemplateBrain=${T1wTemplateBrain}
    else
	TXwInputImages="${T2wInputImages}"
	TXwFolder=${T2wFolder}
	TXwImage=${T2wImage}
	TXwTemplate=${T2wTemplate}
	TXwTemplate2mm=${T2wTemplate2mm}
	TXwTemplateBrain=${T2wTemplateBrain}
    fi
    OutputTXwImageSTRING=""
    OutputTXwBrainImageSTRING=""

      # skip modality if no image

    if [ "${TXwInputImages}" = "NONE" ] ; then
       log_Msg "Skipping Modality: $TXw - image not specified."
       continue
    else
        log_Msg "Processing Modality: $TXw"
    fi

    # Perform Gradient Nonlinearity Correction

    if [ ! $GradientDistortionCoeffs = "NONE" ] ; then
            log_Msg "Performing Gradient Nonlinearity Correction"
	
	i=1
	for Image in $TXwInputImages ; do
	    wdir=${TXwFolder}/${TXwImage}${i}_GradientDistortionUnwarp
		log_Msg "mkdir -p $wdir"
	    mkdir -p $wdir
      # Make sure input axes are oriented the same as the templates
	    ${RUN} ${FSLDIR}/bin/fslreorient2std ${Image} ${wdir}/${TXwImage}${i}

	    ${RUN} ${GlobalScripts}/GradientDistortionUnwarp.sh \
		--workingdir=${wdir} \
		--coeffs=$GradientDistortionCoeffs \
		--in=${wdir}/${TXwImage}${i} \
		--out=${TXwFolder}/${TXwImage}${i}_gdc \
		--owarp=${TXwFolder}/xfms/${TXwImage}${i}_gdc_warp
	    OutputTXwImageSTRING="${OutputTXwImageSTRING}${TXwFolder}/${TXwImage}${i}_gdc "
	    i=$(($i+1))
	done

    else
	log_Msg "NOT PERFORMING GRADIENT DISTORTION CORRECTION"

	i=1
	for Image in $TXwInputImages ; do
	    Image="`${FSLDIR}/bin/remove_ext $Image`"
            if [[ $(imtest ${TXwFolder}/${TXwImage}${i}_gdc) = 1 ]] ; then
               imrm ${TXwFolder}/${TXwImage}${i}_gdc
            fi
	    ${RUN} ${FSLDIR}/bin/fslreorient2std $Image ${TXwFolder}/${TXwImage}${i}_gdc
	    OutputTXwImageSTRING="${OutputTXwImageSTRING}${TXwFolder}/${TXwImage}${i}_gdc "
	    if [ $(${FSLDIR}/bin/imtest $(remove_ext $Image)_brain) = 1 ] ; then # TH - for robust init registration
              if [[ $(imtest ${TXwFolder}/${TXwImage}${i}_gdc_brain) = 1 ]] ; then
                imrm ${TXwFolder}/${TXwImage}${i}_gdc_brain
              fi
	      ${RUN} ${FSLDIR}/bin/fslreorient2std $(remove_ext $Image)_brain ${TXwFolder}/${TXwImage}${i}_gdc_brain
	      log_Msg "Found $(remove_ext $Image)_brain"
	      OutputTXwBrainImageSTRING="${OutputTXwBrainImageSTRING}${TXwFolder}/${TXwImage}${i}_gdc_brain "
	    else
	      log_Msg "Not found $(remove_ext $Image)_brain"
	    fi
	    i=$(($i+1))
	  done
  
    fi

    # Average Like (Same Modality) Scans

    if [ `echo $TXwInputImages | wc -w` -gt 1 ] ; then
	log_Msg "Averaging ${TXw} Images"
        log_Msg "mkdir -p ${TXwFolder}/Average${TXw}Images"
        mkdir -p ${TXwFolder}/Average${TXw}Images
        log_Msg "PERFORMING SIMPLE AVERAGING FOR ${TXw}"
        ${RUN} ${HCPPIPEDIR_PreFS}/AnatomicalAverage.sh -o ${TXwFolder}/${TXwImage} -s ${TXwTemplate} -m ${TemplateMask} -n -w ${TXwFolder}/Average${TXw}Images --noclean -v -b $BrainSize $OutputTXwImageSTRING
        if [ `echo $OutputTXwBrainImageSTRING | wc -w` -ge 1 ] ; then
          log_Msg "PERFORMING SIMPLE AVERAGING FOR ${TXw} BRAIN"
          if [ `echo $OutputTXwBrainImageSTRING | wc -w` = 1 ] ; then
            for img in $OutputTXwBrainImageSTRING ; do
               flirt -in $img -ref ${TXwFolder}/${TXwImage} -applyxfm -init ${TXwFolder}/Average${TXw}Images/ToHalfTrans0001.mat -o ${TXwFolder}/${TXwImage}_brain -interp nearestneighbour
            done
          elif [ `echo $OutputTXwBrainImageSTRING | wc -w` =  `echo $OutputTXwImageSTRING | wc -w` ] ; then
            i=1; 
            for img in $OutputTXwBrainImageSTRING ; do
               num=$(echo $OutputTXwBrainImageSTRING | wc -w)
               num=$(zeropad $num 4)
               flirt -in $img -ref ${TXwFolder}/${TXwImage} -applyxfm -init ${TXwFolder}/Average${TXw}Images/ToHalfTrans${num}.mat -o ${TXwFolder}/Average${TXw}Images/${TXwImage}${i}_gdc_brain -interp nearestneighbour
               OutputTXwBrainImageSTRINGTMP="$OutputTXwBrainImageSTRINGTMP ${TXwFolder}/Average${TXw}Images/${TXwImage}${i}_gdc_brain"
               i=$((i + 1))
            done
            fslmerge -t  ${TXwFolder}/${TXwImage}_brain $OutputTXwBrainImageSTRINGTMP
            fslmaths ${TXwFolder}/${TXwImage}_brain -Tmean ${TXwFolder}/${TXwImage}_brain
          else
          	log_Msg "ERROR: the brain only image should be prepared either for the initial input or for all the inputs"
          	exit 1;
          fi
        fi
    else
	log_Msg "ONLY ONE AVERAGE FOUND: COPYING"
	#${RUN} ${FSLDIR}/bin/imcp ${TXwFolder}/${TXwImage}1_gdc ${TXwFolder}/${TXwImage}
	${RUN} ${FSLDIR}/bin/fslmaths ${TXwFolder}/${TXwImage}1_gdc ${TXwFolder}/${TXwImage}
	if [ `${FSLDIR}/bin/imtest ${TXwFolder}/${TXwImage}1_gdc_brain` = 1 ] ; then
		${RUN} ${FSLDIR}/bin/imcp ${TXwFolder}/${TXwImage}1_gdc_brain ${TXwFolder}/${TXwImage}_brain
	fi
    fi

#### Defacing T1w and T2w if BrainSize=150 (assuminng that it is human brain) - TH July 1 2019
    if [[ $Defacing = TRUE ]] ; then
      if [ "$BrainSize" -eq "150" ] ; then
	log_Msg "BrainSize=150. Defacing ${TXwImage}"
    	${GlobalScripts}/fsl_deface ${TXwFolder}/${TXwImage}.nii.gz ${TXwFolder}/${TXwImage}.nii.gz
      fi
    fi

#### ACPC align T1w and T2w image to 0.7mm MNI T1wTemplate to create native volume space ####

    mkdir -p ${TXwFolder}/ACPCAlignment
#################################### Modified from here. Oct 24 2015, Takuya Hayashi
#    ${RUN} ${PipelineScripts}/ACPCAlignment.sh \
#	--workingdir=${TXwFolder}/ACPCAlignment \
#	--in=${TXwFolder}/${TXwImage} \
#	--ref=${TXwTemplate} \
#	--out=${TXwFolder}/${TXwImage}_acpc \
#	--omat=${TXwFolder}/xfms/acpc.mat \
#	--brainsize=${BrainSize}
# Following command use ${TXwFolder}/${TXwImage}_brain if present
    ${RUN} ${PipelineScripts}/ACPCAlignment_RIKEN.sh \
	--workingdir=${TXwFolder}/ACPCAlignment \
	--in=${TXwFolder}/${TXwImage} \
	--ref=${TXwTemplateBrain} \
	--out=${TXwFolder}/${TXwImage}_acpc \
	--omat=${TXwFolder}/xfms/acpc.mat \
	--brainsize=${BrainSize} \
	--identmat=${IdentMat}
#################################### Modified until here. Oct 24 2015, Takuya Hayashi

#### Brain Extraction (FNIRT-based Masking) ####
#################################### Modified from here. June 18 2016, Takuya Hayashi
  if [ "$BrainExtractionFnirtBased" = TRUE ] ; then
    mkdir -p ${TXwFolder}/BrainExtraction_FNIRTbased
#    ${RUN} ${PipelineScripts}/BrainExtraction_FNIRTbased.sh \
#	--workingdir=${TXwFolder}/BrainExtraction_FNIRTbased \
#	--in=${TXwFolder}/${TXwImage}_acpc \
#	--ref=${TXwTemplate} \
#	--refmask=${TemplateMask} \
#	--ref2mm=${TXwTemplate2mm} \
#	--ref2mmmask=${Template2mmMask} \
#	--outbrain=${TXwFolder}/${TXwImage}_acpc_brain \
#	--outbrainmask=${TXwFolder}/${TXwImage}_acpc_brain_mask \
#	--fnirtconfig=${FNIRTConfig}

# Following command expects an additional input, ${TXwFolder}/${TXwImage}_acpc_brain
    ${RUN} ${PipelineScripts}/BrainExtraction_FNIRTbased_RIKEN.sh \
	--workingdir=${TXwFolder}/BrainExtraction_FNIRTbased \
	--in=${TXwFolder}/${TXwImage}_acpc \
	--ref=${TXwTemplateBrain} \
	--refmask=${TemplateMask} \
	--ref2mm=${TXwTemplate2mm} \
	--ref2mmmask=${Template2mmMask} \
	--outbrain=${TXwFolder}/${TXwImage}_acpc_brain \
	--outbrainmask=${TXwFolder}/${TXwImage}_acpc_brain_mask \
	--fnirtconfig=${FNIRTConfig} \
        --identmat=${IdentMat}
#################################### Modified until here. June 16 2016, Takuya Hayashi
   fi 
done 

######## END LOOP over T1w and T2w #########



#### T2w to T1w Registration and Optional Readout Distortion Correction ####

if [[ ${AvgrdcSTRING} = "FIELDMAP" || ${AvgrdcSTRING} = "TOPUP" ]] ; then
  log_Msg "PERFORMING ${AvgrdcSTRING} READOUT DISTORTION CORRECTION"
  if [ ! $T2wFolder = NONE ] ; then
   wdir=${T2wFolder}/T2wToT1wDistortionCorrectAndReg
   if [ -d ${wdir} ] ; then
      # DO NOT change the following line to "rm -r ${wdir}" because the chances of something going wrong with that are much higher, and rm -r always needs to be treated with the utmost caution
    rm -r ${T2wFolder}/T2wToT1wDistortionCorrectAndReg
   fi
  else
   wdir=${T1wFolder}/T2wToT1wDistortionCorrectAndReg
  fi
  mkdir -p ${wdir}
  ${RUN} ${PipelineScripts}/T2wToT1wDistortionCorrectAndReg_RIKEN.sh \
      --workingdir=${wdir} \
      --t1=${T1wFolder}/${T1wImage}_acpc \
      --t1brain=${T1wFolder}/${T1wImage}_acpc_brain \
      --t2=${T2wFolder_T2wImageWithPath_acpc} \
      --t2brain=${T2wFolder_T2wImageWithPath_acpc_brain} \
      --fmapmag=${MagnitudeInputName} \
      --fmapphase=${PhaseInputName} \
      --echodiff=${TE} \
      --SEPhaseNeg=${SpinEchoPhaseEncodeNegative} \
      --SEPhasePos=${SpinEchoPhaseEncodePositive} \
      --echospacing=${DwellTime} \
      --seunwarpdir=${SEUnwarpDir} \
      --t1sampspacing=${T1wSampleSpacing} \
      --t2sampspacing=${T2wSampleSpacing} \
      --unwarpdir=${UnwarpDir} \
      --ot1=${T1wFolder}/${T1wImage}_acpc_dc \
      --ot1brain=${T1wFolder}/${T1wImage}_acpc_dc_brain \
      --ot1warp=${T1wFolder}/xfms/${T1wImage}_dc \
      --ot2=${T1wFolder}/${T2wImage}_acpc_dc \
      --ot2warp=${T1wFolder}/xfms/${T2wImage}_reg_dc \
      --method=${AvgrdcSTRING} \
      --topupconfig=${TopupConfig} \
      --gdcoeffs=${GradientDistortionCoeffs} \
      --usejacobian="true"

else

  if [ ! $T2wFolder = NONE ] ; then
    wdir=${T2wFolder}/T2wToT1wReg
    if [ -e ${wdir} ] ; then
      # DO NOT change the following line to "rm -r ${wdir}" because the chances of something going wrong with that are much higher, and rm -r always needs to be treated with the utmost caution
      rm -r ${T2wFolder}/T2wToT1wReg
    fi
  else
    wdir=${T1wFolder}/T2wToT1wReg
  fi

  mkdir -p ${wdir}
  ${RUN} ${PipelineScripts}/T2wToT1wReg_RIKEN.sh \
      ${wdir} \
      ${T1wFolder}/${T1wImage}_acpc \
      ${T1wFolder}/${T1wImage}_acpc_brain \
      ${T2wFolder_T2wImageWithPath_acpc} \
      ${T2wFolder_T2wImageWithPath_acpc_brain} \
      ${T1wFolder}/${T1wImage}_acpc_dc \
      ${T1wFolder}/${T1wImage}_acpc_dc_brain \
      ${T1wFolder}/xfms/${T1wImage}_dc \
      ${T1wFolder}/${T2wImage}_acpc_dc \
      ${T1wFolder}/xfms/${T2wImage}_reg_dc \
      ${IdentMat}
fi  


#### Bias Field Correction: Calculate bias field using square root of the product of T1w and T2w iamges.  ####
if [ ! -z ${BiasFieldSmoothingSigma} ] ; then
  BiasFieldSmoothingSigma="--bfsigma=${BiasFieldSmoothingSigma}"
fi

if [ ! "${T2wInputImages}" = "NONE" ] ; then

   mkdir -p ${T1wFolder}/BiasFieldCorrection_sqrtT1wXT2w 
   ${RUN} ${PipelineScripts}/BiasFieldCorrection_sqrtT1wXT2w_RIKEN.sh \
    --workingdir=${T1wFolder}/BiasFieldCorrection_sqrtT1wXT2w \
    --T1im=${T1wFolder}/${T1wImage}_acpc_dc \
    --T1brain=${T1wFolder}/${T1wImage}_acpc_dc_brain \
    --T2im=${T1wFolder_T2wImageWithPath_acpc_dc} \
    --obias=${T1wFolder}/BiasField_acpc_dc \
    --oT1im=${T1wFolder}/${T1wImage}_acpc_dc_restore \
    --oT1brain=${T1wFolder}/${T1wImage}_acpc_dc_restore_brain \
    --oT2im=${T1wFolder}/${T2wImage}_acpc_dc_restore \
    --oT2brain=${T1wFolder}/${T2wImage}_acpc_dc_restore_brain \
    ${BiasFieldSmoothingSigma}

else  # -- No T2w image

    log_Msg "Performing Bias Field Correction using T1w image only"
    BiasFieldSmoothingSigma="20" # Fast-based BiasFieldSmoothingSigma hard coded
    BiasFieldSmoothingSigma="--bfsigma=${BiasFieldSmoothingSigma}"

    ${RUN} ${HCPPIPEDIR_PreFS}/BiasFieldCorrection_T1wOnly_RIKEN.sh \
      --workingdir=${T1wFolder}/BiasFieldCorrection_T1wOnly \
      --T1im=${T1wFolder}/${T1wImage}_acpc_dc \
      --T1brain=${T1wFolder}/${T1wImage}_acpc_dc_brain \
      --obias=${T1wFolder}/BiasField_acpc_dc \
      --oT1im=${T1wFolder}/${T1wImage}_acpc_dc_restore \
      --oT1brain=${T1wFolder}/${T1wImage}_acpc_dc_restore_brain \
      ${BiasFieldSmoothingSigma}

fi


#### Atlas Registration to MNI152: FLIRT + FNIRT  #Also applies registration to T1w and T2w images ####
#Consider combining all transforms and recreating files with single resampling steps
${RUN} ${PipelineScripts}/AtlasRegistrationToMNI152_FLIRTandFNIRT_RIKEN.sh \
    --workingdir=${AtlasSpaceFolder} \
    --t1=${T1wFolder}/${T1wImage}_acpc_dc \
    --t1rest=${T1wFolder}/${T1wImage}_acpc_dc_restore \
    --t1restbrain=${T1wFolder}/${T1wImage}_acpc_dc_restore_brain \
    --t2=${T1wFolder_T2wImageWithPath_acpc_dc}  \
    --t2rest=${T1wFolder}/${T2wImage}_acpc_dc_restore \
    --t2restbrain=${T1wFolder}/${T2wImage}_acpc_dc_restore_brain \
    --ref=${T1wTemplate} \
    --refbrain=${T1wTemplateBrain} \
    --refmask=${TemplateMask} \
    --ref2mm=${T1wTemplate2mm} \
    --ref2mmmask=${Template2mmMask} \
    --owarp=${AtlasSpaceFolder}/xfms/acpc_dc2standard.nii.gz \
    --oinvwarp=${AtlasSpaceFolder}/xfms/standard2acpc_dc.nii.gz \
    --ot1=${AtlasSpaceFolder}/${T1wImage} \
    --ot1rest=${AtlasSpaceFolder}/${T1wImage}_restore \
    --ot1restbrain=${AtlasSpaceFolder}/${T1wImage}_restore_brain \
    --ot2=${AtlasSpaceFolder}/${T2wImage} \
    --ot2rest=${AtlasSpaceFolder}/${T2wImage}_restore \
    --ot2restbrain=${AtlasSpaceFolder}/${T2wImage}_restore_brain \
    --fnirtconfig=${FNIRTConfig} \
    --identmat=${IdentMat}

#### Next stage: FreeSurfer/FreeSurferPipeline.sh

