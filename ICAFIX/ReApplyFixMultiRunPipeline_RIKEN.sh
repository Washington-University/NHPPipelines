#!/bin/bash

#
# # ReApplyMultiRunFixPipeline.sh
#
# ## Copyright Notice
#
# Copyright (C) 2017 The Human Connectome Project/Connectome Coordination Facility
#
# * Washington University in St. Louis
# * University of Minnesota
# * Oxford University
#
# ## Author(s)
#
# * Matthew F. Glasser, Department of Anatomy and Neurobiology, Washington University in St. Louis
# * Timothy B. Brown, Neuroinformatics Research Group, Washington University in St. Louis
#
# ## Product
#
# [Human Connectome Project][HCP] (HCP) Pipelines
#
# ## License
#
# See the [LICENSE](https://github.com/Washington-Univesity/Pipelines/blob/master/LICENSE.md) file
#
# <!-- References -->
# [HCP]: http://www.humanconnectome.org
#

# ------------------------------------------------------------------------------
#  Show usage information for this script
# ------------------------------------------------------------------------------

usage()
{
	local script_name
	script_name=$(basename "${0}")

	cat <<EOF

${script_name}: ReApplyFix Pipeline for MultiRun ICA+FIX

This script has two purposes (both in the context of MultiRun FIX):
1) Reapply FIX cleanup to the volume and default CIFTI (i.e., MSMSulc registered surfaces)
following manual reclassification of the FIX signal/noise components (see ApplyHandReClassifications.sh).
2) Apply FIX cleanup to the CIFTI from an alternative surface registration (e.g., MSMAll)
(either for the first time, or following manual reclassification of the components).
Only one of these two purposes can be accomplished per invocation.

Usage: ${script_name} PARAMETER...

PARAMETERs are [ ] = optional; < > = user supplied value

  Note: The PARAMETERs can be specified positinally (i.e. without using the --param=value
        form) by simply specifying all values on the command line in the order they are
		listed below.

		e.g. ${script_name} <path to study folder> <subject ID> <fMRINames> ...

   [--help] : show this usage information and exit
   --path=<path to study folder> OR --study-folder=<path to study folder>
   --subject=<subject ID> (e.g. 100610)
   --fmri-names=<fMRI Names> @-separated list of fMRI file names 
     (e.g. /path/to/study/100610/MNINonLinear/Results/tfMRI_RETCCW_7T_AP/tfMRI_RETCCW_7T_AP.nii.gz@/path/to/study/100610/MNINonLinear/Results/tfMRI_RETCW_7T_PA/tfMRI_RETCW_7T_PA.nii.gz)
   --concat-fmri-name=<concatenated fMRI scan file name>
     (e.g. /path/to/study/100610/MNINonLinear/Results/tfMRI_7T_RETCCW_AP_RETCW_PA/tfMRI_7T_RETCCW_AP_RETCW_PA.nii.gz)
   --high-pass=<num> the HighPass variable used in Multi-run ICA+FIX (e.g. 2000)
   [--reg-name=<surface registration name> defaults to ${G_DEFAULT_REG_NAME}. (Use NONE for MSMSulc registration)
   [--low-res-mesh=<low res mesh number>] defaults to ${G_DEFAULT_LOW_RES_MESH}
   [--matlab-run-mode={0, 1, 2}] defaults to ${G_DEFAULT_MATLAB_RUN_MODE}
    0 = Use compiled MATLAB
    1 = Use interpreted MATLAB
    2 = Use interpreted Octave
   [--motion-regression={TRUE, FALSE}] defaults to ${G_DEFAULT_MOTION_REGRESSION}
   [-wf=<ndisthpvol>,<ndisthpcifti>,<ndistcifti>] Ndist for 'hp'ed volume, 'hp'ed CIFTI and concatenated cifti

EOF
}

# ------------------------------------------------------------------------------
#  Get the command line options for this script.
# ------------------------------------------------------------------------------
get_options()
{
	local arguments=("$@")

	# initialize global output variables
	unset p_StudyFolder      # ${1}
	unset p_Subject          # ${2}
	unset p_fMRINames        # ${3}
	unset p_ConcatfMRIName   # ${4}
	unset p_HighPass         # ${5}
	p_RegName="None"          # ${6}
	unset p_LowResMesh       # ${7}
	unset p_MatlabRunMode    # ${8}
	unset p_MotionRegression # ${9}

	# set default values
	p_LowResMesh=${G_DEFAULT_LOW_RES_MESH}
	p_MatlabRunMode=${G_DEFAULT_MATLAB_RUN_MODE}

	# parse arguments
	local num_args=${#arguments[@]}
	local argument
	local index=0

	while [ "${index}" -lt "${num_args}" ]; do
		argument=${arguments[index]}

		case ${argument} in
			--help)
				usage
				exit 1
				;;
			--path=*)
				p_StudyFolder=${argument#*=}
				index=$(( index + 1 ))
				;;
			--study-folder=*)
				p_StudyFolder=${argument#*=}
				index=$(( index + 1 ))
				;;
			--subject=*)
				p_Subject=${argument#*=}
				index=$(( index + 1 ))
				;;
			--fmri-names=*)
				p_fMRINames=${argument#*=}
				index=$(( index + 1 ))
				;;
			--concat-fmri-name=*)
				p_ConcatfMRIName=${argument#*=}
				index=$(( index + 1 ))
				;;
			--high-pass=*)
				p_HighPass=${argument#*=}
				index=$(( index + 1 ))
				;;
			--reg-name=*)
				p_RegName=${argument#*=}
				index=$(( index + 1 ))
				;;
			--low-res-mesh=*)
				p_LowResMesh=${argument#*=}
				index=$(( index + 1 ))
				;;
			--matlab-run-mode=*)
				p_MatlabRunMode=${argument#*=}
				index=$(( index + 1 ))
				;;
			--motion-regression=*)
				p_MotionRegression=${argument#*=}
				index=$(( index + 1 ))
				;;
			--wf=*)
				p_WF=${argument#*=}
				index=$(( index + 1 ))
				;;

			*)
				usage
				log_Err_Abort "unrecognized option: ${argument}"
				;;
		esac
	done

	local error_count=0

	# check required parameters
	if [ -z "${p_StudyFolder}" ]; then
		log_Err "Study Folder (--path= or --study-folder=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Study Folder: ${p_StudyFolder}"
	fi
	
	if [ -z "${p_Subject}" ]; then
		log_Err "Subject ID (--subject=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Subject ID: ${p_Subject}"
	fi	

	if [ -z "${p_fMRINames}" ]; then
		log_Err "fMRI Names (--fmri-names=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "fMRI Names: ${p_fMRINames}"
	fi

	if [ -z "${p_ConcatfMRIName}" ]; then
		log_Err "Concatenated fMRI scan name (--concat-fmri-name=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Concatenated fMRI scan name: ${p_ConcatfMRIName}"
	fi
	
	if [ -z "${p_HighPass}" ]; then
		log_Err "High Pass (--high-pass=) required"
		error_count=$(( error_count + 1 ))
	else
		# Checks on the validity of the --high-pass argument
		if [[ "${p_HighPass}" == "0" ]]; then
			log_Msg "--high-pass=0 corresponds to a linear detrend"
		fi
		if [[ "${p_HighPass}" == pd* ]]; then
			local hpNum=${p_HighPass:2}
			if (( hpNum > 5 )); then
				log_Err_Abort "Polynomial detrending of order ${hpNum} is not allowed (may not be numerically stable); Use 5th order or less"
			fi
		else
			local hpNum=${p_HighPass}
		fi
		if ! [[ "${hpNum}" =~ ^[-]?[0-9]+$ ]]; then
			log_Err "--high-pass value of ${p_HighPass} is not valid"
			error_count=$(( error_count + 1 ))
		fi
		if [[ $(echo "${hpNum} < 0" | bc) == "1" ]]; then  #Logic of this script does not support negative hp values
			log_Err "--high-pass value must not be negative"
			error_count=$(( error_count + 1 ))
		fi
		log_Msg "High Pass: ${p_HighPass}"
	fi

	if [ -z "${p_RegName}" ]; then
		log_Err "Reg Name (--reg-name=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Reg Name: ${p_RegName}"
	fi

	if [ -z "${p_LowResMesh}" ]; then
		log_Err "Low Res Mesh (--low-res-mesh=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Low Res Mesh: ${p_LowResMesh}"
	fi
	
	if [ -z "${p_MatlabRunMode}" ]; then
		log_Err "MATLAB run mode value (--matlab-run-mode=) required"
		error_count=$(( error_count + 1 ))
	else
		case ${p_MatlabRunMode} in
			0)
				log_Msg "MATLAB Run Mode: ${p_MatlabRunMode} - Use compiled MATLAB"
				if [ -z "${MATLAB_COMPILER_RUNTIME}" ]; then
					log_Err_Abort "To use MATLAB run mode: ${p_MatlabRunMode}, the MATLAB_COMPILER_RUNTIME environment variable must be set"
				else
					log_Msg "MATLAB_COMPILER_RUNTIME: ${MATLAB_COMPILER_RUNTIME}"
				fi
				;;
			1)
				log_Msg "MATLAB Run Mode: ${p_MatlabRunMode} - Use interpreted MATLAB"
				;;
			2)
				log_Msg "MATLAB Run Mode: ${p_MatlabRunMode} - Use interpreted Octave"
				;;
			*)
				log_Err "MATLAB Run Mode value must be 0, 1, or 2"
				error_count=$(( error_count + 1 ))
				;;
		esac
	fi

	if [ -z "${p_MotionRegression}" ]; then
		log_Err "motion correction setting (--motion-regression=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Motion Regression: ${p_MotionRegression}"
	fi

	if [ ${error_count} -gt 0 ]; then
		log_Err_Abort "For usage information, use --help"
	fi	
}

