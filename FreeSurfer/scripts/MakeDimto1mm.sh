#!/bin/bash

# Make image interpolated to 1mm-resolution for FS (human) or Make scaled image interpolated to 1mm-resolution

CMD=`echo $0 | sed -e 's/^\(.*\)\/\([^\/]*\)/\2/'`

usage_exit() {
      cat <<EOF

  Create interpolated image to 1mm-resolution with a matrix of 256 x 256 x 256.

  Usage: $CMD <species> <input image> [interp]

  Ouput is <input image>_1mm.nii.gz

  Options:
     species - Human, Chimp, Macaque or Marmoset
     interp  - nn or spline (only valid for human)

EOF
    exit 1;
}

[ "$2" = "" ] && usage_exit

T1wImage=`remove_ext $2`
out=${T1wImage}_1mm
interp=spline
if [ "$3" != "" ] ; then
  interp=$3
fi

if [ "$1" = "Human" ] ; then

	flirt -interp spline -in "$T1wImage" -ref "$T1wImage" -applyisoxfm 1 -out "$T1wImage"_1mm.nii.gz
	applywarp --rel --interp=${interp} -i "$T1wImage" -r "$T1wImage"_1mm.nii.gz --premat=$FSLDIR/etc/flirtsch/ident.mat -o "$T1wImage"_1mm.nii.gz

else

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

	imcp "$T1wImage" "$out"
	fslorient -setsform $newsform "$out"
	fslhd -x "$out" | sed s/"dx = '${res}'"/"dx = '1'"/g | sed s/"dy = '${res}'"/"dy = '1'"/g | sed s/"dz = '${res}'"/"dz = '1'"/g | fslcreatehd - "$out"_head.nii.gz
	fslmaths "$out"_head.nii.gz -add "$out" "$out"
	fslorient -copysform2qform "$out"
	rm "$out"_head.nii.gz
	size=256
	dimex=`fslval "$out" dim1`
	dimey=`fslval "$out" dim2`
	dimez=`fslval "$out" dim3`
	if [ $dimex -gt 254 ] || [ $dimey -gt 254 ] || [ $dimez -gt 254 ] ; then
 		echo "Error: matrix of input image should be less than 255 x 255 x 255"; exit 1
	fi
	padx=`echo "($size - $dimex) / 2" | bc`
	pady=`echo "($size - $dimey) / 2" | bc`
	padz=`echo "($size - $dimez) / 2" | bc`
	padx2=`echo "$size - $dimex - $padx" | bc`
	pady2=`echo "$size - $dimey - $pady" | bc`
	padz2=`echo "$size - $dimez - $padz" | bc`

	echo $padx $dimex $padx2
	echo $pady $dimey $pady2
	echo $padz $dimez $padz2

	fslcreatehd $padx $dimey $dimez 1 1 1 1 1 0 0 0 16 "$out"_padx
	fslcreatehd $padx2 $dimey $dimez 1 1 1 1 1 0 0 0 16 "$out"_padx2
	fslmerge -x "$out" "$out"_padx2 "$out" "$out"_padx
	fslcreatehd $size $pady $dimez 1 1 1 1 1 0 0 0 16 "$out"_pady
	fslcreatehd $size $pady2 $dimez 1 1 1 1 1 0 0 0 16 "$out"_pady2
	fslmerge -y "$out" "$out"_pady2 "$out" "$out"_pady
	fslcreatehd $size $size $padz 1 1 1 1 1 0 0 0 16 "$out"_padz
	fslcreatehd $size $size $padz2 1 1 1 1 1 0 0 0 16 "$out"_padz2
	fslmerge -z "$out" "$out"_padz2 "$out" "$out"_padz

	fslorient -setsformcode 1 "$out"
	neworiginx=`echo "$originx + $padx2" | bc -l`
	neworiginy=`echo "$originy - $pady2" | bc -l`
	neworiginz=`echo "$originz - $padz2" | bc -l`
	echo "`echo "1 / $res" | bc -l` 0 0 $padx2"
	echo "0 `echo "1 / $res" | bc -l` 0 $pady2"
	echo "0 0 `echo "1 / $res" | bc -l` $padz2"
	echo "0 0 0 1"
	fslorient -setsform -1 0 0 $neworiginx 0 1 0 $neworiginy 0 0 1 $neworiginz 0 0 0 1 "$out"
	rm "$out"_padx.nii.gz "$out"_pady.nii.gz "$out"_padz.nii.gz "$out"_padx2.nii.gz "$out"_pady2.nii.gz "$out"_padz2.nii.gz

fi

exit 0
