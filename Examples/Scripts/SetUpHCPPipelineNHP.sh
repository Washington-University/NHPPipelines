#!/bin/bash 

echo "This script must be SOURCED to correctly setup the environment prior to running any of the other HCP scripts contained here"

# Set up FSL (if not already done so in the running environment)
#FSLDIR=/usr/share/fsl/5.0
#. ${FSLDIR}/etc/fslconf/fsl.sh

# Set up FreeSurfer (if not already done so in the running environment)
export FREESURFER_HOME=/usr/local/freesurfer-HCP
. ${FREESURFER_HOME}/SetUpFreeSurfer.sh > /dev/null 2>&1

export HCPPIPEDIR=/mnt/FAI1/devel/NHPHCPPipeline

#export CARET7DIR=/mnt/FAI1/devel/workbench/bin_linux64
export CARET7DIR=/usr/bin

# ApplyHandClassification
export MATLAB_HOME=`which matlab | sed 's/bin\/matlab//g'`
export CLUSTER=2.0

# Global
export HCPPIPEDIR_Templates=${HCPPIPEDIR}/global/templates
export HCPPIPEDIR_Bin=${HCPPIPEDIR}/global/binaries
export HCPPIPEDIR_Config=${HCPPIPEDIR}/global/config
export HCPPIPEDIR_PreFS=${HCPPIPEDIR}/PreFreeSurfer/scripts
export HCPPIPEDIR_FS=${HCPPIPEDIR}/FreeSurfer/scripts
export HCPPIPEDIR_PostFS=${HCPPIPEDIR}/PostFreeSurfer/scripts
export HCPPIPEDIR_fMRISurf=${HCPPIPEDIR}/fMRISurface/scripts
export HCPPIPEDIR_fMRIVol=${HCPPIPEDIR}/fMRIVolume/scripts
export HCPPIPEDIR_tfMRI=${HCPPIPEDIR}/tfMRI/scripts
export HCPPIPEDIR_dMRI=${HCPPIPEDIR}/DiffusionPreprocessing/scripts
export HCPPIPEDIR_dMRITract=${HCPPIPEDIR}/DiffusionTractography
export HCPPIPEDIR_Global=${HCPPIPEDIR}/global/scripts
export HCPPIPEDIR_tfMRIAnalysis=${HCPPIPEDIR}/TaskfMRIAnalysis/scripts
export MATLAB_COMPILER_RUNTIME=/usr/local/MATLAB/MATLAB_Compiler_Runtime

HOST=`hostname`
if [ $HOST = Compass-S ] ; then
 export FixDir=/usr/local/fix1.06
else
 export FixDir=/usr/local/HCP/FIX/fix1.06
fi
export NSLOTS=8

export FreeSurferLabels="${HCPPIPEDIR_Config}/FreeSurferAllLut.txt"
export MSMBINDIR=$HCPPIPEDIR/MSMBinaries
export MSMBINDIR=/mnt/FAI1/devel/MSM/MSM_HOCR_v2/Centos

if [ $HOST = Compass-S ] ; then
 export MSMBINDIR=/mnt/FAI1/devel/MSM/MSM_HOCR_v2/Centos
else
 #export MSMBINDIR=/mnt/FAI1/devel/NHPHCPPipeline/MSMBinaries
 export MSMBINDIR=/mnt/FAI1/devel/MSM/MSM_HOCR_v2/Ubuntu
fi

export MSMCONFIGDIR=$HCPPIPEDIR/MSMConfig

#export RegName="MSMSulc" # MSMSulc is recommended, if binary is not available use FS (FreeSurfer)
export RegName="FS"

export BiasFieldSmoothingSigma="1.5" # added by Takuya Hayashi on Oct 7th 2017

if [ "$SPECIES" = Human ] ; then

#Examples/Scripts/PreFreeSurferPipeLineNHP.bat
export BrainSize="150" #BrainSize in mm, 150 for humans, 60 for macaques, 40 for marmosets
export T1wTemplate="${HCPPIPEDIR_Templates}/MNI152_T1_0.7mm.nii.gz"  
export T1wTemplateBrain="${HCPPIPEDIR_Templates}/MNI152_T1_0.7mm_brain.nii.gz" 
export T1wTemplate2mm="${HCPPIPEDIR_Templates}/MNI152_T1_2.0mm"  
export T2wTemplate="${HCPPIPEDIR_Templates}/MNI152_T2w_0.7mm.nii.gz"  
export T2wTemplateBrain="${HCPPIPEDIR_Templates}/MNI152_T2w_0.7mm_brain" 
export T2wTemplate2mm="${HCPPIPEDIR_Templates}/MNI152_T2w_2.0mm" 
export TemplateMask="${HCPPIPEDIR_Templates}/MNI152_T1w_0.7mm_brain_mask.nii.gz" 
export Template2mmMask="${HCPPIPEDIR_Templates}/MNI152_T1w_2.0mm_brain_mask_dil.nii.gz" 
export GCAdir="${FREESURFER_HOME}/average"