determine_old_or_new_fsl()
{
	local fsl_version=${1}
	local old_or_new
	local fsl_version_array
	local fsl_primary_version
	local fsl_secondary_version
	local fsl_tertiary_version

	# parse the FSL version information into primary, secondary, and tertiary parts
	fsl_version_array=(${fsl_version//./ })

	fsl_primary_version="${fsl_version_array[0]}"
	fsl_primary_version=${fsl_primary_version//[!0-9]/}
	
	fsl_secondary_version="${fsl_version_array[1]}"
	fsl_secondary_version=${fsl_secondary_version//[!0-9]/}
	
	fsl_tertiary_version="${fsl_version_array[2]}"
	fsl_tertiary_version=${fsl_tertiary_version//[!0-9]/}

	# determine whether we are using "OLD" or "NEW" FSL 
	# 6.0.0 and below is "OLD"
	# 6.0.1 and above is "NEW"
	
	if [[ $(( ${fsl_primary_version} )) -lt 6 ]] ; then
		# e.g. 4.x.x, 5.x.x
		old_or_new="OLD"
	elif [[ $(( ${fsl_primary_version} )) -gt 6 ]] ; then
		# e.g. 7.x.x
		old_or_new="NEW"
	else
		# e.g. 6.x.x
		if [[ $(( ${fsl_secondary_version} )) -gt 0 ]] ; then
			# e.g. 6.1.x
			old_or_new="NEW"
		else
			# e.g. 6.0.x
			if [[ $(( ${fsl_tertiary_version} )) -lt 1 ]] ; then
				# e.g. 6.0.0
				old_or_new="OLD"
			else
				# e.g. 6.0.1, 6.0.2, 6.0.3 ...
				old_or_new="NEW"
			fi
		fi
	fi

	echo ${old_or_new}
}

# ------------------------------------------------------------------------------
#  Show Tool Versions
# ------------------------------------------------------------------------------

show_tool_versions()
{
	# Show HCP pipelines version
	log_Msg "Showing HCP Pipelines version"
	cat ${HCPPIPEDIR}/version.txt

	# Show wb_command version
	log_Msg "Showing Connectome Workbench (wb_command) version"
	${CARET7DIR}/wb_command -version

	# Show fsl version
	log_Msg "Showing FSL version"
	fsl_version_get fsl_ver
	log_Msg "FSL version: ${fsl_ver}"

	old_or_new_version=$(determine_old_or_new_fsl ${fsl_ver})
	if [ "${old_or_new_version}" == "OLD" ] ; then
		#log_Err_Abort "FSL version 6.0.1 or greater is required."
		log_Msg "Warining: FSL version 6.0.1 or greater is required."
	fi
	HOST=`hostname`
	log_Msg "Host: $HOST"
}

# ------------------------------------------------------------------------------
#  Check for whether or not we have hand reclassification files
# ------------------------------------------------------------------------------

have_hand_reclassification()
{
	local StudyFolder="${1}"
	local Subject="${2}"
	local fMRIName="${3}"
	local HighPass="${4}"

	[ -e "${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_hp${HighPass}.ica/HandNoise.txt" ]
}

# ------------------------------------------------------------------------------
#  Main processing of script.
# ------------------------------------------------------------------------------

main()
{
	#mac readlink doesn't have -f
	if [[ -L "$0" ]]
	then
		local this_script_dir=$(dirname "$(readlink "$0")")
	else
		local this_script_dir=$(dirname "$0")
	fi

	# Show tool versions
	show_tool_versions

	log_Msg "Starting main functionality"

	# Retrieve positional parameters
	local StudyFolder="${1}"
	local Subject="${2}"
	local fMRINames="${3}"
	local ConcatfMRIName="${4}"
	local HighPass="${5}"

	local RegName="${6}"
	if [ -z "${6}" ]; then
		RegName=${G_DEFAULT_REG_NAME}
	else
		RegName="${6}"
	fi

	local LowResMesh
	if [ -z "${7}" ]; then
		LowResMesh=${G_DEFAULT_LOW_RES_MESH}
	else
		LowResMesh="${7}"
	fi
	
	local MatlabRunMode
	if [ -z "${8}" ]; then
		MatlabRunMode=${G_DEFAULT_MATLAB_RUN_MODE}
	else
		MatlabRunMode="${8}"
	fi

	local MotionRegression
	if [ -z "${9}" ]; then
		MotionRegression="${G_DEFAULT_MOTION_REGRESSION}"
	else
		MotionRegression="${9}"
	fi

	# Turn MotionRegression into an appropriate numeric value for fix_3_clean
	case $(echo ${MotionRegression} | tr '[:upper:]' '[:lower:]') in
        ( true | yes | 1)
            MotionRegression=1
            ;;
        ( false | no | none | 0)
            MotionRegression=0
            ;;
		*)
			log_Err_Abort "motion regression setting must be TRUE or FALSE"
			;;
	esac
	# Log values retrieved from positional parameters
	log_Msg "StudyFolder: ${StudyFolder}"
	log_Msg "Subject: ${Subject}"
	log_Msg "fMRINames: ${fMRINames}"
	log_Msg "ConcatfMRIName: ${ConcatfMRIName}"
	log_Msg "HighPass: ${HighPass}"
	log_Msg "RegName: ${RegName}"
	log_Msg "LowResMesh: ${LowResMesh}"
	log_Msg "MatlabRunMode: ${MatlabRunMode}"
	log_Msg "MotionRegression: ${MotionRegression}"


	local p_WF="${10}"

	# Naming Conventions and other variables
	local Caret7_Command="${CARET7DIR}/wb_command"
	log_Msg "Caret7_Command: ${Caret7_Command}"

	local RegString
	if [ "${RegName}" != "NONE" ] ; then
		RegString="_${RegName}"
	else
		RegString=""
	fi

	if [ ! -z ${LowResMesh} ] && [ ${LowResMesh} != ${G_DEFAULT_LOW_RES_MESH} ]; then
		RegString+=".${LowResMesh}k"
	fi

	log_Msg "RegString: ${RegString}"
	
	export FSL_FIX_CIFTIRW="${HCPPIPEDIR}/global/matlab"
	export FSL_FIX_WBC="${Caret7_Command}"
	export FSL_MATLAB_PATH="${FSLDIR}/etc/matlab"
	export FSL_FIXDIR="/mnt/pub/devel/bcil/fix1.06"

	local ML_PATHS="addpath('${FSL_MATLAB_PATH}'); addpath('${FSL_FIX_CIFTIRW}'); addpath('${FSL_FIXDIR}'); addpath('${HCPPIPEDIR}/global/matlab'); addpath('${this_script_dir}/scripts');"

	# Make appropriate files if they don't exist

	local aggressive=0
	local newclassification=0
	local DoVol=0
	local hp=${HighPass}
	local fixlist=".fix"

	# ConcatName (${4}) is expected to NOT include path info, or a nifti extension; make sure that is indeed the case
	#ConcatNameOnly=$(basename $($FSLDIR/bin/remove_ext $ConcatName))
	# But, then generate the absolute path so we can reuse the code from hcp_fix_multi_run
	#ConcatName="${StudyFolder}/${Subject}/MNINonLinear/Results/${ConcatNameOnly}/${ConcatNameOnly}"

	if have_hand_reclassification ${StudyFolder} ${Subject} `basename ${ConcatfMRIName}` ${hp} 
	then
		fixlist="HandNoise.txt"
		if [[ "${RegName}" == "NONE" ]]
		then
			DoVol=1
		fi
	fi
	log_Msg "Use fixlist=$fixlist"
	
	local fmris=${fMRINames//@/ } # replaces the @ that combines the filenames with a space
	log_Msg "fmris: ${fmris}"

	local ConcatName=${ConcatfMRIName}
	log_Msg "ConcatName: ${ConcatName}"


	DIR=`pwd`
	log_Msg "PWD : $DIR"
	## MPH: High level "master" conditional that checks whether the files necessary for fix_3_clean
	## already exist (i.e., reapplying FIX cleanup following manual classification).
	## If so, we can skip all the following looping through individual runs and concatenation, 
	## and resume at the "Housekeeping related to files expected for fix_3_clean" section
	local ConcatNameNoExt=$($FSLDIR/bin/remove_ext $ConcatName)  # No extension, but still includes the directory path

# check Ndist used when running MR-FIX  # TH 
if [ -e ${ConcatNameNoExt}_hp${hp}_wf.txt ] ; then
	ndhpvol="`cat ${ConcatNameNoExt}_hp${hp}_wf.txt | awk '{print $1}'`"
	ndhpcifti="`cat ${ConcatNameNoExt}_hp${hp}_wf.txt | awk '{print $2}'`"
	ndcifti="`cat ${ConcatNameNoExt}_hp${hp}_wf.txt | awk '{print $3}'`"
elif [ -z "$p_WF" ] ; then
	ndhpvol="`echo $p_WF | cut -d ',' -f1`"
	ndhpcifti="`echo $p_WF | cut -d ',' -f2`"
	ndcifti="`echo $p_WF | cut -d ',' -f3`"
else	
	log_Err_Abort "ERROR: cannot find Ndist used in MR-FIX. Please use option --wf to set Ndist"
fi

if [[ -f ${ConcatNameNoExt}_Atlas${RegString}_hp${hp}.dtseries.nii ]]; then
	log_Warn "${ConcatNameNoExt}_Atlas${RegString}_hp${hp}.dtseries.nii already exists."
	if (( DoVol && $(${FSLDIR}/bin/imtest "${ConcatNameNoExt}_hp${hp}") )); then
			log_Warn "$($FSLDIR/bin/imglob -extension ${ConcatNameNoExt}_hp${hp}) already exists."
	fi
	log_Warn "Using preceding existing concatenated file(s) for recleaning."

else  	# bash GOTO construct would be helpful here, to skip a bunch of code
	# NOT RE-INDENTING ALL THE FOLLOWING CODE
	# This 'else' clause terminates at the start of the
	# "Housekeeping related to files expected for fix_3_clean" section

	###LOOP HERE --> Since the files are being passed as a group

	echo $fmris | tr ' ' '\n' #separates paths separated by ' '

	## ---------------------------------------------------------------------------
	## Preparation (highpass) on the individual runs
	## ---------------------------------------------------------------------------

	#Loops over the files and does highpass to each of them
	log_Msg "Looping over files and doing highpass to each of them"

    	NIFTIvolMergeSTRING=""
   	NIFTIvolhpVNMergeSTRING=""
    	SBRefVolSTRING=""
    	MeanVolSTRING=""
    	VNVolSTRING=""
    	CIFTIMergeSTRING=""
    	CIFTIhpVNMergeSTRING=""
    	MeanCIFTISTRING=""
    	VNCIFTISTRING=""

	for fmri in $fmris ; do
    		log_Msg "Top of loop through fmris: fmri: ${fmri}"
	    	NIFTIvolMergeSTRING+="$($FSLDIR/bin/remove_ext $fmri)_demean "
	    	NIFTIvolhpVNMergeSTRING+="$($FSLDIR/bin/remove_ext $fmri)_hp${hp}_vnts "
	    	SBRefVolSTRING+="$($FSLDIR/bin/remove_ext $fmri)_SBRef "
		MeanVolSTRING+="$($FSLDIR/bin/remove_ext $fmri)_mean "
    		VNVolSTRING+="$($FSLDIR/bin/remove_ext $fmri)_hp${hp}_vn "
		CIFTIMergeSTRING+="-cifti $($FSLDIR/bin/remove_ext $fmri)_Atlas${RegString}_demean.dtseries.nii "
		CIFTIhpVNMergeSTRING+="-cifti $($FSLDIR/bin/remove_ext $fmri)_Atlas${RegString}_hp${hp}_vn.dtseries.nii "
		MeanCIFTISTRING+="-cifti $($FSLDIR/bin/remove_ext $fmri)_Atlas${RegString}_mean.dscalar.nii "
    		VNCIFTISTRING+="-cifti $($FSLDIR/bin/remove_ext $fmri)_Atlas${RegString}_hp${hp}_vn.dscalar.nii "

		cd `dirname $fmri`
		fmri=`basename $fmri`
		fmri=`$FSLDIR/bin/imglob $fmri`
		log_Msg "fmri: $fmri"
		fmri_orig=$fmri
		if [ `$FSLDIR/bin/imtest $fmri` != 1 ]; then
			log_Err_Abort "Invalid 4D_FMRI input file specified: ${fmri}"
		fi
    

		#Demean volumes
		if [[ ! -f ${fmri}_demean.nii.gz ]] ; then
			${FSLDIR}/bin/fslmaths $fmri -Tmean ${fmri}_mean
		        ${FSLDIR}/bin/fslmaths $fmri -sub ${fmri}_mean ${fmri}_demean
		else
			log_Warn "$($FSLDIR/bin/imglob -extension ${fmri}_demean) already exists. Using existing version"
	        fi

		#Demean CIFTI    
		if [[ ! -f $($FSLDIR/bin/remove_ext $fmri)_Atlas${RegString}_demean.dtseries.nii ]] ; then
		       ${FSL_FIX_WBC} -cifti-reduce $($FSLDIR/bin/remove_ext $fmri)_Atlas${RegString}.dtseries.nii MEAN $($FSLDIR/bin/remove_ext $fmri)_Atlas${RegString}_mean.dscalar.nii
		       ${FSL_FIX_WBC} -cifti-math "TCS - MEAN" $($FSLDIR/bin/remove_ext $fmri)_Atlas${RegString}_demean.dtseries.nii -var TCS $($FSLDIR/bin/remove_ext $fmri)_Atlas${RegString}.dtseries.nii -var MEAN $($FSLDIR/bin/remove_ext $fmri)_Atlas${RegString}_mean.dscalar.nii -select 1 1 -repeat
		else
			#log_Warn "${fmriNoExt}_Atlas${RegString}_demean.dtseries.nii already exists. Using existing version"
			log_Warn "$($FSLDIR/bin/remove_ext $fmri)_Atlas${RegString}_demean.dtseries.nii already exists. Using existing version"
		fi

		# ReApplyFixMultiRunPipeline has only a single pass through functionhighpassandvariancenormalize.
		# whereas hcp_fix_multi_run has two (because it runs melodic, which is not re-run here).
		# So, the "1st pass" VN is the only-pass, and there is no "2nd pass" VN.
		# Note that functionhighpassandvariancenormalize internally determines whether to process
		# the volume based on whether ${RegString} is empty. (Thus no explicit DoVol conditional
		# in the following).
		# If ${RegString} is empty, the movement regressors will also automatically get re-filtered.
		
		tr=`$FSLDIR/bin/fslval $fmri pixdim4`  #No checking currently that TR is same across runs
		log_Msg "tr: $tr"

		## Check if "1st pass" VN on the individual runs is needed; high-pass gets done here as well

	        if [[ ! -f "$($FSLDIR/bin/remove_ext $fmri)_Atlas${RegString}_hp${hp}_vn.dtseries.nii" || \
			! -f "$($FSLDIR/bin/remove_ext $fmri)_Atlas${RegString}_hp${hp}_vn.dscalar.nii" || \
        		! -f "$($FSLDIR/bin/remove_ext $fmri)_hp${hp}_vn.nii.gz" || \
        		! -f "$($FSLDIR/bin/remove_ext $fmri)_hp${hp}_vn.nii.gz" ]] ; then


			log_Msg "processing FMRI file $fmri with highpass $hp"
		    	case ${MatlabRunMode} in
			0)
			# Use Compiled Matlab
			local matlab_exe="${HCPPIPEDIR}"
			matlab_exe+="/ICAFIX/scripts/Compiled_functionhighpassandvariancenormalize/run_functionhighpassandvariancenormalize.sh"

			# Do NOT enclose string variables inside an additional single quote because all
			# variables are already passed into the compiled binary as strings
			local matlab_function_arguments=("${tr}" "${hp}" "${fmri}" "${Caret7_Command}" "${RegString}")

			# ${MATLAB_COMPILER_RUNTIME} contains the location of the MCR used to compile functionhighpassandvariancenormalize.m
			local matlab_cmd=("${matlab_exe}" "${MATLAB_COMPILER_RUNTIME}" "${matlab_function_arguments[@]}")

			# redirect tokens must be parsed by bash before doing variable expansion, and thus can't be inside a variable
			# MPH: Going to let Compiled MATLAB use the existing stdout and stderr, rather than creating a separate log file
			#local matlab_logfile=".reapplyfixmultirun.${concatfmri}${RegString}.functionhighpassandvariancenormalize.log"
			#"${matlab_cmd[@]}" >> "${matlab_logfile}" 2>&1
			log_Msg "Run compiled MATLAB: ${matlab_cmd[*]}"
			"${matlab_cmd[@]}"
        	        ;;

	            	1 | 2)
	                # Use interpreted MATLAB or Octave
			if [[ ${MatlabRunMode} == "1" ]]; then
				local interpreter=(matlab -nojvm -nodisplay -nosplash)
			else
				local interpreter=(octave-cli -q --no-window-system)
			fi
				
			# ${hp} needs to be passed in as a string, to handle the hp=pd* case
			#local matlab_cmd="${ML_PATHS} functionhighpassandvariancenormalize(${tr}, '${hp}', '${fmri}', '${Caret7_Command}', '${RegString}');"


			log_Msg "${FSL_FIXDIR}/call_matlab.sh -l .fix.functionhighpassandvariancenormalize_riken.log -f functionhighpassandvariancenormalize_riken $tr $hp $fmri ${FSL_FIX_WBC} $ndhpvol $ndhpcifti $ndcifti ${RegString}"

			${FSL_FIXDIR}/call_matlab.sh -l .fix.functionhighpassandvariancenormalize_riken.log -f functionhighpassandvariancenormalize_riken $tr $hp $fmri ${FSL_FIX_WBC} $ndhpvol $ndhpcifti $ndcifti ${RegString}

				
			#log_Msg "Run interpreted MATLAB/Octave (${interpreter[@]}) with command..."
			#log_Msg "${matlab_cmd}"

			# Use bash redirection ("here-string") to pass multiple commands into matlab
			# (Necessary to protect the semicolons that separate matlab commands, which would otherwise
			# get interpreted as separating different bash shell commands)
			# See note below about why we export FSL_FIX_WBC after sourcing FSL_FIXDIR/settings.sh
			(set +e; source "${FSL_FIXDIR}/settings.sh"; set -e; export FSL_FIX_WBC="${Caret7_Command}"; "${interpreter[@]}" <<<"${matlab_cmd}")
	                ;;

			*)
			# Unsupported MATLAB run mode
			log_Err_Abort "Unsupported MATLAB run mode value: ${MatlabRunMode}"
			;;

	        	esac
      	 

			# Demean the movement regressors (in the 'fake-NIFTI' format returned by functionhighpassandvariance  normalize)
			# MPH: This is irrelevant, since we aren't doing anything with these files.
			# (i.e,. not regenerating ${concatfmrihp}.ica/mc/prefiltered_func_data_mcf_conf)
			# But do it anyway, just to ensure that the files left behind are demeaned in the DoVol case
	        	log_Msg "Dims: $(cat ${fmri}_dims.txt)"

			if (( DoVol )); then
		        	fslmaths $(pwd)/${fmri}_hp$hp.ica/mc/prefiltered_func_data_mcf_conf.nii.gz -Tmean $(pwd)/${fmri}_hp$hp.ica/mc/prefiltered_func_data_mcf_conf_mean.nii.gz
		        	fslmaths $(pwd)/${fmri}_hp$hp.ica/mc/prefiltered_func_data_mcf_conf.nii.gz -sub $(pwd)/${fmri}_hp$hp.ica/mc/prefiltered_func_data_mcf_conf_mean.nii.gz $(pwd)/${fmri}_hp$hp.ica/mc/prefiltered_func_data_mcf_conf.nii.gz
		        	$FSLDIR/bin/imrm $(pwd)/${fmri}_hp$hp.ica/mc/prefiltered_func_data_mcf_conf_mean.nii.gz
	        	fi

		else
			log_Warn "Skipping functionhighpassandvariancenormalize because expected files for ${fmri} already exist"
		fi

		#cd ${DIR}  # Return to directory where script was launched	
	
		log_Msg "Bottom of loop through fmris: fmri: ${fmri}"

	done
	###END LOOP

	## ---------------------------------------------------------------------------
	## Concatenate the individual runs and create necessary files
	## ---------------------------------------------------------------------------

	if (( DoVol )); then
    		if [[ ! -f `remove_ext ${ConcatName}`.nii.gz ]] ; then
        		fslmerge -tr `remove_ext ${ConcatName}`_demean ${NIFTIvolMergeSTRING} $tr
        		fslmerge -tr `remove_ext ${ConcatName}`_hp${hp}_vnts ${NIFTIvolhpVNMergeSTRING} $tr
        		fslmerge -t  `remove_ext ${ConcatName}`_SBRef ${SBRefVolSTRING}
        		fslmerge -t  `remove_ext ${ConcatName}`_mean ${MeanVolSTRING}
        		fslmerge -t  `remove_ext ${ConcatName}`_hp${hp}_vn ${VNVolSTRING}
        		fslmaths `remove_ext ${ConcatName}`_SBRef -Tmean `remove_ext ${ConcatName}`_SBRef
        		fslmaths `remove_ext ${ConcatName}`_mean -Tmean `remove_ext ${ConcatName}`_mean
        		fslmaths `remove_ext ${ConcatName}`_hp${hp}_vn -Tmean `remove_ext ${ConcatName}`_hp${hp}_vn
        		fslmaths `remove_ext ${ConcatName}`_hp${hp}_vnts -mul `remove_ext ${ConcatName}`_hp${hp}_vn `remove_ext ${ConcatName}`_hp${hp} 
        		fslmaths `remove_ext ${ConcatName}`_demean -add `remove_ext ${ConcatName}`_mean `remove_ext ${ConcatName}`
        		fslmaths `remove_ext ${ConcatName}`_SBRef -bin `remove_ext ${ConcatName}`_brain_mask # Inserted to create mask to be used in melodic for suppressing memory error - Takuya Hayashi
		else
			log_Warn "$($FSLDIR/bin/imglob -extension ${ConcatName}) already exists. Using existing version"
    		fi
	fi

	# Same thing for the CIFTI    
    	#if [[ ! -f `remove_ext ${ConcatName}`_Atlas${RegString}_hp$hp.dtseries.nii ]] ; then
        	${FSL_FIX_WBC} -cifti-merge `remove_ext ${ConcatName}`_Atlas${RegString}_demean.dtseries.nii ${CIFTIMergeSTRING}
        	${FSL_FIX_WBC} -cifti-average `remove_ext ${ConcatName}`_Atlas${RegString}_mean.dscalar.nii ${MeanCIFTISTRING}
        	${FSL_FIX_WBC} -cifti-average `remove_ext ${ConcatName}`_Atlas${RegString}_hp${hp}_vn.dscalar.nii ${VNCIFTISTRING}
        	${FSL_FIX_WBC} -cifti-math "TCS + MEAN" `remove_ext ${ConcatName}`_Atlas${RegString}.dtseries.nii -var TCS `remove_ext ${ConcatName}`_Atlas${RegString}_demean.dtseries.nii -var MEAN `remove_ext ${ConcatName}`_Atlas${RegString}_mean.dscalar.nii -select 1 1 -repeat
        	${FSL_FIX_WBC} -cifti-merge `remove_ext ${ConcatName}`_Atlas${RegString}_hp${hp}_vn.dtseries.nii ${CIFTIhpVNMergeSTRING}
        	${FSL_FIX_WBC} -cifti-math "TCS * VN" `remove_ext ${ConcatName}`_Atlas${RegString}_hp${hp}.dtseries.nii -var TCS `remove_ext ${ConcatName}`_Atlas${RegString}_hp${hp}_vn.dtseries.nii -var VN `remove_ext ${ConcatName}`_Atlas${RegString}_hp${hp}_vn.dscalar.nii -select 1 1 -repeat
    	#else
	#	log_Warn "${ConcatNameNoExt}_Atlas${RegString}_hp${hp}.dtseries.nii already exists. Using existing version"
    	#fi


	#### Remove unnecessary files here

## Terminate the 'else' clause of the "master" conditional that checked whether
## the preceding code needed to be run.

fi

	## ---------------------------------------------------------------------------
	## Housekeeping related to files expected for fix_3_clean
	## ---------------------------------------------------------------------------
	
	local ConcatFolder=`dirname ${ConcatName}`
	cd ${ConcatFolder}

	local concat_fmri_orig=`basename $(remove_ext ${ConcatName})`
	local concatfmri=`basename $(remove_ext ${ConcatName})`_hp$hp

	cd `remove_ext ${concatfmri}`.ica

	# This is the concated volume time series from the 1st pass VN, with requested
	# hp-filtering applied and with the mean VN map multiplied back in
	${FSLDIR}/bin/imrm filtered_func_data
	#${FSLDIR}/bin/imln ../${concatfmrihp} filtered_func_data	
	${FSLDIR}/bin/imln ../${concatfmri} filtered_func_data

	# This is the concated CIFTI time series from the 1st pass VN, with requested
	# hp-filtering applied and with the mean VN map multiplied back in
	# Unlike single-run FIX (i.e., 'hcp_fix' and 'ReApplyFixPipeline'), here we symlink
	# to the hp-filtered CIFTI and use "AlreadyHP=-1" to skip any additional filtering in fix_3_clean.
	if [[ -f ../${concat_fmri_orig}_Atlas${RegString}_hp$hp.dtseries.nii ]] ; then
		log_Msg "FOUND FILE: ../${concat_fmri_orig}_Atlas${RegString}_hp$hp.dtseries.nii"
		log_Msg "Performing imln"

		rm -f Atlas.dtseries.nii
		$FSLDIR/bin/imln ../${concat_fmri_orig}_Atlas${RegString}_hp$hp.dtseries.nii Atlas.dtseries.nii
		
		log_Msg "START: Showing linked files"
		ls -l ../${concat_fmri_orig}_Atlas${RegString}_hp$hp.dtseries.nii
		ls -l Atlas.dtseries.nii
		log_Msg "END: Showing linked files"
	else
		log_Warn "FILE NOT FOUND: ../${concat_fmri_orig}_Atlas${RegString}_hp$hp.dtseries.nii"
	fi
	
	## ---------------------------------------------------------------------------
	## Run fix_3_clean
	## ---------------------------------------------------------------------------

	# MPH: We need to invoke fix_3_clean directly, rather than through 'fix -a <options>' because
	# the latter does not provide access to the "DoVol" option within the former.
	# (Also, 'fix -a' is hard-coded to use '.fix' as the list of noise components, although that 
	# could be worked around).

	export FSL_FIX_WBC="${Caret7_Command}"
	# WARNING: fix_3_clean uses the environment variable FSL_FIX_WBC, but most previous
	# versions of FSL_FIXDIR/settings.sh (v1.067 and earlier) have a hard-coded value for
	# FSL_FIX_WBC, and don't check whether it is already defined in the environment.
	# Thus, when settings.sh file gets sourced, there is a possibility that the version of
	# wb_command is no longer the same as that specified by ${Caret7_Command}.  So, after
	# sourcing settings.sh below, we explicitly set FSL_FIX_WBC back to value of ${Caret7_Command}.
	# (This may only be relevant for interpreted matlab/octave modes).

	log_Msg "Running fix_3_clean"

	AlreadyHP="-1"

	case ${MatlabRunMode} in

		# See important WARNING above regarding why ${DoVol} is NOT included as an argument when DoVol=1 !!
		
		0)
			# Use Compiled Matlab

			local matlab_exe="${FSL_FIXDIR}/compiled/$(uname -s)/$(uname -m)/run_fix_3_clean.sh"

			# Do NOT enclose string variables inside an additional single quote because all
			# variables are already passed into the compiled binary as strings
			local matlab_function_arguments=("${fixlist}" "${aggressive}" "${MotionRegression}" "${AlreadyHP}")
			if (( ! DoVol )); then
				matlab_function_arguments+=("${DoVol}")
			fi
			
			# fix_3_clean is part of the FIX distribution, which was compiled under its own (separate) MCR.
			# If ${FSL_FIX_MCR} is already defined in the environment, use that for the MCR location.
			# If not, the appropriate MCR version for use with fix_3_clean should be set in $FSL_FIXDIR/settings.sh.
			if [ -z "${FSL_FIX_MCR}" ]; then
				set +e
				source ${FSL_FIXDIR}/settings.sh
				set -e
				export FSL_FIX_WBC="${Caret7_Command}"
				# If FSL_FIX_MCR is still not defined after sourcing settings.sh, we have a problem
				if [ -z "${FSL_FIX_MCR}" ]; then
					log_Err_Abort "To use MATLAB run mode: ${MatlabRunMode}, the FSL_FIX_MCR environment variable must be set"
				fi
			fi
			log_Msg "FSL_FIX_MCR: ${FSL_FIX_MCR}"
							
			local matlab_cmd=("${matlab_exe}" "${FSL_FIX_MCR}" "${matlab_function_arguments[@]}")

			# redirect tokens must be parsed by bash before doing variable expansion, and thus can't be inside a variable
			# MPH: Going to let Compiled MATLAB use the existing stdout and stderr, rather than creating a separate log file
			#local matlab_logfile=".reapplyfixmultirun.${concatfmri}${RegString}.fix_3_clean.matlab.log"
			#log_Msg "Run MATLAB command: ${matlab_cmd[*]} >> ${matlab_logfile} 2>&1"
			#"${matlab_cmd[@]}" >> "${matlab_logfile}" 2>&1
			log_Msg "Run compiled MATLAB: ${matlab_cmd[*]}"
			"${matlab_cmd[@]}"
			;;		

		1 | 2)
			# Use interpreted MATLAB or Octave
			if [[ ${MatlabRunMode} == "1" ]]; then
				local interpreter=(matlab -nojvm -nodisplay -nosplash)
			else
				local interpreter=(octave-cli -q --no-window-system)
			fi

			if (( DoVol )); then
				local matlab_cmd="${ML_PATHS} fix_3_clean('${fixlist}',${aggressive},${MotionRegression},${AlreadyHP});"
			else
				local matlab_cmd="${ML_PATHS} fix_3_clean('${fixlist}',${aggressive},${MotionRegression},${AlreadyHP},${DoVol});"
			fi
			
			log_Msg "Run interpreted MATLAB/Octave (${interpreter[@]}) with command..."
			log_Msg "${matlab_cmd}"
			
            # Use bash redirection ("here-string") to pass multiple commands into matlab
			# (Necessary to protect the semicolons that separate matlab commands, which would otherwise
			# get interpreted as separating different bash shell commands)
			(set +e; source "${FSL_FIXDIR}/settings.sh"; set -e; export FSL_FIX_WBC="${Caret7_Command}"; "${interpreter[@]}" <<<"${matlab_cmd}")
			;;


		*)
			# Unsupported MATLAB run mode
			log_Err_Abort "Unsupported MATLAB run mode value: ${MatlabRunMode}"
			;;
	esac

	cd ..
	
	pwd

	if [[ -f ${concatfmri}.ica/filtered_func_data_clean.nii.gz ]]
	then
		log_Debug_Msg "Moving ${concatfmri}.ica/filtered_func_data_clean to ${concatfmri}_clean"
		$FSLDIR/bin/immv ${concatfmri}.ica/filtered_func_data_clean ${concatfmri}_clean
	       $FSLDIR/bin/immv ${concatfmri}.ica/filtered_func_data_clean_vn ${concatfmri}_clean_vn
	fi

	log_Debug_Msg "Checking for existence of ${concatfmri}.ica/Atlas_clean.dtseries.nii"
	echo ${concatfmri}.ica/Atlas_clean.dtseries.nii

	if [ -f ${concatfmri}.ica/Atlas_clean.dtseries.nii ] ; then
		/bin/mv ${concatfmri}.ica/Atlas_clean.dtseries.nii ${concat_fmri_orig}_Atlas${RegString}_hp${hp}_clean.dtseries.nii
		/bin/mv ${concatfmri}.ica/Atlas_clean_vn.dscalar.nii ${concat_fmri_orig}_Atlas${RegString}_hp${hp}_clean_vn.dscalar.nii
		/bin/mv ${concatfmri}.ica/Atlas_unst.dtseries.nii ${concat_fmri_orig}_Atlas${RegString}_hp${hp}_unst.dtseries.nii  # TH
		#${FSL_FIX_WBC} -cifti-math "TCS/VN" ${concat_fmri_orig}_Atlas${RegString}_hp${hp}_clean_vn.dtseries.nii -var TCS ${concat_fmri_orig}_Atlas${RegString}_hp${hp}_clean.dtseries.nii -var VN ${concat_fmri_orig}_Atlas${RegString}_hp${hp}_clean_vn.dscalar.nii -select 1 1 -repeat  # TH
	fi

	## ---------------------------------------------------------------------------
	## Split the cleaned volume and CIFTI back into individual runs.
	## ---------------------------------------------------------------------------

	## The cleaned volume and CIFTI have no mean.
	## The time series of the individual runs were variance normalized via the 1st pass through functionhighpassandvariancenormalize.
	## The mean VN map (across runs) was then multiplied into the concatenated time series, and that became the input to FIX.
	## We now reverse that process.
	## i.e., the mean VN (across runs) is divided back out, and the VN map for the individual run multiplied back in.
	## Then the mean is added back in to return the timeseries to its original state minus the noise (as estimated by FIX).

	log_Msg "Splitting cifti back into individual runs"
	if (( DoVol )); then
	   log_Msg "Also splitting nifti back into individual runs"
	fi	
	Start="1"
	for fmri in $fmris ; do
		
	    NumTPS=`${FSL_FIX_WBC} -file-information $(remove_ext ${fmri})_Atlas${RegString}.dtseries.nii -no-map-info -only-number-of-maps`
	    Stop=`echo "${NumTPS} + ${Start} -1" | bc -l`
	    log_Msg "Start=${Start} Stop=${Stop}"
	
	    log_Debug_Msg "cifti merging"
	    cifti_out=`remove_ext ${fmri}`_Atlas${RegString}_hp${hp}_clean.dtseries.nii
	    ${FSL_FIX_WBC} -cifti-merge ${cifti_out} -cifti ${concat_fmri_orig}_Atlas${RegString}_hp${hp}_clean.dtseries.nii -column ${Start} -up-to ${Stop}

	   # Adapt to older version of hcp_fix_multi_run - Takuya Hayashi June 2019
            #if [ ! -e `remove_ext ${concat_fmri_orig}`_Atlas${RegString}_hp${hp}_vn.dscalar.nii ] ; then
	   #     if [ -e `remove_ext ${concat_fmri_orig}`_Atlas${RegString}_vn.dscalar.nii ] ; then
            #        cp `remove_ext ${concat_fmri_orig}`_Atlas${RegString}_vn.dscalar.nii `remove_ext ${concat_fmri_orig}`_Atlas${RegString}_hp${hp}_vn.dscalar.nii
            #    fi
            #fi

            #if [ ! -e `remove_ext ${fmri}`_Atlas${RegString}_hp${hp}_vn.dscalar.nii ] ; then
	   #     if [ -e `remove_ext ${fmri}`_Atlas${RegString}_vn.dscalar.nii ] ; then
            #        cp `remove_ext ${fmri}`_Atlas${RegString}_vn.dscalar.nii `remove_ext ${fmri}`_Atlas${RegString}_hp${hp}_vn.dscalar.nii 
            #    fi
            #fi

	    ${FSL_FIX_WBC} -cifti-math "((TCS / VNA) * VN) + Mean" `remove_ext ${fmri}`_Atlas${RegString}_hp${hp}_clean.dtseries.nii -var TCS `remove_ext ${fmri}`_Atlas${RegString}_hp${hp}_clean.dtseries.nii -var VNA `remove_ext ${concat_fmri_orig}`_Atlas${RegString}_hp${hp}_vn.dscalar.nii -select 1 1 -repeat -var VN `remove_ext ${fmri}`_Atlas${RegString}_hp${hp}_vn.dscalar.nii -select 1 1 -repeat -var Mean `remove_ext ${fmri}`_Atlas${RegString}_mean.dscalar.nii -select 1 1 -repeat

  	# Approach 1 for single run VN - not working
	#${FSL_FIX_WBC} -cifti-math '1/VNA*VNB/VNC' `remove_ext ${fmri}`_Atlas_hp${hp}_clean_vn.dscalar.nii -var VNA `remove_ext ${fmri}`_Atlas_vn.dscalar.nii -var VNB `remove_ext ${concat_fmri_orig}`_Atlas_vn.dscalar.nii -var VNC `remove_ext ${concat_fmri_orig}`_Atlas_hp${hp}_clean_vn.dscalar.nii

	# Approach 1 for single run VN based on discussion with Matt - working TH 
	#log_Debug_Msg "Calculate VN 1"
	cp `remove_ext ${concat_fmri_orig}`_Atlas${RegString}_hp${hp}_clean_vn.dscalar.nii `remove_ext ${fmri}`_Atlas${RegString}_hp${hp}_clean_vn.dscalar.nii
	cp `remove_ext ${concat_fmri_orig}`_hp${hp}_clean_vn.nii.gz `remove_ext ${fmri}`_hp${hp}_clean_vn.nii.gz


	#${FSL_FIX_WBC} -cifti-math "TCS/VN" `remove_ext ${fmri}`_Atlas${RegString}_hp${hp}_clean_vn.dtseries.nii -var TCS `remove_ext ${fmri}`_Atlas${RegString}_hp${hp}_clean.dtseries.nii -var VN `remove_ext ${fmri}`_Atlas${RegString}_hp${hp}_clean_vn.dscalar.nii -select 1 1 -repeat # This is now calculated in hcppipe_RSNRegression TH June 2020

	## Approach 2 for single run VN (need to modify fix_3_clean) also working. Is this needed? TH May 2019
	#log_Debug_Msg "Calculate VN 2"
	#${FSL_FIX_WBC} -cifti-merge `remove_ext ${fmri}`_Atlas${RegString}_hp${hp}_clean_unst.dtseries.nii -cifti ${concat_fmri_orig}_Atlas${RegString}_hp${hp}_unst.dtseries.nii -column ${Start} -up-to ${Stop}
	#${FSL_FIX_WBC} -cifti-reduce `remove_ext ${fmri}`_Atlas${RegString}_hp${hp}_clean_unst.dtseries.nii STDEV `remove_ext ${fmri}`_Atlas${RegString}_hp${hp}_clean_vn2.dscalar.nii
	#rm `remove_ext ${fmri}`_Atlas${RegString}_hp${hp}_clean_unst.dtseries.nii
	#${FSL_FIX_WBC} -cifti-math "TCS/VN" `remove_ext ${fmri}`_Atlas${RegString}_hp${hp}_clean_vn2.dtseries.nii -var TCS `remove_ext ${fmri}`_Atlas${RegString}_hp${hp}_clean.dtseries.nii -var VN `remove_ext ${fmri}`_Atlas${RegString}_hp${hp}_clean_vn2.dscalar.nii -select 1 1 -repeat
        ##
	    readme_for_cifti_out=${cifti_out%.dtseries.nii}.README.txt
	    touch ${readme_for_cifti_out}
	    short_cifti_out=${cifti_out##*/}
	    echo "${short_cifti_out} was generated by applying \"multi-run FIX\" (using '${g_script_name}')" >> ${readme_for_cifti_out}
	    echo "across the following individual runs:" >> ${readme_for_cifti_out}
	    for readme_fmri in ${fmris} ; do
		    echo "  ${readme_fmri}" >> ${readme_for_cifti_out}
	    done
		
		if (( DoVol == 1 ))
		then
	        log_Debug_Msg "volume merging"
	        ${FSL_FIX_WBC} -volume-merge `remove_ext ${fmri}`_hp${hp}_clean.nii.gz -volume ${concatfmri}_clean.nii.gz -subvolume ${Start} -up-to ${Stop}
	        fslmaths `remove_ext ${fmri}`_hp${hp}_clean.nii.gz -div `remove_ext ${concat_fmri_orig}`_hp${hp}_vn -mul `remove_ext ${fmri}`_hp${hp}_vn -add `remove_ext ${fmri}`_mean `remove_ext ${fmri}`_hp${hp}_clean.nii.gz
        	fi
	    Start=`echo "${Start} + ${NumTPS}" | bc -l`
	done

	## ---------------------------------------------------------------------------
	## Remove all the large time series files in ${ConcatFolder}
	## ---------------------------------------------------------------------------

	## Deleting these files would save a lot of space.
	## But downstream scripts (e.g., RestingStateStats) assume they exist, and
	## if deleted they would therefore need to be re-created "on the fly" later

	# cd ${ConcatFolder}
        # log_Msg "Removing large (concatenated) time series files from ${ConcatFolder}"
	# $FSLDIR/bin/imrm ${concatfmri}
	# $FSLDIR/bin/imrm ${concatfmri}_hp${hp}
	# $FSLDIR/bin/imrm ${concatfmri}_hp${hp}_clean
	# /bin/rm -f ${concatfmri}_Atlas${RegString}.dtseries.nii
	# /bin/rm -f ${concatfmri}_Atlas${RegString}_hp${hp}.dtseries.nii
	# /bin/rm -f ${concatfmri}_Atlas${RegString}_hp${hp}_clean.dtseries.nii
	cd ${DIR}

	log_Msg "Completed!"
}

