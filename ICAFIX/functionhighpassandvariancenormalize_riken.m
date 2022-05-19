function [ output_args ] = functionhighpassandvariancenormalize(TR,hp,fmri,WBC,ndhpvol,ndhpcifti,ndvol,varargin)

%UNTITLED4 Summary of this function goes here
%   Detailed explanation goes here
%   Default value: ndhpvol=2;ndhpcifti=3; ndvol=3; - Takuya Hayashi, Matt Glasser
fprintf('hp=%d, ndist=%d,%d,%d',hp,ndhpvol,ndhpcifti,ndvol)


regstring = '';
dovol = 1;
if length(varargin) > 0 && ~strcmp(varargin{1}, '')
    dovol = 0;%regname is only used for a new surface registration, so will never require redoing volume
    regstring = varargin{1};%this has the underscore on the front already
end

if dovol > 0
cts=single(read_avw([fmri '.nii.gz']));
ctsX=size(cts,1); ctsY=size(cts,2); ctsZ=size(cts,3); ctsT=size(cts,4); 
cts=reshape(cts,ctsX*ctsY*ctsZ,ctsT);
end

if hp>=0
    confounds=load([fmri '_hp' num2str(hp) '.ica/mc/prefiltered_func_data_mcf.par']);
    confounds=confounds(:,1:6);
    confounds=functionnormalise([confounds [zeros(1,size(confounds,2)); confounds(2:end,:)-confounds(1:end-1,:)] ]);
    confounds=functionnormalise([confounds confounds.*confounds]);

    BO=ciftiopen([fmri '_Atlas' regstring '.dtseries.nii'],WBC);
