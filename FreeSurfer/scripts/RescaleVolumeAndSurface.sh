#! /bin/bash
set -e

Usage_exit (){
echo "RescaleVolumeAndSurface.sh <SubjectDIR> <SubjectID> <RescaleVolumeTransform> <T1wImage>"
exit 0;
}
if [ "$4" = "" ] ; then Usage_exit ;fi

SubjectDIR=$1
SubjectID=$2
RescaleVolumeTransform=$3
T1wImage=$4

mri_convert -rt cubic -at "$RescaleVolumeTransform".xfm -rl "$T1wImage" "$SubjectDIR"/"$SubjectID"_1mm/mri/rawavg.mgz "$SubjectDIR"/"$SubjectID"/mri/rawavg.mgz
mri_convert "$SubjectDIR"/"$SubjectID"/mri/rawavg.mgz "$SubjectDIR"/"$SubjectID"/mri/rawavg.nii.gz
mri_convert -rt nearest -at "$RescaleVolumeTransform".xfm -rl "$T1wImage" "$SubjectDIR"/"$SubjectID"_1mm/mri/wmparc.mgz "$SubjectDIR"/"$SubjectID"/mri/wmparc.mgz
mri_convert -rt nearest -at "$RescaleVolumeTransform".xfm -rl "$T1wImage" "$SubjectDIR"/"$SubjectID"_1mm/mri/brain.finalsurfs.mgz "$SubjectDIR"/"$SubjectID"/mri/brain.finalsurfs.mgz
mri_convert -rt cubic -at "$RescaleVolumeTransform".xfm -rl "$T1wImage" "$SubjectDIR"/"$SubjectID"_1mm/mri/orig.mgz "$SubjectDIR"/"$SubjectID"/mri/orig.mgz
mri_convert -rt cubic -at "$RescaleVolumeTransform".xfm -rl "$T1wImage" "$SubjectDIR"/"$SubjectID"_1mm/mri/brainmask.mgz "$SubjectDIR"/"$SubjectID"/mri/brainmask.mgz

mri_convert -rl "$SubjectDIR"/"$SubjectID"_1mm/mri/rawavg.mgz "$SubjectDIR"/"$SubjectID"_1mm/mri/wmparc.mgz "$SubjectDIR"/"$SubjectID"_1mm/mri/wmparc.nii.gz
mri_convert -rl "$SubjectDIR"/"$SubjectID"_1mm/mri/rawavg.mgz "$SubjectDIR"/"$SubjectID"_1mm/mri/brain.finalsurfs.mgz "$SubjectDIR"/"$SubjectID"_1mm/mri/brain.finalsurfs.nii.gz
mri_convert -rl "$SubjectDIR"/"$SubjectID"_1mm/mri/rawavg.mgz "$SubjectDIR"/"$SubjectID"_1mm/mri/orig.mgz "$SubjectDIR"/"$SubjectID"_1mm/mri/orig.nii.gz

applywarp --interp=nn -i "$SubjectDIR"/"$SubjectID"_1mm/mri/wmparc.nii.gz -r "$SubjectDIR"/"$SubjectID"/mri/rawavg.nii.gz --premat="$RescaleVolumeTransform".mat -o "$SubjectDIR"/"$SubjectID"/mri/wmparc.nii.gz
applywarp --interp=nn -i "$SubjectDIR"/"$SubjectID"_1mm/mri/brain.finalsurfs.nii.gz -r "$SubjectDIR"/"$SubjectID"/mri/rawavg.nii.gz --premat="$RescaleVolumeTransform".mat -o "$SubjectDIR"/"$SubjectID"/mri/brain.finalsurfs.nii.gz
applywarp --interp=nn -i "$SubjectDIR"/"$SubjectID"_1mm/mri/orig.nii.gz -r "$SubjectDIR"/"$SubjectID"/mri/rawavg.nii.gz --premat="$RescaleVolumeTransform".mat -o "$SubjectDIR"/"$SubjectID"/mri/orig.nii.gz

mri_convert "$SubjectDIR"/"$SubjectID"/mri/wmparc.nii.gz "$SubjectDIR"/"$SubjectID"/mri/wmparc.mgz
mri_convert "$SubjectDIR"/"$SubjectID"/mri/brain.finalsurfs.nii.gz "$SubjectDIR"/"$SubjectID"/mri/brain.finalsurfs.mgz
mri_convert "$SubjectDIR"/"$SubjectID"/mri/orig.nii.gz "$SubjectDIR"/"$SubjectID"/mri/orig.mgz

# for hemisphere
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
cp "$SubjectDIR"/"$SubjectID"_1mm/label/lh.aparc.annot "$SubjectDIR"/"$SubjectID"/label/lh.aparc.annot
cp "$SubjectDIR"/"$SubjectID"_1mm/label/rh.aparc.annot "$SubjectDIR"/"$SubjectID"/label/rh.aparc.annot

# For Volume and matrices
cp "$RescaleVolumeTransform".mat "$SubjectDIR"/"$SubjectID"_1mm/mri/transforms/fs2real.mat
convert_xfm -omat "$SubjectDIR"/"$SubjectID"_1mm/mri/transforms/real2fs.mat -inverse "$SubjectDIR"/"$SubjectID"_1mm/mri/transforms/fs2real.mat
convert_xfm -omat "$SubjectDIR"/"$SubjectID"_1mm/mri/transforms/temp.mat -concat "$SubjectDIR"/"$SubjectID"_1mm/mri/transforms/T2wtoT1w.mat "$SubjectDIR"/"$SubjectID"_1mm/mri/transforms/real2fs.mat
convert_xfm -omat "$SubjectDIR"/"$SubjectID"/mri/transforms/T2wtoT1w.mat -concat "$SubjectDIR"/"$SubjectID"_1mm/mri/transforms/fs2real.mat "$SubjectDIR"/"$SubjectID"_1mm/mri/transforms/temp.mat
rm "$SubjectDIR"/"$SubjectID"_1mm/mri/transforms/temp.mat
cp "$SubjectDIR"/"$SubjectID"_1mm/mri/transforms/eye.dat "$SubjectDIR"/"$SubjectID"/mri/transforms/eye.dat
if [ `head -n 1 "$SubjectDIR"/"$SubjectID"/mri/transforms/eye.dat | tail -c 5` != "_1mm" ] ; then # avoid adding too many "_1mm" - Takuya Hayashi
	cat "$SubjectDIR"/"$SubjectID"/mri/transforms/eye.dat | sed "s/${SubjectID}/${SubjectID}_1mm/g" > "$SubjectDIR"/"$SubjectID"_1mm/mri/transforms/eye.dat
fi

# For hemisphere
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
matlab -nojvm -nosplash <<M_PROG
addpath $HCPPIPEDIR/global/matlab
addpath('/usr/local/NHPHCP/matlab')
corticalthickness('${surf}','${hemi}');
M_PROG
hemi="rh"
matlab -nojvm -nosplash <<M_PROG
addpath $HCPPIPEDIR/global/matlab
corticalthickness('${surf}','${hemi}');
M_PROG
