#!/bin/bash 

if [ "$SPECIES"	= "" ] ; then echo "ERROR: please export SPECIES first,	Macaque	or Marmoset"; exit 1;fi
EnvironmentScript="/mnt/FAI1/devel/NHPHCPPipeline/Examples/Scripts/SetUpHCPPipelineNHP.sh"
. ${EnvironmentScript}

StudyFolder=$1; shift
Subjlist=$@

PRINTCOM=""
QUEUE="-T 30"

for Subject in $Subjlist ; do
  if [ -e ${StudyFolder}/${Subject}/RawData/hcppipe_conf.txt ] ; then
   . ${StudyFolder}/${Subject}/RawData/hcppipe_conf.txt
  else
   echo "Cannot find hcppipe_conf.txt in ${Subject}/RawData";
   echo "Exiting without processing.";
   exit 1;
  fi
  for fMRIName in $Tasklist ; do
    fMRIName=`remove_ext $fMRIName`
    LowResMesh="`echo $LowResMesh | sed -e 's/@/ /g' | awk '{print $NF}'`"
    #FinalfMRIResolution="1.25" #Needs to match what is in fMRIVolume
    #SmoothingFWHM="1.25" #Recommended to be roughly the voxel size
    #GrayordinatesResolution="1.25" #Needs to match what is in PostFreeSurfer. Could be the same as FinalfRMIResolution something different, which will call a different module for subcortical processing
    #RegName="FS"  # MSMSulc is recommended, if binary is not available use FS (FreeSurfer)


   # ${FSLDIR}/bin/fsl_sub $QUEUE -l $StudyFolder/$Subject/logs \
      ${HCPPIPEDIR}/fMRISurface/GenericfMRISurfaceProcessingPipeline.sh \
      --path=$StudyFolder \
      --subject=$Subject \
      --fmriname=$fMRIName \
      --lowresmesh=$LowResMesh \
      --fmrires=$FinalfMRIResolution \
      --smoothingFWHM=$SmoothingFWHM \
      --grayordinatesres=$GrayordinatesResolution \
      --regname=$RegName

  # The following lines are used for interactive debugging to set the positional parameters: $1 $2 $3 ...

      echo "set -- --path=$StudyFolder \
      --subject=$Subject \
      --fmriname=$fMRIName \
      --lowresmesh=$LowResMesh \
      --fmrires=$FinalfMRIResolution \
      --smoothingFWHM=$SmoothingFWHM \
      --grayordinatesres=$GrayordinatesResolutio \
      --regname=$RegName"

      echo ". ${EnvironmentScript}"
            
   done
done

