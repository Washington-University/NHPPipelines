#!/bin/bash
set -e
usage () {
echo "Usage: $0 <SubjectID> <SubjectDIR> <T1w_acpc_dc_restore|T1w_acpc_dc_restore_1mm> <T2w_acpc_dc_restore|T2w_acpc_dc_restore_1mm> <T2w|FLAIR|NONE> <Human|Macaque|Marmoset>"
exit 1;
}
[ "$6" = "" ] && usage

echo -e "\n START: FreeSurferHiresPial"
echo -e "\n with flags $@"

SubjectID="$1"
SubjectDIR="$2"
T1wImage="$3" #T1w FreeSurfer Input (Full Resolution)
T2wImage="$4" #T2w FreeSurfer Input (Full Resolution)
T2wType="$5"
SPECIES="$6"

source $HCPPIPEDIR/global/scripts/log.shlib  # Logging related functions
source $HCPPIPEDIR/global/scripts/opts.shlib # Command line option functions
log_SetToolName "FreeSurferHiresPial.sh"

PipelineScripts=${HCPPIPEDIR_FS}

# Species-dependent variables - Takuya Hayashi Sep 2016 - Oct 2019
if  [[ $SPECIES =~ Macaque ]] ; then 

	VARIABLESIGMA="10"
	MAXTHICKNESS="-max 10"
	PSIGMA="-psigma 5"
	PA="-pa 25"			# average pial curvature (default 16)

elif [[ $SPECIES =~ Marmoset ]] ; then

	VARIABLESIGMA="8"
	MAXTHICKNESS="-max 35" 		# maxthickness in mris_make_surface 1 & 2 using T2w
	PSIGMA="-psigma 10"	   	# pial_sigma default=2. 10 is needed to inflate pial enough 
	NSIGMA_ABOVE="-nsigma_above 10"	# default=3 7 to 10 is needed to inflate pial enough
	PA="-pa 40"  			# average pial curvature (default 16)
	ORIG_PIAL="-orig_pial pial.T2" 	# use initial pial in mris_make_surface 2 using T1w
	MAXTHICKNESST1W="-max 50" 	# use maxthickness in mris_make_surface 2 using T1w

elif [[ $SPECIES =~ Human ]] ; then

	#Check if FreeSurfer is version 5.2.0 or not.  If it is not, use new -first_wm_peak mris_make_surfaces flag
	if [ -z `cat ${FREESURFER_HOME}/build-stamp.txt | grep v5.2.0` ] ; then
	 	VARIABLESIGMA="8"
	else
		VARIABLESIGMA="4"
	fi
	MAXTHICKNESS="-max 5"
else
	echo "ERROR: unknown SPECIES=$SPECIES"; 
	exit 1;
fi

log_Msg "SPECIES: $SPECIES"
log_Msg "VARIABLESIGMA: $VARIABLESIGMA"
log_Msg "MAXTHICKNESS: $MAXTHICKNESS"
log_Msg "PSIGMA: $PSIGMA"
log_Msg "PA: $PA"
log_Msg "NSIGMA_ABOVE: $NSIGMA_ABOVE"
log_Msg "ORIG_PIAL: $ORIG_PIAL"
log_Msg "MAXTHICKNESST1w: $MAXTHICKNESST1W"

if [ "${T2wType}" = "T2w" ] ; then
  T2wFlag="-T2dura"
elif [ "${T2wType}" = "FLAIR" ] ; then
  T2wFlag="-FLAIR"
else
  #echo "Unrecognized T2wType, assuming T2w"
  #T2wFlag="-T2dura"
  T2wFlag="NONE"
fi

log_Msg "T2wFlag: $T2wFlag"
Sigma="5" #in mm

export SUBJECTS_DIR="$SubjectDIR"

mridir=$SubjectDIR/$SubjectID/mri
surfdir=$SubjectDIR/$SubjectID/surf