#Examples/Scripts/PostFreeSurferPipeLineNHP.bat
export SurfaceAtlasDIR="${HCPPIPEDIR_Templates}/standard_mesh_atlases"
export GrayordinatesSpaceDIR="${HCPPIPEDIR_Templates}/standard_mesh_atlases"
export ReferenceMyelinMaps="${HCPPIPEDIR_Templates}/standard_mesh_atlases/Conte69.MyelinMap_BC.164k_fs_LR.dscalar.nii"
export LowResMesh="32" #Needs to match what is in PostFreeSurfer
export FinalfMRIResolution="2.0" #Needs to match what is in fMRIVolume
export SmoothingFWHM="2.0" #Recommended to be roughly the voxel size
export GrayordinatesResolution="2.0" #Needs to match what is in PostFreeSurfer. Could be the same as FinalfRMIResolution something different, which will call a different module for subcortical processing


elif [ "$SPECIES" = Macaque ] ; then

export VariableSigma=4
export CorrectionSigma=7
export FNIRTConfig=/usr/local/cmis/etc/flirtsch/mon_highres.cnf

#Examples/Scripts/PreFreeSurferPipeLineNHP.bat
export BrainSize="60" #BrainSize in mm, 150 for humans, 60 for macaques, 40 for marmosets
export T1wTemplate="${HCPPIPEDIR_Templates}/MacaqueYerkes19_T1w_0.5mm_dedrift.nii.gz" #MacaqueYerkes0.5mm template 
export T1wTemplateBrain="${HCPPIPEDIR_Templates}/MacaqueYerkes19_T1w_0.5mm_brain_dedrift.nii.gz" #Brain extracted MacaqueYerkes0.5mm template
export T1wTemplate2mm="${HCPPIPEDIR_Templates}/MacaqueYerkes19_T1w_1.0mm_dedrift" #MacaqueYerkes1.0mm template brain modified by Takuya Hayshi on Oct 24th 2015. 
export T2wTemplate="${HCPPIPEDIR_Templates}/MacaqueYerkes19_T2w_0.5mm_dedrift.nii.gz" #MacaqueYerkes0.5mm T2wTemplate 
export T2wTemplateBrain="${HCPPIPEDIR_Templates}/MacaqueYerkes19_T2w_0.5mm_brain_dedrift.nii.gz" #Brain extracted MacaqueYerkes0.5mm T2wTemplate
export T2wTemplate2mm="${HCPPIPEDIR_Templates}/MacaqueYerkes19_T2w_1.0mm_dedrift" #MacaqueYerkes1.0mm T2wTemplate brain, modified by Takuya Hayashi on Oct 24th 2015.
export TemplateMask="${HCPPIPEDIR_Templates}/MacaqueYerkes19_T1w_0.5mm_brain_mask_dedrift.nii.gz" #Brain mask MacaqueYerkes0.5mm template
export Template2mmMask="${HCPPIPEDIR_Templates}/MacaqueYerkes19_T1w_1.0mm_brain_mask_dedrift.nii.gz" #MacaqueYerkes1.0mm template
export RescaleVolumeTransform="${HCPPIPEDIR_Templates}/fs_xfms/Macaque_rescale" #Transforms to undo the effects of faking the dimensions to 1mm
#export GCAdir="${HCPPIPEDIR_Templates}/MacaqueRIKEN21" #Template Dir with FreeSurfer NHP GCA and TIF files
export GCAdir="${HCPPIPEDIR_Templates}/MacaqueYerkes19" #Template Dir with FreeSurfer NHP GCA and TIF files
#Examples/Scripts/PostFreeSurferPipeLineNHP.bat
#export SurfaceAtlasDIR="${HCPPIPEDIR_Templates}/standard_mesh_atlases_macaque_dedrift"
export SurfaceAtlasDIR="${HCPPIPEDIR_Templates}/standard_mesh_atlases_macaque"
export GrayordinatesSpaceDIR="${HCPPIPEDIR_Templates}/standard_mesh_atlases_macaque_dedrift"
export ReferenceMyelinMaps="${HCPPIPEDIR_Templates}/standard_mesh_atlases_macaque_dedrift/MacaqueYerkes19.MyelinMap_BC.164k_fs_LR.dscalar.nii"
export LowResMesh="32@10" #Needs to match what is in PostFreeSurfer
export FinalfMRIResolution="1.25" #Needs to match what is in fMRIVolume
export SmoothingFWHM="1.25" #Recommended to be roughly the voxel size
export GrayordinatesResolution="1.25" #Needs to match what is in PostFreeSurfer. Could be the same as FinalfRMIResolution something different, which will call a different module for subcortical processing


