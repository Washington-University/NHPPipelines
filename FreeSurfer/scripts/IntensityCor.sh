#!/bin/bash
set -e
# Intensity Correction using FAST

CMD=`echo $0 | sed -e 's/^\(.*\)\/\([^\/]*\)/\2/'`

usage_exit() {
      cat <<EOF

  Intenity correction using FAST

  Usage: $CMD <input.mgz> <brainmask.mgz> <output.mgz> <species>

  Outputs are output.mgz, output_brain.nii.gz and output_histogram.txt.

EOF
    exit 1;
}

[ "$3" = "" ] && usage_exit

in=`echo $1 | sed -e 's/.mgz//'`
mask=`echo $2 | sed -e 's/.mgz//'`
out=`echo $3 | sed -e 's/.mgz//'`
species=$4

lowpass=20

if [ $SPECIES = Human ] ; then
  scalefactor=100
elif [ $SPECIES = Chimp ] ; then
  scalefactor=100
elif [ $SPECIES = Macaque ] ; then
	scalefactor=80
elif [ $SPECIES = Marmoset ] ; then
	scalefactor=68
else
	echo "ERROR: unknown species $SPECIES";
	exit 1;
fi

tmpdir="`dirname $1`/IntensityCor"
mkdir -p $tmpdir

mri_convert "$in".mgz "$tmpdir"/orig.nii.gz -odt float
mri_convert "$mask".mgz "$tmpdir"/mask.nii.gz

fslmaths "$tmpdir"/orig -mas "$tmpdir"/mask "$tmpdir"/orig_brain
fast -v -B -l $lowpass -o "$tmpdir"/fast "$tmpdir"/orig_brain

mean=`fslstats "$tmpdir"/fast_restore.nii.gz -k "$tmpdir"/mask -M`
fslmaths "$tmpdir"/fast_restore -binv -mul "$tmpdir"/orig -add "$tmpdir"/fast_restore -mul $scalefactor -div $mean "$tmpdir"/fast_restore_scale -odt char
mri_convert -ns 1 -odt uchar "$tmpdir"/fast_restore_scale.nii.gz "$out".mgz --like "$in".mgz
fslmaths "$tmpdir"/fast_restore_scale.nii.gz -mas "$tmpdir"/mask.nii.gz "$out"_brain.nii.gz
fsl_histogram -i "$out"_brain.nii.gz -b 254 -m "$out"_brain.nii.gz -o "$out"_brain_histogram.png
rm -rf $tmpdir