reg=$mridir/transforms/hires21mm.dat
regII=$mridir/transforms/1mm2hires.dat
hires="$mridir"/T1w_hires.nii.gz
T2="$mridir"/T2w_hires.norm.mgz
Ratio="$mridir"/T1wDividedByT2w_sqrt.nii.gz

log_Msg "Normalizing T1w_hires and T2w_hires"
mri_convert "$mridir"/wm.hires.mgz "$mridir"/wm.hires.nii.gz
fslmaths "$mridir"/wm.hires.nii.gz -thr 110 -uthr 110 "$mridir"/wm.hires.nii.gz 
wmMean=`fslstats "$mridir"/T1w_hires.nii.gz -k "$mridir"/wm.hires.nii.gz -M`
fslmaths "$mridir"/T1w_hires.nii.gz -div $wmMean -mul 110 "$mridir"/T1w_hires.norm.nii.gz
mri_convert "$mridir"/T1w_hires.norm.nii.gz "$mridir"/T1w_hires.norm.mgz

# If marmoset, need to use brain.hires (bias-corrected with T1w*T2w, fast, mri_ca_normalize, mri_normalize) as T1w volume for correct pial in the first round - Takuya Hayashi Jan 2018
# T2w also needs to be corrected for bias using fast - TH Oct 2019
if [[ ! $SPECIES =~ Marmoset ]] ; then 
	T1wHires="T1w_hires.norm"; 
	fslmaths "$mridir"/T2w_hires.nii.gz -div `fslstats "$mridir"/T2w_hires.nii.gz -k "$mridir"/wm.hires.nii.gz -M` -mul 57 "$mridir"/T2w_hires.norm.nii.gz -odt float
	mri_convert "$mridir"/T2w_hires.norm.nii.gz "$mridir"/T2w_hires.norm.mgz
else
	T1wHires="T1w_hires.norm";
	mri_convert "$mridir"/T2w_hires.nii.gz "$mridir"/T2w_hires.mgz
	${PipelineScripts}/IntensityCor.sh "$mridir"/T2w_hires.mgz "$mridir"/T1w_hires.masked.norm.mgz "$mridir"/wm.hires.mgz "$mridir"/T2w_hires.norm.mgz $SPECIES
fi

# Replace accumbens,caudate and lateral ventricle to putamen in aseg for accurate pial surface estimation in sub-genual ACC with mris_make_surface - Takuya Hayashi,Nov 2019

DIR=`pwd`
cd $mridir
fslmaths aseg -thr 58 -uthr 58 -bin -mul 51 appendputamen.rh  # accumbens rh
fslmaths aseg -thr 26 -uthr 26 -bin -mul 12 appendputamen.lh  # accumbens lh
fslmaths aseg -thr 50 -uthr 50 -bin -mul 51 -add appendputamen.rh appendputamen.rh # caudate rh
fslmaths aseg -thr 11 -uthr 11 -bin -mul 12 -add appendputamen.lh appendputamen.lh # caudate lh
fslmaths aseg -thr 43 -uthr 43 -bin -mul 51 -add appendputamen.rh appendputamen.rh # lateral ventricle rh
fslmaths aseg -thr  4 -uthr  4 -bin -mul 12 -add appendputamen.lh appendputamen.lh # lateral ventricle lh
fslmaths aseg -thr 58 -uthr 58 -bin -mul -32 -add aseg -thr 26 -uthr 26 -binv -mul aseg aseg.pial
fslmaths aseg.pial -thr 50 -uthr 50 -bin -mul -39 -add aseg.pial -thr 11 -uthr 11 -binv -mul aseg.pial aseg.pial
fslmaths aseg.pial -thr 43 -uthr 43 -bin -mul -39 -add aseg.pial -thr  4 -uthr  4 -binv -mul aseg.pial aseg.pial
fslmaths aseg.pial -add appendputamen.lh -add appendputamen.rh aseg.pial -odt char
mri_convert -ns 1 -odt uchar aseg.pial.nii.gz aseg.pial.mgz
mri_convert -rl "$mridir"/T1w_hires.nii.gz -rt nearest $mridir/aseg.pial.mgz $mridir/aseg.hires.pial.mgz
cd $DIR

