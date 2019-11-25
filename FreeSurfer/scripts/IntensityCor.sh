#!/bin/bash
set -e
# Intensity Correction using FAST

CMD=`echo $0 | sed -e 's/^\(.*\)\/\([^\/]*\)/\2/'`

usage_exit() {
      cat <<EOF

  Intenity correction using FAST

  Usage for T1w: $CMD <T1w input.mgz> <brainmask.mgz> <output.mgz> <species>

  Usage for T2w: $CMD <T2w input.mgz> <brainmask.mgz> <wmmask.mgz> <output.mgz> <species>

  Outputs are output.mgz, output_brain.nii.gz and output_histogram.txt.

EOF
    exit 1;
}

[ "$3" = "" ] && usage_exit

in=`echo $1 | sed -e 's/.mgz//'`
mask=`echo $2 | sed -e 's/.mgz//'`
if [[ $5 == "" ]] ; then
        type=1
        out=`echo $3 | sed -e 's/.mgz//'`
        SPECIES=$45
else
        type=2
        mask2=`echo $3 | sed -e 's/.mgz//'`
        out=`echo $4 | sed -e 's/.mgz//'`
        SPECIES=$5
fi

lowpass=20
scalefactor2=57
sigma=$(echo $lowpass/2.35 | bc -l)

if [ $SPECIES = Human ] ; then
  scalefactor=100
elif [ $SPECIES = Macaque ] ; then
	scalefactor=80
elif [ $SPECIES = Marmoset ] ; then
	scalefactor=68
else
	echo "ERROR: unknown species $SPECIES";
	exit 1;
fi

echo ""
echo "Start IntensityCor"
echo "SPECIES: $SPECIES"
echo "Type: $type"

tmpdir="`dirname $1`/IntensityCor"
mkdir -p $tmpdir

mri_convert "$in".mgz "$tmpdir"/orig.nii.gz -odt float
mri_convert "$mask".mgz "$tmpdir"/mask.nii.gz --like "$tmpdir"/orig.nii.gz

fslmaths "$tmpdir"/orig -mas "$tmpdir"/mask "$tmpdir"/orig_brain
echo "Run fast..."
echo "fast -v -B -b -t $type -l $lowpass -o "$tmpdir"/fast "$tmpdir"/orig_brain"
fast -v -B -b $type -l $lowpass -o "$tmpdir"/fast "$tmpdir"/orig_brain

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
mri_convert -ns 1 -odt uchar "$tmpdir"/fast_restore_scale.nii.gz "$out".mgz --like "$in".mgz
fslmaths "$tmpdir"/fast_restore_scale.nii.gz -mas "$tmpdir"/mask.nii.gz "$out"_brain.nii.gz
fsl_histogram -i "$out"_brain.nii.gz -b 254 -m "$out"_brain.nii.gz -o "$out"_brain_histogram.png
rm -rf $tmpdir

echo "End IntensityCor"
echo ""
exit 0;
