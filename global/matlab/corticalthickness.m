function [ thickness ] = corticalthickness(surf,hemi)
%Calculates Cortical Thickness from a White and Pial Surface

[white faces] = read_surf([surf '/' hemi '.white']);
[pial faces] = read_surf([surf '/' hemi '.pial']);

mask = read_curv([surf '/' hemi '.thickness']);

thickness = -1 * ((white(:,1) - pial(:,1)).^2 + (white(:,2) - pial(:,2)).^2 + (white(:,3) - pial(:,3)).^2).^0.5;

thickness(mask == 0) = 0;

truncations = sum(thickness < -6);
disp(['There were ' num2str(truncations) ' truncations at 6mm']);
thickness(thickness < -6) = -6;

write_curv([surf '/' hemi '.thickness'],thickness,length(faces));

end