#mris_make_surfaces -variablesigma "${VARIABLESIGMA}" -white NOWRITE -aseg aseg.hires -orig white.deformed -filled filled.hires -wm wm.hires -sdir "$SubjectDIR" -mgz -T1 T1w_hires.norm "$SubjectID" lh

log_Msg "mris_make_surface 1 using T1w hires"
# Note that adding "$MAXTHICKNESS" $MAXTHICKNESST1W may cause wrong inflation in the orbitral area but will be done in mris_make_surface T2w and 2nd T1w - TH Oct 2019
# $PSIGMA
mris_make_surfaces $MAXTHICKNESST1W -variablesigma $VARIABLESIGMA $PA -white NOWRITE -aseg aseg.hires.pial -orig white.deformed -filled filled.hires -wm wm.hires -sdir $SubjectDIR -mgz -T1 $T1wHires $SubjectID lh
mris_make_surfaces $MAXTHICKNESST1W -variablesigma $VARIABLESIGMA $PA -white NOWRITE -aseg aseg.hires.pial -orig white.deformed -filled filled.hires -wm wm.hires -sdir $SubjectDIR -mgz -T1 $T1wHires $SubjectID rh

cp $SubjectDIR/$SubjectID/surf/lh.pial $SubjectDIR/$SubjectID/surf/lh.pial.preT2
cp $SubjectDIR/$SubjectID/surf/rh.pial $SubjectDIR/$SubjectID/surf/rh.pial.preT2