elif [ "$SPECIES" = Macaque_T1 ] ; then
export VariableSigma=4
export CorrectionSigma=7
export FNIRTConfig=/usr/local/cmis/etc/flirtsch/mon_highres.cnf

#Examples/Scripts/PreFreeSurferPipeLineNHP.bat
export BrainSize="60" #BrainSize in mm, 150 for humans, 60 for macaques, 40 for marmosets
export T1wTemplate="${HCPPIPEDIR_Templates}/MacaqueYerkes19_T1w_0.5mm.nii.gz" #MacaqueYerkes0.5mm template 
export T1wTemplateBrain="${HCPPIPEDIR_Templates}/MacaqueYerkes19_T1w_0.5mm_brain.nii.gz" #Brain extracted MacaqueYerkes0.5mm template
export T1wTemplate2mm="${HCPPIPEDIR_Templates}/MacaqueYerkes19_T1w_1.0mm" #MacaqueYerkes1.0mm template brain modified by Takuya Hayshi on Oct 24th 2015. 
export T2wTemplate="${HCPPIPEDIR_Templates}/MacaqueYerkes19_T2w_0.5mm.nii.gz" #MacaqueYerkes0.5mm T2wTemplate 
export T2wTemplateBrain="${HCPPIPEDIR_Templates}/MacaqueYerkes19_T2w_0.5mm_brain.nii.gz" #Brain extracted MacaqueYerkes0.5mm T2wTemplate
export T2wTemplate2mm="${HCPPIPEDIR_Templates}/MacaqueYerkes19_T2w_1.0mm" #MacaqueYerkes1.0mm T2wTemplate brain, modified by Takuya Hayashi on Oct 24th 2015.
export TemplateMask="${HCPPIPEDIR_Templates}/MacaqueYerkes19_T1w_0.5mm_brain_mask_dil.nii.gz" #Brain mask MacaqueYerkes0.5mm template
export Template2mmMask="${HCPPIPEDIR_Templates}/MacaqueYerkes19_T1w_1.0mm_brain_mask_dil.nii.gz" #MacaqueYerkes1.0mm template
export RescaleVolumeTransform="${HCPPIPEDIR_Templates}/fs_xfms/Macaque_rescale" #Transforms to undo the effects of faking the dimensions to 1mm
export GCAdir="${HCPPIPEDIR_Templates}/MacaqueYerkes19" #Template Dir with FreeSurfer NHP GCA and TIF files
#Examples/Scripts/PostFreeSurferPipeLineNHP.bat
export SurfaceAtlasDIR="${HCPPIPEDIR_Templates}/standard_mesh_atlases_macaque"
export GrayordinatesSpaceDIR="${HCPPIPEDIR_Templates}/standard_mesh_atlases_macaque"
export ReferenceMyelinMaps="${HCPPIPEDIR_Templates}/standard_mesh_atlases_macaque/MacaqueYerkes19.MyelinMap_BC.164k_fs_LR.dscalar.nii"
#export IdentMat="TRUE" # TRUE or NONE. If True, apply ident.mat to registration
export T2wFlag="NONE" # T2w, FLAIR, NONE.
export LowResMesh="32@10" #Needs to match what is in PostFreeSurfer
export FinalfMRIResolution="1.25" #Needs to match what is in fMRIVolume
export SmoothingFWHM="1.25" #Recommended to be roughly the voxel size
export GrayordinatesResolution="1.25" #Needs to match what is in PostFreeSurfer. Could be the same as FinalfRMIResolution something different, which will call a different module for subcortical processing

elif [ "$SPECIES" = Macaque_MNI ] ; then
export VariableSigma=4
export CorrectionSigma=7
export FNIRTConfig=/usr/local/cmis/etc/flirtsch/mon_highres.cnf

#Examples/Scripts/PreFreeSurferPipeLineNHP.bat
export BrainSize="80" #BrainSize in mm, 150 for humans, 60 for macaques, 40 for marmosets
export GCAdir="${HCPPIPEDIR_Templates}/MacaqueYerkes19" #Template Dir with FreeSurfer NHP GCA and TIF files

