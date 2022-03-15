#!/bin/bash 
set -e

# Requirements for this script
#  installed versions of: FSL5.0.1 or higher , FreeSurfer (version 5 or higher) , gradunwarp (python code from MGH)
#  environment: FSLDIR , FREESURFER_HOME , HCPPIPEDIR , CARET7DIR , PATH (for gradient_unwarp.py)

# make pipeline engine happy...
if [ $# -eq 1 ] ; then
    echo "Version unknown..."
    exit 0
fi

########################################## PIPELINE OVERVIEW ########################################## 

#TODO

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

# Also exist:
#    T1w/xfms/
#    T2w/xfms/
#    MNINonLinear/xfms/

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

log_Msg "T1wFolder: $T1wFolder"
log_Msg "T2wFolder: $T2wFolder"
log_Msg "AtlasFolder: $AtlasSpaceFolder"

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

#### Gradient nonlinearity correction  (for T1w and T2w) ####

    if [ ! $GradientDistortionCoeffs = "NONE" ] ; then
	
	i=1
	for Image in $TXwInputImages ; do
	    wdir=${TXwFolder}/${TXwImage}${i}_GradientDistortionUnwarp
		log_Msg "mkdir -p $wdir"
	    mkdir -p $wdir
	    ${RUN} ${FSLDIR}/bin/fslreorient2std ${Image} ${wdir}/${TXwImage}${i} #Make sure input axes are oriented the same as the templates 
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

#### Average Like Scans ####

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

