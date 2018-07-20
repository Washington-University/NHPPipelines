#!/bin/bash 

if [ "$SPECIES" = "" ] ; then echo "ERROR: please export SPECIES first, Macaque or Marmoset"; exit 1;fi
EnvironmentScript="/mnt/FAI1/devel/NHPHCPPipeline/Examples/Scripts/SetUpHCPPipeline_RIKEN.sh"
. ${EnvironmentScript}

StudyFolder=$1;shift
Subjlist=$@


PRINTCOM=""
#PRINTCOM="echo"
QUEUE="-T 360"


for Subject in $Subjlist ; do
  if [ -e ${StudyFolder}/${Subject}/RawData/hcppipe_conf.txt ] ; then
   . ${StudyFolder}/${Subject}/RawData/hcppipe_conf.txt
  else
   echo "Cannot find hcppipe_conf.txt in ${Subject}/RawData";
   echo "Exiting without processing.";
   exit 1;
  fi
  i=1
  for fMRIName in $Tasklist ; do
    UnwarpDir=`echo $PhaseEncodinglist | cut -d " " -f $i`
    fMRIName=`remove_ext $fMRIName`
    fMRITimeSeries="`imglob -extension ${StudyFolder}/${Subject}/RawData/$fMRIName`"
    fMRISBRef="`echo $Taskreflist | cut -d " " -f $i`"
    fMRISBRef="`imglob -extension ${StudyFolder}/${Subject}/RawData/$fMRISBRef`" #A single band reference image (SBRef) is recommended if using multiband, set to NONE if you want to use the first volume of the timeseries for motion correction
    ###Previous data was processed with 2x the correct echo spacing because ipat was not accounted for###
    #DwellTime="0.00115" #Echo Spacing or Dwelltime of fMRI image = 1/(BandwidthPerPixelPhaseEncode * # of phase encoding samples): DICOM field (0019,1028) = BandwidthPerPixelPhaseEncode, DICOM field (0051,100b) AcquisitionMatrixText first value (# of phase encoding samples) 
    if [ "$MagnitudeInputName" = "" ] || [ "$MagnitudeInputName" = "NONE" ]; then
	DistortionCorrection="TOPUP" #FIELDMAP or TOPUP, distortion correction is required for accurate processing
    	SpinEchoPhaseEncodeNegative="`imglob -extension ${StudyFolder}/${Subject}/RawData/$TopupNegative`" #For the spin echo field map volume with a negative phase encoding direction (LR in HCP data), set to NONE if using regular FIELDMAP
    	SpinEchoPhaseEncodePositive="`imglob -extension ${StudyFolder}/${Subject}/RawData/$TopupPositive`" #For the spin echo field map volume with a positive phase encoding direction (RL in HCP data), set to NONE if using regular FIELDMAP
       PhaseInputName="NONE" #Expects a 3D Phase volume, set to NONE if using TOPUP
       MagnitudeInputName="NONE" #Expects 4D Magnitude volume with two 3D timepoints, set to NONE if using TOPUP
    	TopUpConfig="b02b0.cnf" #Topup config if using TOPUP, set to NONE if using regular FIELDMAP
       UseJacobian="True"

    else
	MagnitudeInputNAME="`imglob -extension ${StudyFolder}/${Subject}/RawData/${MagnitudeInputName}`"
	PhaseInputNAME="`imglob -extension ${StudyFolder}/${Subject}/RawData/${PhaseInputName}`"
	DistortionCorrection="FIELDMAP"
       DeltaTE="2.46" #2.46ms for 3T, 1.02ms for 7T, set to NONE if using TOPUP
       UseJacobian="False"
    fi

    BiasCorrection="NONE" #NONE, LEGACY, or SEBASED: LEGACY uses the T1w bias field, SEBASED calculates bias field from spin echo images (which requires TOPUP distortion correction)
    #BiasCorrection="SEBASED"
    FinalFMRIResolution="$FinalfMRIResolution" #Target final resolution of fMRI data. 2mm is recommended.  Use 2.0 or 1.0 to avoid standard FSL templates
    GradientDistortionCoeffs="NONE" #Gradient distortion correction coefficents, set to NONE to turn off


    # Use mcflirt motion correction
    MCType="FLIRT"

#    ${FSLDIR}/bin/fsl_sub $QUEUE -l $StudyFolder/$Subject/logs \
    ${HCPPIPEDIR}/fMRIVolume/GenericfMRIVolumeProcessingPipelineNHP.sh \
      --path=$StudyFolder \
      --subject=$Subject \
      --fmriname=$fMRIName \
      --fmritcs=$fMRITimeSeries \
      --fmriscout=$fMRISBRef \
      --SEPhaseNeg=$SpinEchoPhaseEncodeNegative \
      --SEPhasePos=$SpinEchoPhaseEncodePositive \
      --fmapmag=$MagnitudeInputNAME \
      --fmapphase=$PhaseInputNAME \
      --fmapgeneralelectric=$GEB0InputName \
      --echospacing=$DwellTime \
      --echodiff=$DeltaTE \
      --unwarpdir=$UnwarpDir \
      --fmrires=$FinalFMRIResolution \
      --dcmethod=$DistortionCorrection \
      --gdcoeffs=$GradientDistortionCoeffs \
      --topupconfig=$TopUpConfig \
      --printcom=$PRINTCOM \
      --biascorrection=$BiasCorrection \
      --usejacobian=$UseJacobian \
      --mctype=${MCType}

  # The following lines are used for interactive debugging to set the positional parameters: $1 $2 $3 ...

  echo "set -- --path=$StudyFolder \
      --subject=$Subject \
      --fmriname=$fMRIName \
      --fmritcs=$fMRITimeSeries \
      --fmriscout=$fMRISBRef \
      --SEPhaseNeg=$SpinEchoPhaseEncodeNegative \
      --SEPhasePos=$SpinEchoPhaseEncodePositive \
      --fmapmag=$MagnitudeInputNAME \
      --fmapphase=$PhaseInputNAME \
      --fmapgeneralelectric=$GEB0InputName \
      --echospacing=$DwellTime \
      --echodiff=$DeltaTE \
      --unwarpdir=$UnwarpDir \
      --fmrires=$FinalFMRIResolution \
      --dcmethod=$DistortionCorrection \
      --gdcoeffs=$GradientDistortionCoeffs \
      --topupconfig=$TopUpConfig \
      --printcom=$PRINTCOM \
      --biascorrection=$BiasCorrection \
      --usejacobian=$UseJacobian \
      --mctype=${MCType}"

  echo ". ${EnvironmentScript}"
	
    i=$(($i+1))
  done
done