## Examples/Scripts/PostFreeSurferPipeLineNHP.bat
export SurfaceAtlasDIR="${HCPPIPEDIR_Templates}/standard_mesh_atlases_macaque_MNI"
export GrayordinatesSpaceDIR="${HCPPIPEDIR_Templates}/standard_mesh_atlases_macaque_MNI"
export ReferenceMyelinMaps="${HCPPIPEDIR_Templates}/standard_mesh_atlases_macaque_MNI/MacaqueYerkes19.MyelinMap_BC.164k_fs_LR.dscalar.nii"

# Special options
export BiasFieldSmoothingSigma="5" # NONE: do not perform bias field correction, usually use 5
export T1wTemplate="/mnt/mridata1/standard/M.Mulatta/MNI/rhesus_7_model-MNI_0.5mm_HCP.nii.gz"
export T1wTemplateBrain="/mnt/mridata1/standard/M.Mulatta/MNI/rhesus_7_model-MNI_0.5mm_HCP_brain.nii.gz"
export T1wTemplate2mm="/mnt/mridata1/standard/M.Mulatta/MNI/rhesus_7_model-MNI_0.5mm_HCP.nii.gz"
export T2wTemplate="/mnt/mridata1/standard/M.Mulatta/MNI/FakeT2_HCP.nii.gz"
export T2wTemplateBrain="/mnt/mridata1/standard/M.Mulatta/MNI/FakeT2_HCP_brain.nii.gz"
export T2wTemplate2mm="/mnt/mridata1/standard/M.Mulatta/MNI/FakeT2_HCP.nii.gz"
export TemplateMask="/mnt/mridata1/standard/M.Mulatta/MNI/rhesus_7_model-MNI_0.5mm_HCP_brain_mask.nii.gz"
export Template2mmMask="/mnt/mridata1/standard/M.Mulatta/MNI/rhesus_7_model-MNI_0.5mm_HCP_brain_mask.nii.gz"
export RescaleVolumeTransform="/mnt/mridata1/standard/M.Mulatta/MNI/fs_xfms/Macaque_rescale"
export LowResMesh="32@10" #Needs to match what is in PostFreeSurfer
export FinalfMRIResolution="1.25" #Needs to match what is in fMRIVolume
export SmoothingFWHM="1.25" #Recommended to be roughly the voxel size
export GrayordinatesResolution="1.25" #Needs to match what is in PostFreeSurfer. Could be the same as FinalfRMIResolution something different, which will call a different module for subcortical processing

elif [ "$SPECIES" = Marmoset ] ; then

export VariableSigma=4
export CorrectionSigma=7
export FNIRTConfig=/usr/local/cmis/etc/flirtsch/mon_highres.cnf

export BrainSize="40" #BrainSize in mm, 150 for humans, 60 for macaques, 40 for marmosets
#Examples/Scripts/PreFreeSurferPipeLineNHP.bat=g
export T1wTemplate="/mnt/FAI1/devel/NHPHCPPipeline/global/templates/MarmosetRIKEN/RIKENMarmoset15_AverageT1w_restore_dedrift.nii.gz"
export T1wTemplateBrain="/mnt/FAI1/devel/NHPHCPPipeline/global/templates/MarmosetRIKEN/RIKENMarmoset15_AverageT1w_restore_dedrift_brain.nii.gz" 
export T1wTemplate2mm="/mnt/FAI1/devel/NHPHCPPipeline/global/templates/MarmosetRIKEN/RIKENMarmoset15_AverageT1w_restore_dedrift_0.5mm.nii.gz" 
export T2wTemplate="/mnt/FAI1/devel/NHPHCPPipeline/global/templates/MarmosetRIKEN/RIKENMarmoset15_AverageT2w_restore_dedrift.nii.gz" 
export T2wTemplateBrain="/mnt/FAI1/devel/NHPHCPPipeline/global/templates/MarmosetRIKEN/RIKENMarmoset15_AverageT2w_restore_dedrift_brain.nii.gz"
export T2wTemplate2mm="/mnt/FAI1/devel/NHPHCPPipeline/global/templates/MarmosetRIKEN/RIKENMarmoset15_AverageT2w_restore_dedrift_0.5mm.nii.gz"
export TemplateMask="/mnt/FAI1/devel/NHPHCPPipeline/global/templates/MarmosetRIKEN/RIKENMarmoset15_AverageT1w_restore_dedrift_brain_mask_dilM.nii.gz"
export Template2mmMask="/mnt/FAI1/devel/NHPHCPPipeline/global/templates/MarmosetRIKEN/RIKENMarmoset15_AverageT1w_restore_dedrift_0.5mm_brain_mask_dilM.nii.gz"
export GCAdir="/mnt/FAI1/devel/NHPHCPPipeline/global/templates/MarmosetRIKEN" 
#export GCAdir="${HCPPIPEDIR_Templates}/MacaqueYerkes19" #Used for initialization of surfreg Takuya Hayashi Jan 2018
export RescaleVolumeTransform="${HCPPIPEDIR_Templates}/fs_xfms/Marmoset_rescale"
#Examples/Scripts/PostFreeSurferPipeLineNHP.bat
export SurfaceAtlasDIR="/mnt/FAI1/devel/NHPHCPPipeline/global/templates/standard_mesh_atlases_marmoset"
export GrayordinatesSpaceDIR="/mnt/FAI1/devel/NHPHCPPipeline/global/templates/standard_mesh_atlases_marmoset"
export ReferenceMyelinMaps="/mnt/FAI1/devel/NHPHCPPipeline/global/templates/standard_mesh_atlases_marmoset/MyelinMap_BC.164k_fs_LR.dscalar.nii"
export VariebleSigma=12
export CorrectionSigma=3
#export T2wFlag="T2w" # do not use T2w in HiresPial. Marmoset does not work