else
    if dovol > 0
       cts=demean(cts')'; 
    end
end

if hp==0
    if dovol > 0
    save_avw(reshape(confounds',size(confounds,2),1,1,size(confounds,1)),[fmri '_hp' num2str(hp) '.ica/mc/prefiltered_func_data_mcf_conf'],'f',[1 1 1 TR]);
    confounds=detrend(confounds);
    save_avw(reshape(confounds',size(confounds,2),1,1,size(confounds,1)),[fmri '_hp' num2str(hp) '.ica/mc/prefiltered_func_data_mcf_conf_hp'],'f',[1 1 1 TR]);
    
    cts=detrend(cts')';
    save_avw(reshape(cts,ctsX,ctsY,ctsZ,ctsT),[fmri '_hp' num2str(hp) '.nii.gz'],'f',[1 1 1 TR]);
    call_fsl(['fslcpgeom ' fmri '.nii.gz ' fmri '_hp' num2str(hp) '.nii.gz']);
    end

    BO.cdata=detrend(BO.cdata')';
    ciftisave(BO,[fmri '_Atlas' regstring '_hp' num2str(hp) '.dtseries.nii'],WBC);
end
if hp>0
    if dovol > 0
      save_avw(reshape(confounds',size(confounds,2),1,1,size(confounds,1)),[fmri '_hp' num2str(hp) '.ica/mc/prefiltered_func_data_mcf_conf'],'f',[1 1 1 TR]);
      call_fsl(sprintf(['fslmaths ' fmri '_hp' num2str(hp) '.ica/mc/prefiltered_func_data_mcf_conf -bptf %f -1 ' fmri '_hp' num2str(hp) '.ica/mc/prefiltered_func_data_mcf_conf_hp'],0.5*hp/TR));
      if exist([fmri '_hp' num2str(hp) '.nii.gz'], 'file') == 0 % added by Takuya Hayashi
        save_avw(reshape(cts,ctsX,ctsY,ctsZ,ctsT),[fmri '_hp' num2str(hp) '.nii.gz'],'f',[1 1 1 TR]);
        call_fsl(['fslmaths ' fmri '_hp' num2str(hp) '.nii.gz -bptf ' num2str(0.5*hp/TR) ' -1 ' fmri '_hp' num2str(hp) '.nii.gz']);
      end
      cts=single(read_avw([fmri '_hp' num2str(hp) '.nii.gz']));
      cts=reshape(cts,ctsX*ctsY*ctsZ,ctsT);
      call_fsl(['fslcpgeom ' fmri '.nii.gz ' fmri '_hp' num2str(hp) '.nii.gz']);
    end

    BOdimX=size(BO.cdata,1);  BOdimZnew=ceil(BOdimX/100);  BOdimT=size(BO.cdata,2);
    save_avw(reshape([BO.cdata ; zeros(100*BOdimZnew-BOdimX,BOdimT)],10,10,BOdimZnew,BOdimT),'Atlas','f',[1 1 1 TR]);
    call_fsl(sprintf('fslmaths Atlas -bptf %f -1 Atlas',0.5*hp/TR));
    grot=reshape(single(read_avw('Atlas')),100*BOdimZnew,BOdimT);  BO.cdata=grot(1:BOdimX,:);  clear grot; 
    call_fsl('rm Atlas.nii.gz');
    ciftisave(BO,[fmri '_Atlas' regstring '_hp' num2str(hp) '.dtseries.nii'],WBC);

end

%Compute VN
if hp>=0
    if dovol > 0
    %Outcts=icaDim(cts,0,1,2,2); %Volume fits two distributions to deal with processing interpolation and multiband
    Outcts=icaDim(cts,0,1,2,ndhpvol); %Volume fits two distributions to deal with processing interpolation and multiband
    end
    %OutBO=icaDim(BO.cdata,0,1,2,3); %CIFTI fits three because of the effects of volume to CIFTI mapping and regularization
    OutBO=icaDim(BO.cdata,0,1,2,ndhpcifti); %CIFTI fits three because of the effects of volume to CIFTI mapping and regularization
else
    if dovol > 0
    %Outcts=icaDim(cts,0,1,2,3); %Volume fits three distributions to deal with processing interpolation and multiband and concatination effects
    Outcts=icaDim(cts,0,1,2,ndvol); % More repeated WF
    end
end

%Save VN
if hp>=0
    if dovol > 0
	    save_avw(reshape(Outcts.noise_unst_std,ctsX,ctsY,ctsZ,1),[fmri '_hp' num2str(hp) '_vn.nii.gz'],'f',[1 1 1 1]);
	    call_fsl(['fslcpgeom ' fmri '_mean.nii.gz ' fmri '_hp' num2str(hp) '_vn.nii.gz -d']);
    end 

    VN=BO;
    VN.cdata=OutBO.noise_unst_std;
    disp(['saving ' fmri '_Atlas' regstring '_hp' num2str(hp) '_vn.dscalar.nii']);
    ciftisavereset(VN,[fmri '_Atlas' regstring '_hp' num2str(hp) '_vn.dscalar.nii'],WBC);    
end

%Apply VN and Save HP_VN TCS
if dovol > 0
  cts=cts./repmat(Outcts.noise_unst_std,1,ctsT);
  if hp>=0
    save_avw(reshape(cts,ctsX,ctsY,ctsZ,ctsT),[fmri '_hp' num2str(hp) '_vnts.nii.gz'],'f',[1 1 1 1]); 
    call_fsl(['fslcpgeom ' fmri '.nii.gz ' fmri '_hp' num2str(hp) '_vnts.nii.gz -d']); 
  else
    save_avw(reshape(cts,ctsX,ctsY,ctsZ,ctsT),[fmri '_vnts.nii.gz'],'f',[1 1 1 1]); 
    call_fsl(['fslmaths ' fmri '.nii.gz -sub ' fmri '.nii.gz -add ' fmri '_vnts.nii.gz ' fmri '_vnts.nii.gz']); 
    %call_fsl(['fslcpgeom ' fmri '.nii.gz ' fmri '_vnf.nii.gz -d']); 
  end
end

if hp>=0
    BO.cdata=BO.cdata./repmat(OutBO.noise_unst_std,1,size(BO.cdata,2));
    ciftisave(BO,[fmri '_Atlas' regstring '_hp' num2str(hp) '_vn.dtseries.nii'],WBC); 
end

%Echo Dims
%TSC: add the regstring to the output filename to avoid overwriting
if hp>=0
    if dovol > 0
        dlmwrite([fmri regstring '_dims.txt'],[Outcts.calcDim OutBO.calcDim],'\t');
    else
        dlmwrite([fmri regstring '_dims.txt'],[OutBO.calcDim],'\t');
    end
else
    %TSC: this mode never gets called with a regstring
    dlmwrite([fmri '_dims.txt'],[Outcts.calcDim],'\t');
end

dlmwrite([fmri '_wf.txt'],[ndhpvol ndhpcifti ndvol],'\t');

end

