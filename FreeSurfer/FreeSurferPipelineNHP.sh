#!/bin/bash 
set -e

# Requirements for this script
#  installed versions of: FSL5.0.5 or higher , FreeSurfer (version 5.2 or higher) ,
#  environment: FSLDIR , FREESURFER_HOME , HCPPIPEDIR , CARET7DIR 

# make pipeline engine happy...
if [ $# -eq 1 ] ; then
    echo "Version unknown..."
    exit 0
fi

########################################## PIPELINE OVERVIEW ########################################## 

#TODO

########################################## OUTPUT DIRECTORIES ########################################## 

#TODO

# --------------------------------------------------------------------------------
#  Load Function Libraries
# --------------------------------------------------------------------------------

source $HCPPIPEDIR/global/scripts/log.shlib  # Logging related functions
source $HCPPIPEDIR/global/scripts/opts.shlib # Command line option functions

########################################## SUPPORT FUNCTIONS ########################################## 

# --------------------------------------------------------------------------------
#  Usage Description Function
# --------------------------------------------------------------------------------

show_usage() {
    echo "Usage information To Be Written"
    exit 1
}

# --------------------------------------------------------------------------------
#   Establish tool name for logging
# --------------------------------------------------------------------------------
log_SetToolName "FreeSurferPipeline.sh"

################################################## OPTION PARSING #####################################################

opts_ShowVersionIfRequested $@

if opts_CheckForHelpRequest $@; then
    show_usage
fi

log_Msg "Parsing Command Line Options"

# Input Variables
SubjectID=`opts_GetOpt1 "--subject" $@` #FreeSurfer Subject ID Name
SubjectDIR=`opts_GetOpt1 "--subjectDIR" $@` #Location to Put FreeSurfer Subject's Folder
T1wImage=`opts_GetOpt1 "--t1" $@` #T1w FreeSurfer Input for head (Full Resolution)
T1wImageBrain=`opts_GetOpt1 "--t1brain" $@` #T1w FreeSurfer Input for brain (Full Resolution)
T2wImage=`opts_GetOpt1 "--t2" $@` #T2w FreeSurfer Input for brain (Full Resolution)
recon_all_seed=`opts_GetOpt1 "--seed" $@`

#FSLinearTransform=`opts_GetOpt1 "--fslinear" $@`
GCAdir=`opts_GetOpt1 "--gcadir" $@` # Needed for NHP
RescaleVolumeTransform=`opts_GetOpt1 "--rescaletrans" $@` # Needed for NHP
AsegEdit=`opts_GetOpt1 "--asegedit" $@` # Needed to use aseg.edit.mgz 
ControlPoints=`opts_GetOpt1 "--controlpoints" $@` # Needed to use $SubjectID/tmp/control.dat, modified by Takuya Hayashi Nov 2017
WmEdit=`opts_GetOpt1 "--wmedit" $@` # Needed to use wm.edit.mgz, modified by Takuya Hayashi Nov 4th 2015
T2wFlag=`opts_GetOpt1 "--t2wflag" $@` # T2w, FLAIR or NONE for FreeSurferHiresPial.sh, inserted by Takuya Hayashi Nov 4th 2015
SPECIES=`opts_GetOpt1 "--species" $@` # Human, Macaque, Marmoset, inserted by Takuya Hayashi on Feb 13th 2016
RunMode=`opts_GetOpt1 "--runmode" $@`  # Run in step mode (0: run all (default), 1: FSinit, 2: FSaseg, 3: FSNormalize2, 4: FSwhiteandpial, 5: FSfinish)

if [ "$SPECIES" = "" ] ; then SPECIES=Human; fi

if [ "$SPECIES" = "Human" ] ; then GCAdir="${FREESURFER_HOME}/average";fi

# ------------------------------------------------------------------------------
#  Show Command Line Options
# ------------------------------------------------------------------------------

log_Msg "Finished Parsing Command Line Options"
log_Msg "SubjectID: ${SubjectID}"
log_Msg "SubjectDIR: ${SubjectDIR}"
log_Msg "T1wImage: ${T1wImage}"
log_Msg "T1wImageBrain: ${T1wImageBrain}"
log_Msg "T2wImage: ${T2wImage}"
log_Msg "recon_all_seed: ${recon_all_seed}"
log_Msg "GCAdir: ${GCAdir}"
log_Msg "AsegEdit: ${AsegEdit}"
log_Msg "ControlPoints: ${ControlPoints}"
log_Msg "WmEdit: ${WmEdit}"
log_Msg "T2wFlag: ${T2wFlag}"
log_Msg "SPECIES: ${SPECIES}"
log_Msg "RunMode: ${RunMode}"

# figure out whether to include a random seed generator seed in all the recon-all command lines
seed_cmd_appendix=""
if [ -z "${recon_all_seed}" ] ; then
	seed_cmd_appendix=""
else
	seed_cmd_appendix="-norandomness -rng-seed ${recon_all_seed}"
fi
log_Msg "seed_cmd_appendix: ${seed_cmd_appendix}"

# ------------------------------------------------------------------------------
#  Show Environment Variables
# ------------------------------------------------------------------------------

log_Msg "HCPPIPEDIR: ${HCPPIPEDIR}"
log_Msg "HCPPIPEDIR_FS: ${HCPPIPEDIR_FS}"

# ------------------------------------------------------------------------------
#  Identify Tools
# ------------------------------------------------------------------------------

which_flirt=`which flirt`
flirt_version=`flirt -version`
log_Msg "which flirt: ${which_flirt}"
log_Msg "flirt -version: ${flirt_version}"

which_applywarp=`which applywarp`
log_Msg "which applywarp: ${which_applywarp}"

which_fslstats=`which fslstats`
log_Msg "which fslstats: ${which_fslstats}"

which_fslmaths=`which fslmaths`
log_Msg "which fslmaths: ${which_fslmaths}"

which_recon_all=`which recon-all`
recon_all_version=`recon-all --version`
log_Msg "which recon-all: ${which_recon_all}"
log_Msg "recon-all --version: ${recon_all_version}"

which_mri_convert=`which mri_convert`
log_Msg "which mri_convert: ${which_mri_convert}"

which_mri_em_register=`which mri_em_register`
mri_em_register_version=`mri_em_register --version`
log_Msg "which mri_em_register: ${which_mri_em_register}"
log_Msg "mri_em_register --version: ${mri_em_register_version}"

which_mri_watershed=`which mri_watershed`
mri_watershed_version=`mri_watershed --version`
log_Msg "which mri_watershed: ${which_mri_watershed}"
log_Msg "mri_watershed --version: ${mri_watershed_version}"

# Start work

T1wImageFile=`remove_ext $T1wImage`;
T1wImageBrainFile=`remove_ext $T1wImageBrain`;
T2wImageFile=`remove_ext $T2wImage`;

PipelineScripts=${HCPPIPEDIR_FS}

export SUBJECTS_DIR="$SubjectDIR"

if [ -e "$SubjectDIR"/"$SubjectID"/scripts/IsRunning.lh+rh ] ; then
  rm "$SubjectDIR"/"$SubjectID"/scripts/IsRunning.lh+rh
<<<<<<< HEAD
elif [ -e "$SubjectDIR"/"$SubjectID"_1mm/scripts/IsRunning.lh+rh ] ; then
  rm "$SubjectDIR"/"$SubjectID"_1mm/scripts/IsRunning.lh+rh
fi

# Both the SGE and PBS cluster schedulers use the environment variable NSLOTS to indicate the number of cores
# a job will use.  If this environment variable is set, we will use it to determine the number of cores to
# tell recon-all to use.

if [ -z "${NSLOTS}" ] ; then
	num_cores=8
else
	#num_cores="${NSLOTS}"
	num_cores=8
fi
log_Msg "NSLOTS: ${NSLOTS}"
log_Msg "num_cores: ${num_cores}"

function runFSinit () {

	"$PipelineScripts"/MakeDimto1mm.sh $SPECIES "$T1wImage"
	"$PipelineScripts"/MakeDimto1mm.sh $SPECIES "$T1wImageBrain" nn
	"$PipelineScripts"/MakeDimto1mm.sh $SPECIES "$T2wImage"
	Mean=`fslstats $T1wImageBrain -M`
	fslmaths "$T1wImageFile"_1mm.nii.gz -div $Mean -mul 150 -abs "$T1wImageFile"_1mm.nii.gz

	#Initial Recon-all Steps
	if [ -e "$SubjectDIR"/"$SubjectID" ] ; then
 		rm -r "$SubjectDIR"/"$SubjectID"
	fi
	if [ -e "$SubjectDIR"/"$SubjectID"_1mm ] ; then
		rm -r "$SubjectDIR"/"$SubjectID"_1mm
	fi

	log_Msg "Initial recon-all steps"

	recon-all -i "$T1wImageFile"_1mm.nii.gz -subjid $SubjectID -sd $SubjectDIR -motioncor -openmp ${num_cores} ${seed_cmd_appendix}
	mri_convert "$T1wImageBrainFile"_1mm.nii.gz "$SubjectDIR"/"$SubjectID"/mri/brainmask.mgz --conform

	# Intensity Correction use nu_correct for human and fast for NHP  
	if [ "$SPECIES" != "Human" ] ; then 
	
		# Use fast instead of nu_correct (in mri_nu_correct.mni) for bias correction, since the former likely better sharpens the histogram.
       	"$PipelineScripts"/IntensityCor.sh "$SubjectDIR"/"$SubjectID"/mri/orig.mgz "$SubjectDIR"/"$SubjectID"/mri/brainmask.mgz \
		"$SubjectDIR"/"$SubjectID"/mri/nu.mgz $SPECIES
		recon-all -subjid $SubjectID -sd $SubjectDIR -normalization -openmp ${num_cores} ${seed_cmd_appendix}
		#mri_normalize -b 20 -n 5 -g 1 "$SubjectDIR"/"$SubjectID"/mri/nu.mgz "$SubjectDIR"/"$SubjectID"/mri/T1.mgz # MH's tuning for pediatric brain
		#mri_mask "$SubjectDIR"/"$SubjectID"/mri/T1.mgz "$SubjectDIR"/"$SubjectID"/mri/brainmask.mgz \
		#"$SubjectDIR"/"$SubjectID"/mri/brainmask.mgz

	else
		# Call recon-all with flags that are part of "-autorecon1", with the exception of -skullstrip.
		# -skullstrip of FreeSurfer not reliable for Phase II data because of poor FreeSurfer mri_em_register registrations with Skull on, 
		# so run registration with PreFreeSurfer masked data and then generate brain mask as usual.
		recon-all -subjid $SubjectID -sd $SubjectDIR -talairach -nuintensitycor -normalization -openmp ${num_cores} ${seed_cmd_appendix}

	fi

}

function runFSbrainmaskandseg () {

	# Generate brain mask
	export OMP_NUM_THREADS=${num_cores}
	if [ ! -e "$SubjectDIR"/"$SubjectID"/mri/brainmask.edit.mgz ] ; then
		mri_em_register "$SubjectDIR"/"$SubjectID"/mri/nu.mgz "$GCAdir"/RB_all_withskull_2008-03-26.gca \
		"$SubjectDIR"/"$SubjectID"/mri/transforms/talairach_with_skull.lta
		mri_watershed -T1 -brain_atlas "$GCAdir"/RB_all_withskull_2008-03-26.gca \
		"$SubjectDIR"/"$SubjectID"/mri/transforms/talairach_with_skull.lta "$SubjectDIR"/"$SubjectID"/mri/T1.mgz \
		"$SubjectDIR"/"$SubjectID"/mri/brainmask.auto.mgz
		cp "$SubjectDIR"/"$SubjectID"/mri/brainmask.auto.mgz "$SubjectDIR"/"$SubjectID"/mri/brainmask.mgz 
	else
		cp "$SubjectDIR"/"$SubjectID"/mri/brainmask.edit.mgz "$SubjectDIR"/"$SubjectID"/mri/brainmask.mgz 
	fi
		
	# Registration and normalization to GCA
	log_Msg "Second recon-all steps for registration and normaliztion to GCA"

	recon-all -subjid $SubjectID -sd $SubjectDIR -gcareg -canorm -careg -careginv -rmneck -skull-lta -gca-dir $GCAdir \
	-openmp ${num_cores} ${seed_cmd_appendix}
	cp "$SubjectDIR"/"$SubjectID"/mri/norm.mgz "$SubjectDIR"/"$SubjectID"/mri/norm.orig.mgz 

	log_Msg "Third recon-all steps for segmentation using GCA"
	# Segmentation with GCA
	DIR=`pwd`
	cd "$SubjectDIR"/"$SubjectID"/mri
	if [ "$AsegEdit" = "NONE" ] ; then
		mri_ca_label -align -nobigventricles -nowmsa norm.mgz transforms/talairach.m3z "$GCAdir"/RB_all_2008-03-26.gca aseg.auto_noCCseg.mgz
	fi
	cd $DIR
 
}

function runFSaseg () {

	DIR=`pwd`
	cd "$SubjectDIR"/"$SubjectID"/mri
	mri_cc -aseg aseg.auto_noCCseg.mgz -o aseg.auto.mgz -lta "$SubjectDIR"/"$SubjectID"/mri/transforms/cc_up.lta "$SubjectID"
	cp aseg.auto.mgz aseg+claustrum.mgz
	cp aseg.auto.mgz aseg.mgz
	cd $DIR

}	

function runNormalize2 () {

	log_Msg "Fourth recon-all steps for normalization2"

	recon-all -subjid $SubjectID -sd $SubjectDIR -normalization2
	#mri_normalize -b 20 -n 5 -aseg "$SubjectDIR"/"$SubjectID"/mri/aseg.mgz -mask "$SubjectDIR"/"$SubjectID"/mri/brainmask.mgz \
	#"$SubjectDIR"/"$SubjectID"/mri/norm.mgz "$SubjectDIR"/"$SubjectID"/mri/brain.mgz # MH's tuning for pediatric brain

	recon-all -subjid $SubjectID -sd $SubjectDIR -maskbfs -segmentation

	## Paste claustrum to wm.mgz - Takuya Hayashi, Oct 2017 
	DIR=`pwd`
	cd "$SubjectDIR"/"$SubjectID"/mri
	cp wm.mgz wm.orig.mgz
	mri_convert wm.mgz wm.nii.gz
	mri_convert aseg+claustrum.mgz aseg+claustrum.nii.gz 
	fslmaths aseg+claustrum.nii.gz -thr 138 -uthr 138 -bin -add aseg+claustrum.nii.gz -thr 139 -uthr 139 -bin -mul 250 \
	-max wm.nii.gz wm.nii.gz # pasting claustrum to wm.mgz
	## deweight cortical gray in wm.mgz to remove prunning of white surface into gray - Takuya Hayahsi Dec 2017
	if [ "$ControlPoints" = "NONE" ] ; then
		fslmaths aseg+claustrum.nii.gz -thr 42 -uthr 42 -bin -mul -39 -add aseg+claustrum.nii.gz -thr 3 -uthr 3 -bin -s 0.25 -sub 1 -mul -1 \
		-mul wm.nii.gz -thr 50 wm.nii.gz -odt char
	fi
	mri_convert -ns 1 -odt uchar wm.nii.gz wm.mgz  # save in 8-bit
	cd $DIR

}

function runFSwhite () {

	## Replace claustrum by putamen in aseg for accurate white surface estimation with mris_make_surface - Takuya Hayashi, Oct 2017
	DIR=`pwd`
	cd "$SubjectDIR"/"$SubjectID"/mri
	fslmaths aseg+claustrum.nii.gz -thr 139 -uthr 139 -bin -mul 51 claustrum2putamen.rh
	fslmaths aseg+claustrum.nii.gz -thr 138 -uthr 138 -bin -mul 12 claustrum2putamen.lh
	fslmaths aseg+claustrum.nii.gz -thr 138 -uthr 138 -bin -add aseg+claustrum.nii.gz -thr 139 -uthr 139 -binv \
	-mul aseg+claustrum.nii.gz -add claustrum2putamen.lh.nii.gz -add claustrum2putamen.rh.nii.gz aseg.nii.gz -odt char
	mri_convert -ns 1 -odt uchar aseg.nii.gz aseg.mgz
	cd $DIR

	log_Msg "Fifth recon-all steps for white"
	recon-all -subjid $SubjectID -sd $SubjectDIR -fill -tessellate -smooth1 -inflate1 -qsphere -fix -white \
	-openmp ${num_cores} ${seed_cmd_appendix}

	# Highres and white stuffs and fine-tune T2w to T1w Reg

	log_Msg "High resolution white matter and fine tune T2w to T1w registration"
	if [ "$SPECIES" != "Human" ] ; then
		# Modified HiresWhite - Takuya Hayashi for bias-correction of T1w, Jan 2017
		"$PipelineScripts"/FreeSurferHiresWhiteNHP.sh "$SubjectID" "$SubjectDIR" "$T1wImageFile"_1mm.nii.gz \
		"$T2wImageFile"_1mm.nii.gz $SPECIES 
	else
		"$PipelineScripts"/FreeSurferHiresWhite.sh "$SubjectID" "$SubjectDIR" "$T1wImage" "$T2wImage"
	fi

	#Intermediate Recon-all Steps
	log_Msg "Sixth recon-all steps"
	if [ "$SPECIES" != "Human" ] ; then
		CurvStats=""
		AvgCurv=""
	else
		CurvStats="-curvstats"
		AvgCurv="-avgcurv"
	fi
	recon-all -subjid $SubjectID -sd $SubjectDIR -smooth2 -inflate2 $CurvStats -sphere 

}

function runFSsurfreg () {

	log_Msg "Surface registration"
	# Marmoset needs to contrain surface registration in FS - Takuya Hayashi Jan 2018
	if [ "$SPECIES" = Marmoset ] ; then
		dist="-dist 20";
		max_degrees="-max_degrees 50";
	else
		dist=""; # Default is 5
		max_degrees="";  # Default is 68
	fi
	DIR=`pwd`
	cd "$SubjectDIR"/"$SubjectID"/surf
	for hemi in lh rh; do
		mris_register -curv $dist $max_degrees ${hemi}.sphere $GCAdir/${hemi}.average.curvature.filled.buckner40.tif ${hemi}.sphere.reg
	done
	cd $DIR

	log_Msg "Seventh recon-all steps"
	if [ "$SPECIES" != "Human" ] ; then
		AvgCurv=""
	else
		AvgCurv="-avgcurv"
	fi
	recon-all -subjid $SubjectID -sd $SubjectDIR -jacobian_white $AvgCurv -cortparc

}

function runFSpial () {

	#Highres pial stuff (this module adjusts the pial surface based on the the T2w image)
	log_Msg "High resolution pial surface"
	if [ "$SPECIES" != "Human" ] ; then
		# Modified HiresPial - Takuya Hayashi for bias-correction of T2w, Jan 2017
		"$PipelineScripts"/FreeSurferHiresPialNHP.sh "$SubjectID" "$SubjectDIR" "$T1wImageFile"_1mm.nii.gz \
		"$T2wImageFile"_1mm.nii.gz "$T2wFlag" "$SPECIES"
	else
		"$PipelineScripts"/FreeSurferHiresPial.sh "$SubjectID" "$SubjectDIR" "$T1wImage" "$T2wImage" "$MaxThickness"
	fi

	#Final Recon-all Steps
	log_Msg "Final recon-all steps"
	if [ "$SPECIES" != "Human" ] ; then
		cp "$SubjectDIR"/"$SubjectID"/mri/aseg.mgz "$SubjectDIR"/"$SubjectID"/mri/wmparc.mgz
	else
		recon-all -subjid $SubjectID -sd $SubjectDIR -surfvolume -parcstats -cortparc2 -parcstats2 -cortparc3 -parcstats3 -cortribbon \
		-segstats -aparc2aseg -wmparc -balabels -label-exvivo-ec -openmp ${num_cores} ${seed_cmd_appendix}
	fi

}

function runFSfinish () {

if [ "$SPECIES" != "Human" ] ; then

	log_Msg "Rescale volume and surface to native space"
	# RescaleVolumeTransform=${HCPPIPEDIR}/global/templates/fs_xfms/${SPECIES}_rescale
	mv "$SubjectDIR"/"$SubjectID" "$SubjectDIR"/"$SubjectID"_1mm
	mkdir -p "$SubjectDIR"/"$SubjectID"/mri
	mkdir -p "$SubjectDIR"/"$SubjectID"/mri/transforms
	mkdir -p "$SubjectDIR"/"$SubjectID"/surf
	mkdir -p "$SubjectDIR"/"$SubjectID"/label
	"$PipelineScripts"/RescaleVolumeAndSurface.sh "$SubjectDIR" "$SubjectID" "$RescaleVolumeTransform" "$T1wImage"

fi

exit 0;

}

function main {

if   [ "$RunMode" = "0" ] ; then 

	runFSinit;runFSbrainmaskandseg;runFSaseg;runNormalize2;runFSwhite;runFSsurfreg;runFSpial;runFSfinish;

elif [ "$RunMode" = "1" ] ; then

	runFSinit;runFSbrainmaskandseg;runFSaseg;runNormalize2;runFSwhite;runFSsurfreg;runFSpial;runFSfinish;

elif [ "$RunMode" = "2" ] ; then

	runFSbrainmaskandseg;runFSaseg;runNormalize2;runFSwhite;runFSsurfreg;runFSpial;runFSfinish;

elif [ "$RunMode" = "3" ] ; then

	if [ "$AsegEdit" != "NONE" ] ; then
		cp $AsegEdit "$SubjectDIR"/"$SubjectID"/mri/aseg.auto_noCCseg.mgz
	fi
	runFSaseg;runNormalize2;runFSwhite;runFSsurfreg;runFSpial;runFSfinish;

elif [ "$RunMode" = "4" ] ; then

	if [ "$ControlPoints" != "NONE" ] ; then
		mkdir -p "$SubjectDIR"/"$SubjectID"/tmp
		cp "$ControlPoints" "$SubjectDIR"/"$SubjectID"/tmp/control.dat
		# the following line is to suppress error in mris_fix_toplogy
		for i in lh.curv rh.curv ; do if [ -e "$SubjectDIR"/"$SubjectID"/surf/$i ] ; then rm "$SubjectDIR"/"$SubjectID"/surf/$i ;fi;done 
	fi
	runNormalize2;runFSwhite;runFSsurfreg;runFSpial;runFSfinish;
	rm -rf "$SubjectDIR"/"$SubjectID"/tmp/control.dat

elif [ "$RunMode" = "5" ] ; then

	if [ "$WmEdit" != "NONE" ] ; then
		cp $WmEdit "$SubjectDIR"/"$SubjectID"/mri/wm.mgz 
	fi
	runFSwhite;runFSsurfreg;runFSpial;runFSfinish;

elif [ "$RunMode" = "6" ] ; then

	runFSsurfreg;runFSpial;runFSfinish;

elif [ "$RunMode" = "7" ] ; then

	runFSfinish;

fi

}

main;
=======
fi

### DELETE IF NOT USING ###
#if [ -e "$SubjectDIR"/"$SubjectID" ] ; then
#  rm -r "$SubjectDIR"/"$SubjectID"
#fi

#mv "$SubjectDIR"/"$SubjectID"_1mm "$SubjectDIR"/"$SubjectID"
### DELETE IF NOT USING ###
#function comment {

#Make Spline Interpolated Downsample to 1mm
Mean=`fslstats $T1wImageBrain -M`
res=`fslorient -getsform $T1wImage | cut -d " " -f 1 | cut -d "-" -f 2`
oldsform=`fslorient -getsform $T1wImage`
newsform=""
i=1
while [ $i -le 12 ] ; do
  oldelement=`echo $oldsform | cut -d " " -f $i`
  newelement=`echo "scale=1; $oldelement / $res" | bc -l`
  newsform=`echo "$newsform""$newelement"" "`
  if [ $i -eq 4 ] ; then
    originx="$newelement"
  fi
  if [ $i -eq 8 ] ; then
    originy="$newelement"
  fi
  if [ $i -eq 12 ] ; then
    originz="$newelement"
  fi
  i=$(($i+1))
done
newsform=`echo "$newsform""0 0 0 1" | sed 's/  / /g'`

cp "$T1wImage" "$T1wImageFile"_1mm.nii.gz
fslorient -setsform $newsform "$T1wImageFile"_1mm.nii.gz
fslhd -x "$T1wImageFile"_1mm.nii.gz | sed s/"dx = '${res}'"/"dx = '1'"/g | sed s/"dy = '${res}'"/"dy = '1'"/g | sed s/"dz = '${res}'"/"dz = '1'"/g | fslcreatehd - "$T1wImageFile"_1mm_head.nii.gz
fslmaths "$T1wImageFile"_1mm_head.nii.gz -add "$T1wImageFile"_1mm.nii.gz "$T1wImageFile"_1mm.nii.gz
fslorient -copysform2qform "$T1wImageFile"_1mm.nii.gz
rm "$T1wImageFile"_1mm_head.nii.gz
dimex=`fslval "$T1wImageFile"_1mm dim1`
dimey=`fslval "$T1wImageFile"_1mm dim2`
dimez=`fslval "$T1wImageFile"_1mm dim3`
padx=`echo "(256 - $dimex) / 2" | bc`
pady=`echo "(256 - $dimey) / 2" | bc`
padz=`echo "(256 - $dimez) / 2" | bc`
fslcreatehd $padx $dimey $dimez 1 1 1 1 1 0 0 0 16 "$T1wImageFile"_1mm_padx
fslmerge -x "$T1wImageFile"_1mm "$T1wImageFile"_1mm_padx "$T1wImageFile"_1mm "$T1wImageFile"_1mm_padx
fslcreatehd 256 $pady $dimez 1 1 1 1 1 0 0 0 16 "$T1wImageFile"_1mm_pady
fslmerge -y "$T1wImageFile"_1mm "$T1wImageFile"_1mm_pady "$T1wImageFile"_1mm "$T1wImageFile"_1mm_pady
fslcreatehd 256 256 $padz 1 1 1 1 1 0 0 0 16 "$T1wImageFile"_1mm_padz
fslmerge -z "$T1wImageFile"_1mm "$T1wImageFile"_1mm_padz "$T1wImageFile"_1mm "$T1wImageFile"_1mm_padz
fslorient -setsformcode 1 "$T1wImageFile"_1mm
fslorient -setsform -1 0 0 `echo "$originx + $padx" | bc -l` 0 1 0 `echo "$originy - $pady" | bc -l` 0 0 1 `echo "$originz - $padz" | bc -l` 0 0 0 1 "$T1wImageFile"_1mm
rm "$T1wImageFile"_1mm_padx.nii.gz "$T1wImageFile"_1mm_pady.nii.gz "$T1wImageFile"_1mm_padz.nii.gz

cp "$T2wImage" "$T2wImageFile"_1mm.nii.gz
fslorient -setsform $newsform "$T2wImageFile"_1mm.nii.gz
fslhd -x "$T2wImageFile"_1mm.nii.gz | sed s/"dx = '${res}'"/"dx = '1'"/g | sed s/"dy = '${res}'"/"dy = '1'"/g | sed s/"dz = '${res}'"/"dz = '1'"/g | fslcreatehd - "$T2wImageFile"_1mm_head.nii.gz
fslmaths "$T2wImageFile"_1mm_head.nii.gz -add "$T2wImageFile"_1mm.nii.gz "$T2wImageFile"_1mm.nii.gz
fslorient -copysform2qform "$T2wImageFile"_1mm.nii.gz
rm "$T2wImageFile"_1mm_head.nii.gz
dimex=`fslval "$T2wImageFile"_1mm dim1`
dimey=`fslval "$T2wImageFile"_1mm dim2`
dimez=`fslval "$T2wImageFile"_1mm dim3`
padx=`echo "(256 - $dimex) / 2" | bc`
pady=`echo "(256 - $dimey) / 2" | bc`
padz=`echo "(256 - $dimez) / 2" | bc`
fslcreatehd $padx $dimey $dimez 1 1 1 1 1 0 0 0 16 "$T2wImageFile"_1mm_padx
fslmerge -x "$T2wImageFile"_1mm "$T2wImageFile"_1mm_padx "$T2wImageFile"_1mm "$T2wImageFile"_1mm_padx
fslcreatehd 256 $pady $dimez 1 1 1 1 1 0 0 0 16 "$T2wImageFile"_1mm_pady
fslmerge -y "$T2wImageFile"_1mm "$T2wImageFile"_1mm_pady "$T2wImageFile"_1mm "$T2wImageFile"_1mm_pady
fslcreatehd 256 256 $padz 1 1 1 1 1 0 0 0 16 "$T2wImageFile"_1mm_padz
fslmerge -z "$T2wImageFile"_1mm "$T2wImageFile"_1mm_padz "$T2wImageFile"_1mm "$T2wImageFile"_1mm_padz
fslorient -setsformcode 1 "$T2wImageFile"_1mm
fslorient -setsform -1 0 0 `echo "$originx + $padx" | bc -l` 0 1 0 `echo "$originy - $pady" | bc -l` 0 0 1 `echo "$originz - $padz" | bc -l` 0 0 0 1 "$T2wImageFile"_1mm
rm "$T2wImageFile"_1mm_padx.nii.gz "$T2wImageFile"_1mm_pady.nii.gz "$T2wImageFile"_1mm_padz.nii.gz
#in FSL, matrix is identity, will not be in other conventions
fslmaths "$T1wImageFile"_1mm.nii.gz -div $Mean -mul 150 -abs "$T1wImageFile"_1mm.nii.gz

#Initial Recon-all Steps
if [ -e "$SubjectDIR"/"$SubjectID" ] ; then
  rm -r "$SubjectDIR"/"$SubjectID"
fi
if [ -e "$SubjectDIR"/"$SubjectID"_1mm ] ; then
  rm -r "$SubjectDIR"/"$SubjectID"_1mm
fi
recon-all -i "$T1wImageFile"_1mm.nii.gz -subjid $SubjectID -sd $SubjectDIR -motioncor 

#Copy in linear transformation matrices
#cp "$FSLinearTransform" "$SubjectDIR"/"$SubjectID"/mri/transforms/talairach.xfm
#tkregister2 --noedit --check-reg --mov "$SubjectDIR"/"$SubjectID"/mri/orig.mgz --targ "$FREESURFER_HOME"/average/mni305.cor.mgz --xfm "$SubjectDIR"/"$SubjectID"/mri/transforms/talairach.xfm --ltaout "$SubjectDIR"/"$SubjectID"/mri/transforms/talairach.lta
#cp "$SubjectDIR"/"$SubjectID"/mri/transforms/talairach.lta "$SubjectDIR"/"$SubjectID"/mri/transforms/talairach_with_skull.lta 
#cp "$SubjectDIR"/"$SubjectID"/mri/transforms/talairach.lta "$SubjectDIR"/"$SubjectID"/mri/transforms/talairach_with_skull_2.lta 

cp "$SubjectDIR"/"$SubjectID"/mri/orig.mgz "$SubjectDIR"/"$SubjectID"/mri/nu.mgz

recon-all -subjid $SubjectID -sd $SubjectDIR -normalization 

#Copy over brainmask, later, consider replacing with skull GCA
cp "$SubjectDIR"/"$SubjectID"/mri/T1.mgz "$SubjectDIR"/"$SubjectID"/mri/brainmask.mgz

recon-all -subjid $SubjectID -sd $SubjectDIR -gcareg -gca-dir $GCAdir #-openmp 12
cp "$SubjectDIR"/"$SubjectID"/mri/transforms/talairach.lta "$SubjectDIR"/"$SubjectID"/mri/transforms/talairach_with_skull.lta 
cp "$SubjectDIR"/"$SubjectID"/mri/transforms/talairach.lta "$SubjectDIR"/"$SubjectID"/mri/transforms/talairach_with_skull_2.lta 

#Replace with Chimp GCA
recon-all -subjid $SubjectID -sd $SubjectDIR -canorm -gca-dir $GCAdir #-openmp 12

#Replace with Chimp GCA
recon-all -subjid $SubjectID -sd $SubjectDIR -careg -gca-dir $GCAdir #-openmp 12

#Replace with Chimp GCA
recon-all -subjid $SubjectID -sd $SubjectDIR -careginv -gca-dir $GCAdir

#Replace with Chimp GCA
#recon-all -subjid $SubjectID -sd $SubjectDIR -calabel -gca-dir $GCAdir 

if [ $AsegEdit = "NONE" ] ; then
  DIR=`pwd`
  cd "$SubjectDIR"/"$SubjectID"/mri
  mri_ca_label -align -nobigventricles -nowmsa norm.mgz transforms/talairach.m3z "$GCAdir"/RB_all_2008-03-26.gca aseg.auto_noCCseg.mgz
  mri_cc -aseg aseg.auto_noCCseg.mgz -o aseg.auto.mgz -lta "$SubjectDIR"/"$SubjectID"/mri/transforms/cc_up.lta "$SubjectID"
  cp aseg.auto.mgz aseg.mgz
  cd $DIR
else
  cp $AsegEdit "$SubjectDIR"/"$SubjectID"/mri/aseg.mgz
  cp $AsegEdit "$SubjectDIR"/"$SubjectID"/mri/aseg.auto_noCCseg.mgz
fi

#recon-all -subjid $SubjectID -sd $SubjectDIR -normalization2 -maskbfs -segmentation -fill -tessellate -smooth1 -inflate1 -qsphere -fix
cp "$SubjectDIR"/"$SubjectID"/mri/norm.mgz "$SubjectDIR"/"$SubjectID"/mri/brain.mgz 
recon-all -subjid $SubjectID -sd $SubjectDIR -maskbfs -segmentation -fill -tessellate -smooth1 -inflate1 -qsphere -fix 


recon-all -subjid $SubjectID -sd $SubjectDIR -white 

#Issues with transform?
#Highres white stuff and Fine Tune T2w to T1w Reg
"$PipelineScripts"/FreeSurferHiresWhite.sh "$SubjectID" "$SubjectDIR" "$T1wImageFile"_1mm.nii.gz "$T2wImageFile"_1mm.nii.gz

#Intermediate Recon-all Steps
recon-all -subjid $SubjectID -sd $SubjectDIR -smooth2 -inflate2 -sphere #-openmp 12
#}
#Surface Reg To Chimp Template
recon-all -subjid $SubjectID -sd $SubjectDIR -surfreg -avgcurvtifpath $GCAdir #-openmp 12

#More Intermediate Recon-all Steps
recon-all -subjid $SubjectID -sd $SubjectDIR -jacobian_white 

#Is this step needed or could something else, like ?h.cortex.label, be substuted in for cortex label for pial surface
recon-all -subjid $SubjectID -sd $SubjectDIR -cortparc 

#Issues with transform?
#Highres pial stuff (this module adjusts the pial surface based on the the T2w image)
"$PipelineScripts"/FreeSurferHiresPial.sh "$SubjectID" "$SubjectDIR" "$T1wImageFile"_1mm.nii.gz "$T2wImageFile"_1mm.nii.gz "$maxThickness"

cp "$SubjectDIR"/"$SubjectID"/mri/aseg.mgz "$SubjectDIR"/"$SubjectID"/mri/wmparc.mgz

mv "$SubjectDIR"/"$SubjectID" "$SubjectDIR"/"$SubjectID"_1mm
mkdir -p "$SubjectDIR"/"$SubjectID"/mri
mkdir -p "$SubjectDIR"/"$SubjectID"/mri/transforms
mkdir -p "$SubjectDIR"/"$SubjectID"/surf
mkdir -p "$SubjectDIR"/"$SubjectID"/label
#}
#Bad interpolation
mri_convert -rt cubic -at "$RescaleVolumeTransform".xfm -rl "$T1wImage" "$SubjectDIR"/"$SubjectID"_1mm/mri/rawavg.mgz "$SubjectDIR"/"$SubjectID"/mri/rawavg.mgz
mri_convert "$SubjectDIR"/"$SubjectID"/mri/rawavg.mgz "$SubjectDIR"/"$SubjectID"/mri/rawavg.nii.gz
mri_convert -rt nearest -at "$RescaleVolumeTransform".xfm -rl "$T1wImage" "$SubjectDIR"/"$SubjectID"_1mm/mri/wmparc.mgz "$SubjectDIR"/"$SubjectID"/mri/wmparc.mgz
mri_convert -rt nearest -at "$RescaleVolumeTransform".xfm -rl "$T1wImage" "$SubjectDIR"/"$SubjectID"_1mm/mri/brain.finalsurfs.mgz "$SubjectDIR"/"$SubjectID"/mri/brain.finalsurfs.mgz
mri_convert -rt cubic -at "$RescaleVolumeTransform".xfm -rl "$T1wImage" "$SubjectDIR"/"$SubjectID"_1mm/mri/orig.mgz "$SubjectDIR"/"$SubjectID"/mri/orig.mgz

mri_convert -rl "$SubjectDIR"/"$SubjectID"_1mm/mri/rawavg.mgz "$SubjectDIR"/"$SubjectID"_1mm/mri/wmparc.mgz "$SubjectDIR"/"$SubjectID"_1mm/mri/wmparc.nii.gz
mri_convert -rl "$SubjectDIR"/"$SubjectID"_1mm/mri/rawavg.mgz "$SubjectDIR"/"$SubjectID"_1mm/mri/brain.finalsurfs.mgz "$SubjectDIR"/"$SubjectID"_1mm/mri/brain.finalsurfs.nii.gz
mri_convert -rl "$SubjectDIR"/"$SubjectID"_1mm/mri/rawavg.mgz "$SubjectDIR"/"$SubjectID"_1mm/mri/orig.mgz "$SubjectDIR"/"$SubjectID"_1mm/mri/orig.nii.gz

applywarp --interp=nn -i "$SubjectDIR"/"$SubjectID"_1mm/mri/wmparc.nii.gz -r "$SubjectDIR"/"$SubjectID"/mri/rawavg.nii.gz --premat="$RescaleVolumeTransform".mat -o "$SubjectDIR"/"$SubjectID"/mri/wmparc.nii.gz
applywarp --interp=nn -i "$SubjectDIR"/"$SubjectID"_1mm/mri/brain.finalsurfs.nii.gz -r "$SubjectDIR"/"$SubjectID"/mri/rawavg.nii.gz --premat="$RescaleVolumeTransform".mat -o "$SubjectDIR"/"$SubjectID"/mri/brain.finalsurfs.nii.gz
applywarp --interp=nn -i "$SubjectDIR"/"$SubjectID"_1mm/mri/orig.nii.gz -r "$SubjectDIR"/"$SubjectID"/mri/rawavg.nii.gz --premat="$RescaleVolumeTransform".mat -o "$SubjectDIR"/"$SubjectID"/mri/orig.nii.gz

mri_convert "$SubjectDIR"/"$SubjectID"/mri/wmparc.nii.gz "$SubjectDIR"/"$SubjectID"/mri/wmparc.mgz
mri_convert "$SubjectDIR"/"$SubjectID"/mri/brain.finalsurfs.nii.gz "$SubjectDIR"/"$SubjectID"/mri/brain.finalsurfs.mgz
mri_convert "$SubjectDIR"/"$SubjectID"/mri/orig.nii.gz "$SubjectDIR"/"$SubjectID"/mri/orig.mgz

mri_surf2surf --s "$SubjectID"_1mm --sval-xyz white --reg-inv "$RescaleVolumeTransform".dat "$SubjectDIR"/"$SubjectID"/mri/brain.finalsurfs.mgz --tval-xyz --tval white_temp --hemi lh
mv "$SubjectDIR"/"$SubjectID"_1mm/surf/lh.white_temp "$SubjectDIR"/"$SubjectID"/surf/lh.white
mri_surf2surf --s "$SubjectID"_1mm --sval-xyz white --reg-inv "$RescaleVolumeTransform".dat "$SubjectDIR"/"$SubjectID"/mri/brain.finalsurfs.mgz --tval-xyz --tval white_temp --hemi rh
mv "$SubjectDIR"/"$SubjectID"_1mm/surf/rh.white_temp "$SubjectDIR"/"$SubjectID"/surf/rh.white
mri_surf2surf --s "$SubjectID"_1mm --sval-xyz pial --reg-inv "$RescaleVolumeTransform".dat "$SubjectDIR"/"$SubjectID"/mri/brain.finalsurfs.mgz --tval-xyz --tval pial_temp --hemi lh
mv "$SubjectDIR"/"$SubjectID"_1mm/surf/lh.pial_temp "$SubjectDIR"/"$SubjectID"/surf/lh.pial
mri_surf2surf --s "$SubjectID"_1mm --sval-xyz pial --reg-inv "$RescaleVolumeTransform".dat "$SubjectDIR"/"$SubjectID"/mri/brain.finalsurfs.mgz --tval-xyz --tval pial_temp --hemi rh
mv "$SubjectDIR"/"$SubjectID"_1mm/surf/rh.pial_temp "$SubjectDIR"/"$SubjectID"/surf/rh.pial

mri_surf2surf --s "$SubjectID"_1mm --sval-xyz white.deformed --reg-inv "$RescaleVolumeTransform".dat "$SubjectDIR"/"$SubjectID"/mri/brain.finalsurfs.mgz --tval-xyz --tval white.deformed_temp --hemi lh
mv "$SubjectDIR"/"$SubjectID"_1mm/surf/lh.white.deformed_temp "$SubjectDIR"/"$SubjectID"/surf/lh.white.deformed
mri_surf2surf --s "$SubjectID"_1mm --sval-xyz white.deformed --reg-inv "$RescaleVolumeTransform".dat "$SubjectDIR"/"$SubjectID"/mri/brain.finalsurfs.mgz --tval-xyz --tval white.deformed_temp --hemi rh
mv "$SubjectDIR"/"$SubjectID"_1mm/surf/rh.white.deformed_temp "$SubjectDIR"/"$SubjectID"/surf/rh.white.deformed


cp "$SubjectDIR"/"$SubjectID"_1mm/surf/lh.sphere "$SubjectDIR"/"$SubjectID"/surf/lh.sphere
cp "$SubjectDIR"/"$SubjectID"_1mm/surf/rh.sphere "$SubjectDIR"/"$SubjectID"/surf/rh.sphere
cp "$SubjectDIR"/"$SubjectID"_1mm/surf/lh.sphere.reg "$SubjectDIR"/"$SubjectID"/surf/lh.sphere.reg
cp "$SubjectDIR"/"$SubjectID"_1mm/surf/rh.sphere.reg "$SubjectDIR"/"$SubjectID"/surf/rh.sphere.reg
cp "$SubjectDIR"/"$SubjectID"_1mm/surf/lh.curv "$SubjectDIR"/"$SubjectID"/surf/lh.curv
cp "$SubjectDIR"/"$SubjectID"_1mm/surf/rh.curv "$SubjectDIR"/"$SubjectID"/surf/rh.curv
cp "$SubjectDIR"/"$SubjectID"_1mm/surf/lh.sulc "$SubjectDIR"/"$SubjectID"/surf/lh.sulc
cp "$SubjectDIR"/"$SubjectID"_1mm/surf/rh.sulc "$SubjectDIR"/"$SubjectID"/surf/rh.sulc

cp "$SubjectDIR"/"$SubjectID"_1mm/label/lh.cortex.label "$SubjectDIR"/"$SubjectID"/label/lh.cortex.label
cp "$SubjectDIR"/"$SubjectID"_1mm/label/rh.cortex.label "$SubjectDIR"/"$SubjectID"/label/rh.cortex.label

cp "$RescaleVolumeTransform".mat "$SubjectDIR"/"$SubjectID"_1mm/mri/transforms/fs2real.mat
convert_xfm -omat "$SubjectDIR"/"$SubjectID"_1mm/mri/transforms/real2fs.mat -inverse "$SubjectDIR"/"$SubjectID"_1mm/mri/transforms/fs2real.mat
convert_xfm -omat "$SubjectDIR"/"$SubjectID"_1mm/mri/transforms/temp.mat -concat "$SubjectDIR"/"$SubjectID"_1mm/mri/transforms/T2wtoT1w.mat "$SubjectDIR"/"$SubjectID"_1mm/mri/transforms/real2fs.mat
convert_xfm -omat "$SubjectDIR"/"$SubjectID"/mri/transforms/T2wtoT1w.mat -concat "$SubjectDIR"/"$SubjectID"_1mm/mri/transforms/fs2real.mat "$SubjectDIR"/"$SubjectID"_1mm/mri/transforms/temp.mat
rm "$SubjectDIR"/"$SubjectID"_1mm/mri/transforms/temp.mat
cp "$SubjectDIR"/"$SubjectID"_1mm/mri/transforms/eye.dat "$SubjectDIR"/"$SubjectID"/mri/transforms/eye.dat
cat "$SubjectDIR"/"$SubjectID"/mri/transforms/eye.dat | sed "s/${SubjectID}/${SubjectID}_1mm/g" > "$SubjectDIR"/"$SubjectID"_1mm/mri/transforms/eye.dat


for hemisphere in l r ; do
  cp "$SubjectDIR"/"$SubjectID"_1mm/surf/${hemisphere}h.thickness "$SubjectDIR"/"$SubjectID"/surf/${hemisphere}h.thickness
  #mris_convert "$SubjectDIR"/"$SubjectID"/surf/${hemisphere}h.white "$SubjectDIR"/"$SubjectID"/surf/${hemisphere}h.white.surf.gii
  #mris_convert "$SubjectDIR"/"$SubjectID"/surf/${hemisphere}h.pial "$SubjectDIR"/"$SubjectID"/surf/${hemisphere}h.pial.surf.gii
  #mris_convert -c "$SubjectDIR"/"$SubjectID"/surf/${hemisphere}h.thickness "$SubjectDIR"/"$SubjectID"/surf/${hemisphere}h.white "$SubjectDIR"/"$SubjectID"/surf/${hemisphere}h.roi.shape.gii 
  #${CARET7DIR}/wb_command -surface-to-surface-3d-distance "$SubjectDIR"/"$SubjectID"/surf/${hemisphere}h.white.surf.gii "$SubjectDIR"/"$SubjectID"/surf/${hemisphere}h.pial.surf.gii "$SubjectDIR"/"$SubjectID"/surf/${hemisphere}h.thickness.shape.gii
  #${CARET7DIR}/wb_command -metric-math "roi * min(thickness, 6)" "$SubjectDIR"/"$SubjectID"/surf/${hemisphere}h.thickness.shape.gii -var thickness "$SubjectDIR"/"$SubjectID"/surf/${hemisphere}h.thickness.shape.gii -var roi "$SubjectDIR"/"$SubjectID"/surf/${hemisphere}h.roi.shape.gii
  #mris_convert -c "$SubjectDIR"/"$SubjectID"/surf/${hemisphere}h.thickness.shape.gii "$SubjectDIR"/"$SubjectID"/surf/${hemisphere}h.white "$SubjectDIR"/"$SubjectID"/surf/${hemisphere}h.thickness.asc 
  #rm "$SubjectDIR"/"$SubjectID"/surf/${hemisphere}h.white.surf.gii "$SubjectDIR"/"$SubjectID"/surf/${hemisphere}h.pial.surf.gii "$SubjectDIR"/"$SubjectID"/surf/${hemisphere}h.thickness.shape.gii "$SubjectDIR"/"$SubjectID"/surf/${hemisphere}h.roi.shape.gii  
done 
surf="${SubjectDIR}/${SubjectID}/surf"
hemi="lh"
matlab <<M_PROG
corticalthickness('${surf}','${hemi}');
M_PROG
hemi="rh"
matlab <<M_PROG
corticalthickness('${surf}','${hemi}');
M_PROG


>>>>>>> Added Macaque and Chimp templates and FreeSurferNHP.sh script as maintained by VELab
