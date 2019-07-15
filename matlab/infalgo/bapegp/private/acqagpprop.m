function acq = acqagpprop(Xs,vbmodel,gp,options,transpose_flag)
%ACQAGPPROP Acquisition function for AGP via entropy maximization and
%proposal fcn regularization.

if nargin < 5 || isempty(transpose_flag); transpose_flag = false; end

% Transposed input (useful for CMAES)
if transpose_flag; Xs = Xs'; end

% Probability density of vbgmm at test points
p = vbgmmpdf(vbmodel,Xs')';

% Search proposal function
yp = options.ProposalFcn(Xs);
yp = max(yp,realmin);

% GP mean and variance for each hyperparameter sample
[~,~,fmu,fs2] = gplite_pred(gp,Xs,[],[],1);

Ns = size(fmu,2);
fbar = sum(fmu,2)/Ns;   % Mean across samples
vbar = sum(fs2,2)/Ns;   % Average variance across samples
if Ns > 1; vf = sum((fmu - fbar).^2,2)/(Ns-1); else; vf = 0; end  % Sample variance
vtot = vf + vbar;       % Total variance

acq = -(fbar + 0.5 + 0.5*log(2*pi*vtot) + 0.5*log(p) + 0.5*log(yp));
acq = max(acq,-realmax);

% Transposed output
if transpose_flag; acq = acq'; end


end