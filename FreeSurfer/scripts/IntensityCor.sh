#!/bin/bash
set -e
# Intensity Correction using FAST
# Takuya Hayashi, RIKEN BCIL 2016-2019

CMD=`echo $0 | sed -e 's/^\(.*\)\/\([^\/]*\)/\2/'`

usage_exit() {
      cat <<EOF

  Intenity correction using FAST

  Usage for T1w: $CMD <T1w input.mgz> <brainmask.mgz> <output.mgz> <species>
 
  Usage for T2w: $CMD <T2w input.mgz> <brainmask.mgz> <wmmask.mgz> <output.mgz> <species>

  Outputs are output.mgz, output_brain.mgz and output_brain_histogram.png

EOF
    exit 1;
}

[ "$3" = "" ] && usage_exit

in=`echo $1 | sed -e 's/.mgz//'`
mask=`echo $2 | sed -e 's/.mgz//'`

if [[ $5 == "" ]] ; then
	type=1
	out=`echo $3 | sed -e 's/.mgz//'`
	SPECIES=$4
else
	type=2
	mask2=`echo $3 | sed -e 's/.mgz//'`
	out=`echo $4 | sed -e 's/.mgz//'`
	SPECIES=$5
fi


lowpass=20
scalefactor2=57
sigma=$(echo $lowpass/2.35 | bc -l)

if [[ $SPECIES =~ Human ]] ; then
	scalefactor=100
elif [[ $SPECIES =~ Chimp ]] ; then
	scalefactor=100
elif [[ $SPECIES =~ Macaque ]] ; then
	scalefactor=80 
elif [[ $SPECIES =~ Marmoset ]] ; then
	scalefactor=68
else
	echo "ERROR: unknown species $SPECIES"; 
	exit 1;
fi

echo ""
echo "Start IntensityCor"
echo "SPECIES: $SPECIES"
echo "Type: $type"

tmpdir="`dirname $in`/"`basename $in`".IntensityCor"
mkdir -p $tmpdir

mri_convert "$in".mgz "$tmpdir"/orig.nii.gz -odt float
mri_convert "$mask".mgz "$tmpdir"/mask.nii.gz --like "$tmpdir"/orig.nii.gz

fslmaths "$tmpdir"/orig -mas "$tmpdir"/mask "$tmpdir"/orig_brain
echo "Run fast..."
echo "fast -v -B -b -t $type -l $lowpass -o "$tmpdir"/fast "$tmpdir"/orig_brain"
fast -v -B -b -t $type -l $lowpass -o "$tmpdir"/fast "$tmpdir"/orig_brain

fslmaths "$tmpdir"/fast_bias -mas "$tmpdir"/mask -dilall -s $sigma "$tmpdir"/fast_bias
fslmaths "$tmpdir"/orig -div "$tmpdir"/fast_bias "$tmpdir"/orig_restore

echo "Scaling restored image"
if (( type == 1 )) ; then

	mean=`fslstats "$tmpdir"/orig_restore.nii.gz -k "$tmpdir"/mask -M`
	fslmaths "$tmpdir"/orig_restore -mul $scalefactor -div $mean "$tmpdir"/orig_restore_scale -odt char

elif (( type == 2 )) ; then

	mri_convert "$mask2".mgz "$tmpdir"/mask2.nii.gz --like "$tmpdir"/orig.nii.gz
	mean=`fslstats "$tmpdir"/orig_restore.nii.gz -k "$tmpdir"/mask2 -M`
	fslmaths "$tmpdir"/orig_restore -mul $scalefactor2 -div $mean "$tmpdir"/orig_restore_scale -odt char

fi

echo "Converting to mgz"
mri_convert -ns 1 -odt uchar "$tmpdir"/orig_restore_scale.nii.gz "$out".mgz --like "$in".mgz
fslmaths "$tmpdir"/orig_restore_scale.nii.gz -mas "$tmpdir"/mask.nii.gz "$tmpdir"/orig_restore_scale_brain.nii.gz
fsl_histogram -i "$tmpdir"/orig_restore_scale_brain.nii.gz -b 254 -m "$tmpdir"/mask.nii.gz -o "$out"_brain_histogram.png
mri_convert -ns 1 -odt uchar "$tmpdir"/orig_restore_scale_brain.nii.gz "$out"_brain.mgz --like "$in".mgz 
#rm -rf $tmpdir

echo "End IntensityCor"
echo ""
exit 0;
