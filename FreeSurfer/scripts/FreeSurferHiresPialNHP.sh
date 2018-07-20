#!/bin/bash
set -e
usage () {
echo "Usage: $0 <SubjectID> <SubjectDIR> <T1w_acpc_dc_restore or T1w_acpc_dc_restore_1mm> <T2w_acpc_dc_restore or T2w_acpc_dc_restore_1mm> <T2w | FLAIR | NONE> <Human | Macaque | Marmoset>"
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

# Species-dependent variables - Takuya Hayashi Sep 12, 2016
if  [ "`echo $SPECIES | grep Macaque`" != "" ] ; then 
	VARIABLESIGMA="10"
	MAXTHICKNESS="-max 10"
	PSIGMA="-psigma 5"
	NSIGMA_ABOVE="-nsigma_above 3"
#	NSIGMA_BELOW="-nsigma_below 2"
#	MINGRAY="-min_gray_at_csf_border 10"
#	MAXGRAY="-max_gray_at_csf_border 40"
elif [ "$SPECIES" = "Marmoset" ] ; then
	VARIABLESIGMA="8"  # 20
	MAXTHICKNESS="-max 20" # -max 40 is needed to inflate white enough to estimate pial
	PSIGMA="-psigma 10"    # pial_sigma default=2. 10 is needed to inflate pial enough 
	NSIGMA_ABOVE="-nsigma_above 7" # default=3 7 to 10 is needed to inflate pial enough
elif [ "$SPECIES" = "Human" ] ; then
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

# If marmoset, need to use brain.hires (bias-corrected with T1w*T2w, fast, mri_ca_normalize, mri_normalize) as T1w volume for correct pial in the first round. We also need to apply T1w biasfield to T2w, which suppresses overinflation of pial estimated by -T2dura - Takuya Hayashi Jan 2018
if [ "$SPECIES" != "Marmoset" ] ; then 
	T1wHires="T1w_hires.norm"; 
	fslmaths "$mridir"/T2w_hires.nii.gz -div `fslstats "$mridir"/T2w_hires.nii.gz -k "$mridir"/wm.hires.nii.gz -M` -mul 57 "$mridir"/T2w_hires.norm.nii.gz -odt float
else
	T1wHires="T1w_hires.masked.norm";
	mri_convert $mridir/"$T1wHires".mgz $mridir/"$T1wHires".nii.gz
	mri_convert -rl "$mridir"/T1w_hires.nii.gz -rt nearest "$mridir"/aseg.mgz "$mridir"/aseg.nii.gz
	mri_convert -rl "$mridir"/T1w_hires.nii.gz "$mridir"/orig.mgz "$mridir"/orig.nii.gz
	fslmaths "$mridir"/"$T1wHires".nii.gz -div  "$mridir"/orig.nii.gz -s 2 -mas "$mridir"/aseg.nii.gz -dilall "$mridir"/norm.biasfield.nii.gz
	# Assuming bias is same between T1w and T2w
	fslmaths "$mridir"/T2w_hires.nii.gz -div "$mridir"/norm.biasfield.nii.gz "$mridir"/T2w_hires.norm.nii.gz
	fslmaths "$mridir"/T2w_hires.norm.nii.gz -div `fslstats "$mridir"/T2w_hires.norm.nii.gz -k "$mridir"/wm.hires.nii.gz -M` -mul 57 "$mridir"/T2w_hires.norm.nii.gz -odt float
fi

mri_convert "$mridir"/T2w_hires.norm.nii.gz "$mridir"/T2w_hires.norm.mgz

#mris_make_surfaces -variablesigma "${VARIABLESIGMA}" -white NOWRITE -aseg aseg.hires -orig white.deformed -filled filled.hires -wm wm.hires -sdir "$SubjectDIR" -mgz -T1 T1w_hires.norm "$SubjectID" lh

log_Msg "mris_make_surface 1 using T1w hires"

mris_make_surfaces -variablesigma $VARIABLESIGMA $PSIGMA $MAXTHICKNESS $MINGRAY $MAXGRAY -white NOWRITE -aseg aseg.hires -orig white.deformed -filled filled.hires -wm wm.hires -sdir $SubjectDIR -T1 $T1wHires $SubjectID lh
mris_make_surfaces -variablesigma $VARIABLESIGMA $PSIGMA $MfTAXTHICKNESS $MINGRAY $MAXGRAY -white NOWRITE -aseg aseg.hires -orig white.deformed -filled filled.hires -wm wm.hires -sdir $SubjectDIR -T1 $T1wHires $SubjectID rh

cp $SubjectDIR/$SubjectID/surf/lh.pial $SubjectDIR/$SubjectID/surf/lh.pial.preT2
cp $SubjectDIR/$SubjectID/surf/rh.pial $SubjectDIR/$SubjectID/surf/rh.pial.preT2

if [ "$T2wFlag" != "NONE" ] ; then 

	log_Msg "mris_make_surface 1 using $T2wHires"
	#For mris_make_surface with correct arguments #Could go from 3 to 2 potentially...
	mris_make_surfaces $NSIGMA_ABOVE -aseg aseg.hires -filled filled.hires -wm wm.hires -mgz -sdir $SubjectDIR -orig white.deformed -nowhite -orig_white white.deformed -orig_pial pial $T2wFlag $mridir/T2w_hires.norm -T1 $T1wHires -output .T2 $SubjectID lh
	mris_make_surfaces $NSIGMA_ABOVE -aseg aseg.hires -filled filled.hires -wm wm.hires -mgz -sdir $SubjectDIR -orig white.deformed -nowhite -orig_white white.deformed -orig_pial pial $T2wFlag $mridir/T2w_hires.norm -T1 $T1wHires -output .T2 $SubjectID rh
	
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

	# marmoset data does not work well for the second round T1w-based pial estimation - pial is not inflated enough Takuya Hayashi Jan 2018
	log_Msg "mris_make_surface 2 using T1w_hires.greynorm"
	# Added "$MAXTHICKNESS" "PSIGMA" "$MINGRAY", adding $MAXGRAY seems to result in segmentation errors -  Takuya Hayashi 2016/09/08
	mris_make_surfaces -variablesigma $VARIABLESIGMA $MAXTHICKNESS $PSIGMA $MINGRAY -white NOWRITE -aseg aseg.hires -orig white.deformed -filled filled.hires -wm wm.hires -sdir $SubjectDIR -mgz -T1 T1w_hires.greynorm $SubjectID lh 
	mris_make_surfaces -variablesigma $VARIABLESIGMA $MAXTHICKNESS $PSIGMA $MINGRAY -white NOWRITE -aseg aseg.hires -orig white.deformed -filled filled.hires -wm wm.hires -sdir $SubjectDIR -mgz -T1 T1w_hires.greynorm  $SubjectID rh

	cp $SubjectDIR/$SubjectID/surf/lh.pial $SubjectDIR/$SubjectID/surf/lh.pial.preT2.two
	cp $SubjectDIR/$SubjectID/surf/rh.pial $SubjectDIR/$SubjectID/surf/rh.pial.preT2.two

	#Could go from 3 to 2 potentially...
	log_Msg "mris_make_surface 2 using T2w_hires"
	mris_make_surfaces -aseg aseg.hires -filled filled.hires -wm wm.hires -mgz -sdir $SubjectDIR -orig white.deformed -nowhite -orig_white white.deformed -orig_pial pial $T2wFlag $mridir/T2w_hires.norm -T1 $T1wHires -output .T2.two $SubjectID lh
	mris_make_surfaces -aseg aseg.hires -filled filled.hires -wm wm.hires -mgz -sdir $SubjectDIR -orig white.deformed -nowhite -orig_white white.deformed -orig_pial pial $T2wFlag $mridir/T2w_hires.norm -T1 $T1wHires -output .T2.two $SubjectID rh
	
	# Marmoset data does not work well for second round.
	if [ "$SPECIES" != Marmoset ] ; then
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
		mri_surf2surf --s $SubjectID --sval-xyz pial.T2 --reg $regII $mridir/orig.mgz --tval-xyz --tval pial --hemi lh
		mri_surf2surf --s $SubjectID --sval-xyz pial.T2 --reg $regII $mridir/orig.mgz --tval-xyz --tval pial --hemi rh

		cp $SubjectDIR/$SubjectID/surf/lh.thickness $SubjectDIR/$SubjectID/surf/lh.thickness.preT2
		cp $SubjectDIR/$SubjectID/surf/rh.thickness $SubjectDIR/$SubjectID/surf/rh.thickness.preT2

		cp $SubjectDIR/$SubjectID/surf/lh.thickness.T2 $SubjectDIR/$SubjectID/surf/lh.thickness
		cp $SubjectDIR/$SubjectID/surf/rh.thickness.T2 $SubjectDIR/$SubjectID/surf/rh.thickness

		cp $SubjectDIR/$SubjectID/surf/lh.area.pial.T2 $SubjectDIR/$SubjectID/surf/lh.area.pial
		cp $SubjectDIR/$SubjectID/surf/rh.area.pial.T2 $SubjectDIR/$SubjectID/surf/rh.area.pial

		cp $SubjectDIR/$SubjectID/surf/lh.curv.pial.T2 $SubjectDIR/$SubjectID/surf/lh.curv.pial
		cp $SubjectDIR/$SubjectID/surf/rh.curv.pial.T2 $SubjectDIR/$SubjectID/surf/rh.curv.pial

	fi

else

	mri_surf2surf --s $SubjectID --sval-xyz pial.preT2 --reg $regII $mridir/orig.mgz --tval-xyz --tval pial --hemi lh
	mri_surf2surf --s $SubjectID --sval-xyz pial.preT2 --reg $regII $mridir/orig.mgz --tval-xyz --tval pial --hemi rh

	cp $SubjectDIR/$SubjectID/surf/lh.thickness.preT2 $SubjectDIR/$SubjectID/surf/lh.thickness
	cp $SubjectDIR/$SubjectID/surf/rh.thickness.preT2 $SubjectDIR/$SubjectID/surf/rh.thickness

	cp $SubjectDIR/$SubjectID/surf/lh.area.pial.preT2 $SubjectDIR/$SubjectID/surf/lh.area.pial
	cp $SubjectDIR/$SubjectID/surf/rh.area.pial.preT2 $SubjectDIR/$SubjectID/surf/rh.area.pial

	cp $SubjectDIR/$SubjectID/surf/lh.curv.pial.preT2 $SubjectDIR/$SubjectID/surf/lh.curv.pial
	cp $SubjectDIR/$SubjectID/surf/rh.curv.pial.preT2 $SubjectDIR/$SubjectID/surf/rh.curv.pial

fi

echo -e "\n END: FreeSurferHiresPial"