#Grayordinates
export LowResMesh=32@10@2 #Needs to match what is in PostFreeSurfer
export FinalfMRIResolution="1.0" #Needs to match what is in fMRIVolume
export SmoothingFWHM="1.0" #Recommended to be roughly the voxel size
export GrayordinatesResolution="1.0" #Needs to match what is in PostFreeSurfer. Could be the same as FinalfRMIResolution something different, which will call a different module for subcortical processing
export RegName="MSMSulc"
#export RegName="NONE"

else

 echo "Not yet supported speces: $SPECIES"

fi

#export MSMBin=/media/myelin/brainmappers/HardDrives/2TBB/Connectome_Project/Pipelines/OLD/MSMBinaries/PreVisit

## WASHU config - as understood by MJ - (different structure from the GIT repository)
## Also look at: /nrgpackages/scripts/tools_setup.sh

# Set up FSL (if not already done so in the running environment)
#FSLDIR=/nrgpackages/scripts
#. ${FSLDIR}/fsl5_setup.sh

# Set up FreeSurfer (if not already done so in the running environment)
#FREESURFER_HOME=/nrgpackages/tools/freesurfer5
#. ${FREESURFER_HOME}/SetUpFreeSurfer.sh

#NRG_SCRIPTS=/nrgpackages/scripts
#. ${NRG_SCRIPTS}/epd-python_setup.sh

#export HCPPIPEDIR=/home/NRG/jwilso01/dev/Pipelines
#export HCPPIPEDIR_PreFS=${HCPPIPEDIR}/PreFreeSurfer/scripts
#export HCPPIPEDIR_FS=/data/intradb/pipeline/catalog/StructuralHCP/resources/scripts
#export HCPPIPEDIR_PostFS=/data/intradb/pipeline/catalog/StructuralHCP/resources/scripts

#export HCPPIPEDIR_FIX=/data/intradb/pipeline/catalog/FIX_HCP/resources/scripts
#export HCPPIPEDIR_Diffusion=/data/intradb/pipeline/catalog/DiffusionHCP/resources/scripts
#export HCPPIPEDIR_Functional=/data/intradb/pipeline/catalog/FunctionalHCP/resources/scripts

#export HCPPIPETOOLS=/nrgpackages/tools/HCP
#export HCPPIPEDIR_Templates=/nrgpackages/atlas/HCP
#export HCPPIPEDIR_Bin=${HCPPIPETOOLS}/bin
#export HCPPIPEDIR_Config=${HCPPIPETOOLS}/conf
#export HCPPIPEDIR_Global=${HCPPIPETOOLS}/scripts_v2

#export CARET5DIR=${HCPPIPEDIR_Bin}/caret5
#export CARET7DIR=${HCPPIPEDIR_Bin}/caret7/bin_linux64
## may or may not want the above variables from CARET5DIR to HCPPIPEDIR_Global to be setup as above or not
##    (if so then the HCPPIPEDIR line needs to go before them)
## end of WASHU config


# The following is probably unnecessary on most systems
#PATH=${PATH}:/vols/Data/HCP/pybin/bin/
#PYTHONPATH=/vols/Data/HCP/pybin/lib64/python2.6/site-packages/