# ------------------------------------------------------------------------------
#  "Global" processing - everything above here should be in a function
# ------------------------------------------------------------------------------

set -e # If any command exits with non-zero value, this script exits

# Establish defaults
G_DEFAULT_REG_NAME="NONE"
G_DEFAULT_LOW_RES_MESH=32
G_DEFAULT_MATLAB_RUN_MODE=1		# Use interpreted MATLAB
G_DEFAULT_MOTION_REGRESSION="FALSE"

# Set global variables
g_script_name=$(basename "${0}")

# Allow script to return a Usage statement, before any other output
if [ "$#" = "0" ]; then
    usage
    exit 1
fi
# Verify that HCPPIPEDIR environment variable is set
if [ -z "${HCPPIPEDIR}" ]; then
	echo "$(basename ${0}): ABORTING: HCPPIPEDIR environment variable must be set"
	exit 1
fi

# Load function libraries
source ${HCPPIPEDIR}/global/scripts/log.shlib # Logging related functions
source ${HCPPIPEDIR}/global/scripts/fsl_version.shlib # Functions for getting FSL version
log_SetToolName "ReApplyFixPipelineMultiRun.sh"
log_Msg "HCPPIPEDIR: ${HCPPIPEDIR}"

# Verify any other needed environment variables are set
log_Check_Env_Var CARET7DIR
log_Check_Env_Var FSLDIR
log_Check_Env_Var FSL_FIXDIR

# Establish default MATLAB run mode
G_DEFAULT_MATLAB_RUN_MODE=1		# Use interpreted MATLAB

# Establish default low res mesh for NHP
if [ "$SPECIES" = "Macaque" ] ; then
	G_DEFAULT_LOW_RES_MESH=10
elif [ "$SPECIES" = "Marmoset" ] ; then
	G_DEFAULT_LOW_RES_MESH=4
fi
	
# Determine whether named or positional parameters are used
if [[ ${1} == --* ]]; then
	# Named parameters (e.g. --parameter-name=parameter-value) are used
	log_Msg "Using named parameters"

	# Get command line options
	get_options "$@"

	# Invoke main functionality
	#     ${1}               ${2}           ${3}             ${4}                  ${5}            ${6}           ${7}              ${8}              ${9}
	main "${p_StudyFolder}" "${p_Subject}" "${p_fMRINames}" "${p_ConcatfMRIName}" "${p_HighPass}" "${p_RegName}" "${p_LowResMesh}" "${p_MatlabRunMode}" "${p_MotionRegression} ${p_WF}"


else
	# Positional parameters are used
	log_Msg "Using positional parameters"
	main "$@"

fi







