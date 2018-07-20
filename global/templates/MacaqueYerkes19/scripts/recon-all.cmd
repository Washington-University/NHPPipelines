#--------------------------------------
#@# SubCort Seg Fri Apr 20 21:14:48 CDT 2012

 mri_ca_label -align -nobigventricles norm.mgz transforms/talairach.m3z /media/myelin/brainmappers/MyelinMapping_Project/Templates/ChimpYerkes29/RB_all_2008-03-26.gca aseg.auto_noCCseg.mgz 


 mri_cc -aseg aseg.auto_noCCseg.mgz -o aseg.auto.mgz -lta /media/myelin/brainmappers/MyelinMapping_Project/Templates/MacaqueYerkes19/mri/transforms/cc_up.lta MacaqueYerkes19 

#--------------------------------------
#@# Merge ASeg Fri Apr 20 21:49:26 CDT 2012

 cp aseg.auto.mgz aseg.mgz 