if [ "$T2wFlag" != "NONE" ] ; then 

	log_Msg "mris_make_surface 1 using T2wHires"
	#For mris_make_surface with correct arguments #Could go from 3 to 2 potentially...
	# Added $MAXTHICKNESS $NSIGMA_ABOVE $PSIGMA $PA - TG Oct 2019
	mris_make_surfaces $MAXTHICKNESS $NSIGMA_ABOVE $PSIGMA $PA -aseg aseg.hires.pial -filled filled.hires -wm wm.hires -mgz -sdir $SubjectDIR -orig white.deformed -nowhite -orig_white white.deformed -orig_pial pial $T2wFlag $mridir/T2w_hires.norm -T1 $T1wHires -output .T2 $SubjectID lh
	mris_make_surfaces $MAXTHICKNESS $NSIGMA_ABOVE $PSIGMA $PA -aseg aseg.hires.pial -filled filled.hires -wm wm.hires -mgz -sdir $SubjectDIR -orig white.deformed -nowhite -orig_white white.deformed -orig_pial pial $T2wFlag $mridir/T2w_hires.norm -T1 $T1wHires -output .T2 $SubjectID rh
	
	mri_surf2surf --s $SubjectID --sval-xyz pial.T2 --reg $regII $mridir/orig.mgz --tval-xyz --tval pial --hemi lh
	mri_surf2surf --s $SubjectID --sval-xyz pial.T2 --reg $regII $mridir/orig.mgz --tval-xyz --tval pial --hemi rh

	# Second round
	log_Msg "Creating T1w_hires.graynorm"
	MatrixX=`mri_info $mridir/brain.finalsurfs.mgz | grep "c_r" | cut -d "=" -f 5 | sed s/" "/""/g`
	MatrixY=`mri_info $mridir/brain.finalsurfs.mgz | grep "c_a" | cut -d "=" -f 5 | sed s/" "/""/g`
	MatrixZ=`mri_info $mridir/brain.finalsurfs.mgz | grep "c_s" | cut -d "=" -f 5 | sed s/" "/""/g`
	echo "1 0 0 ""$MatrixX" > $mridir/c_ras.mat
	echo "0 1 0 ""$MatrixY" >> $mridir/c_ras.mat
	echo "0 0 1 ""$MatrixZ" >> $mridir/c_ras.mat
	echo "0 0 0 1" >> $mridir/c_ras.mat

	mris_convert "$surfdir"/lh.white "$surfdir"/lh.white.surf.gii
	${CARET7DIR}/wb_command -set-structure "$surfdir"/lh.white.surf.gii CORTEX_LEFT 
	${CARET7DIR}/wb_command -surface-apply-affine "$surfdir"/lh.white.surf.gii $mridir/c_ras.mat "$surfdir"/lh.white.surf.gii
	${CARET7DIR}/wb_command -create-signed-distance-volume "$surfdir"/lh.white.surf.gii "$mridir"/T1w_hires.nii.gz "$surfdir"/lh.white.nii.gz

	mris_convert "$surfdir"/lh.pial "$surfdir"/lh.pial.surf.gii
	${CARET7DIR}/wb_command -set-structure "$surfdir"/lh.pial.surf.gii CORTEX_LEFT 
	${CARET7DIR}/wb_command -surface-apply-affine "$surfdir"/lh.pial.surf.gii $mridir/c_ras.mat "$surfdir"/lh.pial.surf.gii
	${CARET7DIR}/wb_command -create-signed-distance-volume "$surfdir"/lh.pial.surf.gii "$mridir"/T1w_hires.nii.gz "$surfdir"/lh.pial.nii.gz

	mris_convert "$surfdir"/rh.white "$surfdir"/rh.white.surf.gii
	${CARET7DIR}/wb_command -set-structure "$surfdir"/rh.white.surf.gii CORTEX_RIGHT 
	${CARET7DIR}/wb_command -surface-apply-affine "$surfdir"/rh.white.surf.gii $mridir/c_ras.mat "$surfdir"/rh.white.surf.gii
	${CARET7DIR}/wb_command -create-signed-distance-volume "$surfdir"/rh.white.surf.gii "$mridir"/T1w_hires.nii.gz "$surfdir"/rh.white.nii.gz

	mris_convert "$surfdir"/rh.pial "$surfdir"/rh.pial.surf.gii
	${CARET7DIR}/wb_command -set-structure "$surfdir"/rh.pial.surf.gii CORTEX_RIGHT 
	${CARET7DIR}/wb_command -surface-apply-affine "$surfdir"/rh.pial.surf.gii $mridir/c_ras.mat "$surfdir"/rh.pial.surf.gii
	${CARET7DIR}/wb_command -create-signed-distance-volume "$surfdir"/rh.pial.surf.gii "$mridir"/T1w_hires.nii.gz "$surfdir"/rh.pial.nii.gz

	# Normalize T1w image for low spatial frequency variations in myelin content (especially to improve pial surface capture of very lightly myelinated cortex)
	#fslmaths "$surfdir"/lh.white.nii.gz -mul "$surfdir"/lh.pial.nii.gz -uthr 0 -mul -1 -bin "$mridir"/lh.ribbon.nii.gz
	#fslmaths "$surfdir"/rh.white.nii.gz -mul "$surfdir"/rh.pial.nii.gz -uthr 0 -mul -1 -bin "$mridir"/rh.ribbon.nii.gz
	# Avoid errors from (occational) positive values 'inside' the surface in the output of wb_command -create-signed-distance-volume in some cases
	fslmaths "$surfdir"/lh.pial.nii.gz -uthr 0 -abs -mul "$surfdir"/lh.white.nii.gz -thr 0 -bin "$mridir"/lh.ribbon.nii.gz
	fslmaths "$surfdir"/rh.pial.nii.gz -uthr 0 -abs -mul "$surfdir"/rh.white.nii.gz -thr 0 -bin "$mridir"/rh.ribbon.nii.gz

	fslmaths "$mridir"/lh.ribbon.nii.gz -add "$mridir"/rh.ribbon.nii.gz -bin "$mridir"/ribbon.nii.gz
	fslcpgeom "$mridir"/"$T1wHires".nii.gz "$mridir"/ribbon.nii.gz
	fslmaths "$mridir"/ribbon.nii.gz -s $Sigma "$mridir"/ribbon_s"$Sigma".nii.gz
	
	fslmaths "$mridir"/"$T1wHires".nii.gz -mas "$mridir"/ribbon.nii.gz "$mridir"/"$T1wHires"_ribbon.nii.gz
	greymean=`fslstats "$mridir"/"$T1wHires"_ribbon.nii.gz -M`
	fslmaths "$mridir"/ribbon.nii.gz -sub 1 -mul -1 "$mridir"/ribbon_inv.nii.gz

	fslmaths "$mridir"/"$T1wHires"_ribbon.nii.gz -s $Sigma -div "$mridir"/ribbon_s"$Sigma".nii.gz -div $greymean -mas "$mridir"/ribbon.nii.gz -add "$mridir"/ribbon_inv.nii.gz "$mridir"/"$T1wHires"_ribbon_myelin.nii.gz

	fslmaths "$surfdir"/lh.white.nii.gz -uthr 0 -mul -1 -bin "$mridir"/lh.white.nii.gz
	fslmaths "$surfdir"/rh.white.nii.gz -uthr 0 -mul -1 -bin "$mridir"/rh.white.nii.gz
	fslmaths "$mridir"/lh.white.nii.gz -add "$mridir"/rh.white.nii.gz -bin "$mridir"/white.nii.gz
	rm "$mridir"/lh.white.nii.gz "$mridir"/rh.white.nii.gz

	fslmaths "$mridir"/"$T1wHires"_ribbon_myelin.nii.gz -mas "$mridir"/ribbon.nii.gz -add "$mridir"/white.nii.gz -uthr 1.9 "$mridir"/"$T1wHires"_grey_myelin.nii.gz
	fslmaths "$mridir"/"$T1wHires"_grey_myelin.nii.gz -dilM -dilM -dilM -dilM -dilM "$mridir"/"$T1wHires"_grey_myelin.nii.gz
	fslmaths "$mridir"/"$T1wHires"_grey_myelin.nii.gz -binv "$mridir"/dilribbon_inv.nii.gz
	fslmaths "$mridir"/"$T1wHires"_grey_myelin.nii.gz -add "$mridir"/dilribbon_inv.nii.gz "$mridir"/"$T1wHires"_grey_myelin.nii.gz

	fslmaths "$mridir"/"$T1wHires".nii.gz -div "$mridir"/"$T1wHires"_ribbon_myelin.nii.gz "$mridir"/T1w_hires.greynorm_ribbon.nii.gz
	fslmaths "$mridir"/"$T1wHires".nii.gz -div "$mridir"/"$T1wHires"_grey_myelin.nii.gz "$mridir"/T1w_hires.greynorm.nii.gz

	mri_convert "$mridir"/T1w_hires.greynorm.nii.gz "$mridir"/T1w_hires.greynorm.mgz
	
	cp $SubjectDIR/$SubjectID/surf/lh.pial $SubjectDIR/$SubjectID/surf/lh.pial.one
	cp $SubjectDIR/$SubjectID/surf/rh.pial $SubjectDIR/$SubjectID/surf/rh.pial.one

	#Check if FreeSurfer is version 5.2.0 or not.  If it is not, use new -first_wm_peak mris_make_surfaces flag
	if [ -z `cat ${FREESURFER_HOME}/build-stamp.txt | grep v5.2.0` ] ; then
	  VARIABLESIGMA="4"
	else
	  VARIABLESIGMA="2"
	fi
	
	log_Msg "mris_make_surface 2 using T1w_hires.greynorm"
	# Marmoset data does not work well for the second round T1w-based pial estimation - pial is not inflated enough Takuya Hayashi Jan 2018
	# Added "$MAXTHICKNESS" "PSIGMA" "$MINGRAY", adding $MAXGRAY seems to result in segmentation errors -  Takuya Hayashi 2016/09/08
	# Added "-orig_pial pial.T2" for marmoset - Takuya Hayashi Sep 2019
	# Removed "$MAXTHICKNESS" "PSIGMA" "$MINGRAY", added $MAXTHICKNESST1W $PA, which decreased inflation in the orbitral area - TH Oct 2019 
	mris_make_surfaces $PSIGMA $PA $MAXTHICKNESST1W -variablesigma $VARIABLESIGMA -white NOWRITE -aseg aseg.hires.pial -orig white.deformed $ORIG_PIAL -filled filled.hires -wm wm.hires -sdir $SubjectDIR -mgz -T1 T1w_hires.greynorm $SubjectID lh 
	mris_make_surfaces $PSIGMA $PA $MAXTHICKNESST1W -variablesigma $VARIABLESIGMA -white NOWRITE -aseg aseg.hires.pial -orig white.deformed $ORIG_PIAL -filled filled.hires -wm wm.hires -sdir $SubjectDIR -mgz -T1 T1w_hires.greynorm $SubjectID rh

	cp $SubjectDIR/$SubjectID/surf/lh.pial $SubjectDIR/$SubjectID/surf/lh.pial.preT2.two
	cp $SubjectDIR/$SubjectID/surf/rh.pial $SubjectDIR/$SubjectID/surf/rh.pial.preT2.two

	#Could go from 3 to 2 potentially...
	log_Msg "mris_make_surface 2 using T2w_hires"
	# Added $MAXTHICKNESS $NSIGMA_ABOVE $PSIGMA $PA for fullly inflate pial - TH Oct 2019
	mris_make_surfaces $MAXTHICKNESS $NSIGMA_ABOVE $PSIGMA $PA -aseg aseg.hires.pial -filled filled.hires -wm wm.hires -mgz -sdir $SubjectDIR -orig white.deformed -nowhite -orig_white white.deformed -orig_pial pial $T2wFlag $mridir/T2w_hires.norm -T1 $T1wHires -output .T2.two $SubjectID lh
	mris_make_surfaces $MAXTHICKNESS $NSIGMA_ABOVE $PSIGMA $PA -aseg aseg.hires.pial -filled filled.hires -wm wm.hires -mgz -sdir $SubjectDIR -orig white.deformed -nowhite -orig_white white.deformed -orig_pial pial $T2wFlag $mridir/T2w_hires.norm -T1 $T1wHires -output .T2.two $SubjectID rh
	mri_surf2surf --s $SubjectID --sval-xyz pial.T2.two --reg $regII $mridir/orig.mgz --tval-xyz --tval pial --hemi lh
	mri_surf2surf --s $SubjectID --sval-xyz pial.T2.two --reg $regII $mridir/orig.mgz --tval-xyz --tval pial --hemi rh

	cp $SubjectDIR/$SubjectID/surf/lh.thickness $SubjectDIR/$SubjectID/surf/lh.thickness.preT2
	cp $SubjectDIR/$SubjectID/surf/rh.thickness $SubjectDIR/$SubjectID/surf/rh.thickness.preT2

	cp $SubjectDIR/$SubjectID/surf/lh.thickness.T2.two $SubjectDIR/$SubjectID/surf/lh.thickness
	cp $SubjectDIR/$SubjectID/surf/rh.thickness.T2.two $SubjectDIR/$SubjectID/surf/rh.thickness

	cp $SubjectDIR/$SubjectID/surf/lh.area.pial.T2.two $SubjectDIR/$SubjectID/surf/lh.area.pial
	cp $SubjectDIR/$SubjectID/surf/rh.area.pial.T2.two $SubjectDIR/$SubjectID/surf/rh.area.pial

	cp $SubjectDIR/$SubjectID/surf/lh.curv.pial.T2.two $SubjectDIR/$SubjectID/surf/lh.curv.pial
	cp $SubjectDIR/$SubjectID/surf/rh.curv.pial.T2.two $SubjectDIR/$SubjectID/surf/rh.curv.pial

else

	mri_surf2surf --s $SubjectID --sval-xyz pial.preT2 --reg $regII $mridir/orig.mgz --tval-xyz --tval pial --hemi lh
	mri_surf2surf --s $SubjectID --sval-xyz pial.preT2 --reg $regII $mridir/orig.mgz --tval-xyz --tval pial --hemi rh

fi

echo -e "\n END: FreeSurferHiresPial"
