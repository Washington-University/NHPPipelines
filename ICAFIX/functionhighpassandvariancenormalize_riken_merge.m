function [ output_args ] = functionhighpassandvariancenormalize(TR,hp,fmri,WBC,varargin)



%UNTITLED4 Summary of this function goes here
%   Detailed explanation goes here
%   Default value: ndhpvol=2;ndhpcifti=3; ndvol=3; - Takuya Hayashi, Matt Glasser
fprintf('hp=%d, ndist=%d,%d,%d',hp,ndhpvol,ndhpcifti,ndvol)


regstring = '';
dovol = 1;
%%if length(varargin) > 0 && ~strcmp(varargin{1}, '')
%%    dovol = 0;%regname is only used for a new surface registration, so will never require redoing volume
%%    regstring = varargin{1};%this has the underscore on the front already
if length(varargin) == 1 && ~isempty(varargin{1})
  dovol = 0; %regname is only used for a new surface registration, so will never require redoing volume
  regstring = varargin{1}; %this has the underscore on the front already
  ndhpvol=2
  ndhpcifti=3
  ndvol=3
  if ~ischar(regstring)
	error('%s: REGSTRING should be a string', mfilename);
  end
elseif length(varargin) >= 3
  if ~isempty(varagin{4})
    dovol = 0
    regstring = varargin{4}
    if ~ischar(regstring)
	  error('%s: REGSTRING should be a string', mfilename);
    end
  end
  ndhpvol=varargin{1}
  ndhpcifti=varargin{2}
  ndvol=varargin{3}
  if ~isint(ndhpvol)
    error('%s: NDHPVOL should be an integer', mfilename);
  end
  if ~isint(ndhpcifti)
    error('%s: NDHPCIFTI should be an integer', mfilename);
  end
  if ~isint(ndvol)
	error('%s: NDVOL should be an integer', mfilename);
  end
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
        Outcts=icaDim(cts,0,1,-1,ndhpvol); %0=Don't detrend, 1=Initialize variance normalization at 1, -1=Converge with running dim average, Volume fits two distributions to deal with MNI transform 
    end

    OutBO=icaDim(BO.cdata,0,1,-1,ndhpcifti); %0=Don't detrend, 1=Initialize variance normalization at 1, -1=Converge with running dim average, CIFTI fits three distributions to deal with volume to CIFTI mapping
else
    if dovol > 0
        Outcts=icaDim(cts,0,1,-1,ndvol); %0=Don't detrend, 1=Initialize variance normalization at 1, -1=Converge with running dim average, Volume fits two distributions to deal with MNI transform  
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
%% ----------------------------------------------

%% Polynomial detrending function
function Y = detrendpoly(X,p);

% X: Input data (column major order)
% p: Order of polynomial to remove
% Y: Detrended output
  
% Need to define a function to accomplish this, because MATLAB's own DETREND
% is only capable of removing a *linear* trend (i.e., "p=1" only)
  
  % Check data, must be in column order
  [m, n] = size(X);
  if (m == 1)
	X = X';
	r=n;
  else
	r=m;
  end
  
  if (~isscalar(p) || p < 0 || p ~= fix(p))
	error('order of polynomial (p) must be a non-negative integer');
  end
  
  % 5/1/2019 -- Construct the "Vandermonde matrix" (V) scaled to a maximum of 1, for better numerical properties.
  % Note that Octave's DETREND function supports arbitrary polynomial orders, but computes V by taking powers
  % of [1:r] (rather than [1:r]/r), which is not numerically robust as p increases.
  
  V = ([1 : r]'/r * ones (1, p + 1)) .^ (ones (r, 1) * [0 : p]);  % "Vandermonde" design matrix
  
  % Cast design matrix to 'single' if the input is also 'single' (which CIFTI will be)
  if strcmp(class(X),'single')
	V = single(V);
  end
  
  % Use mldivide ('\') as the linear solver, as it has the nice property of generating a warning
  % if the solution is rank deficient (in MATLAB at least; Octave doesn't appear to generate a similar warning).
  % [In contrast, PINV does NOT generate a warning if the singular values are less than its internal tolerance].
  % Note that even with the scaling of the Vandermonde matrix to a maximum of 1, rank deficiency starts
  % becoming a problem at p=6 for data of class 'single' and 1200 time points.
  % Rather than explicitly restricting the allowed order here, we'll code a restriction into the calling scripts.
  
  Y = X - V * (V \ X);  % Remove polynomial fit

end

