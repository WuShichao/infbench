function [X,y,exitflag,output,vbmodel] = bapegp(fun,x0,LB,UB,PLB,PUB,options)
%BAPEGP Bayesian adaptive posterior estimation inference via Gaussian processes.
%
% This function implements both the BAPE [1] and AGP [2] posterior inference 
% methods.

% References:
% 1. Kandasamy, K., Schneider, J., & P�czos, B. (2017). Query efficient 
% posterior estimation in scientific experiments via Bayesian active learning. 
% Artificial Intelligence, 243, 45-56.
% 2. Wang, H., & Li, J. (2017). Adaptive Gaussian process approximation 
% for Bayesian inference with expensive likelihood functions. 
% arXiv preprint arXiv:1703.09930.

% Code by Luigi Acerbi (2018).

% Check existence of GPlite toolbox in path
if ~exist('gplite_train.m','file')
    error('bapegp:NoGPliteToolbox','The GPlite toolbox needs to be in the MATLAB path to run BAPEGP.');
end

exitflag = 0;   % To be used in the future
D = size(x0,2);

% Check hard and plausible bounds
if isempty(LB); LB = -Inf; end
if isempty(UB); UB = Inf; end
if isscalar(LB); LB = LB*ones(1,D); end
if isscalar(UB); UB = UB*ones(1,D); end
if isempty(PLB); PLB = LB; end
if isempty(PUB); PUB = UB; end
if isscalar(PLB); PLB = PLB*ones(1,D); end
if isscalar(PUB); PUB = PUB*ones(1,D); end
if any(~isfinite(PLB)) || any(~isfinite(PUB))
    error('bapegp:NotFinitePB','Plausible lower/upper bounds need to be finite.');
end

%% Algorithm options and defaults

% Shared options between BAPE and AGP
defopts.Algorithm = 'bape';             % Algorithm ('bape' or 'agp')
defopts.MaxFunEvals = D*100;            % Maximum number of fcn evals
defopts.NsMax_gp = 0;                   % Max GP hyperparameter samples (0 = optimize)
defopts.StopGPSampling = 200 + 10*D;    % Training set size for switching to GP hyperparameter optimization (if sampling)
defopts.AcqFun = [];                    % Acquisition function
defopts.Plot = 0;                       % Make diagnostic plots at each iteration
defopts.FracExpand = 0.1;               % Expand search box by this amount
defopts.ProposalFcn = @(x) agp_proposal(x,PLB,PUB); % Proposal fcn based on PLB and PUB (unused)

% BAPE-only options
defopts.Meanfun = 'const';              % GP mean function for BAPE (for AGP always zero)

% AGP-only options for mixture-of-Gaussians posterior approximation
defopts.Ns = 2e4;                       % Number of MCMC samples to get approximate posterior
defopts.SamplingMethod = 'parallel';    % MCMC sampler for approximate posterior
defopts.NcompMax = 30;                  % Maximum number of mixture components


for f = fields(defopts)'
    if ~isfield(options,f{:}) || isempty(options.(f{:}))
        options.(f{:}) = defopts.(f{:});
    end
end

switch lower(options.Algorithm)
    case 'bape'
        if isempty(options.AcqFun)
            options.AcqFun = @acqbapeEV;
        end       
        
        gp_meanfun = options.Meanfun;
        gpsample_flag = options.Plot;   % Sample posterior from GP only for visualization
        vbgmm_flag = false;             % Does not use GMM approximation
        
    case 'agp'
                
        if isempty(options.AcqFun)
            options.AcqFun = @acqagp;
        end
        
        gp_meanfun = 'zero';    % Constant-zero mean function
        gpsample_flag = true;   % Sample posterior from GP
        vbgmm_flag = true;      % Builds GMM posterior approximation
        
    otherwise
        error('bapegp:UnknownAlgorithm','Unknown inference algorithm. Available methods are ''bape'' (default) or ''agp''.');
        
end

% Convert AcqFun to function handle if passed as a string
if ischar(options.AcqFun); options.AcqFun = str2func(options.AcqFun); end

Ninit = 20;     % Initial design
Nstep = 10;     % Training points at each iteration
Nsearch = 2^13; % Starting search points for acquisition fcn

% GPLITE model options
gpopts.Nopts = 1;       % Number of hyperparameter optimization runs
gpopts.Ninit = 2^10;    % Initial design size for hyperparameter optimization
gpopts.Thin = 5;        % Thinning for hyperparameter sampling (if sampling)

% Setup options for CMA-ES optimization
cmaes_opts = cmaes_modded('defaults');
cmaes_opts.EvalParallel = 'yes';
cmaes_opts.DispFinal = 'off';
cmaes_opts.SaveVariables = 'off';
cmaes_opts.DispModulo = Inf;
cmaes_opts.LogModulo = 0;
cmaes_opts.LBounds = LB(:);
cmaes_opts.UBounds = UB(:);
cmaes_opts.CMA.active = 1;      % Use Active CMA (generally better)

if vbgmm_flag
    % Add variational Gaussian mixture model toolbox to path
    mypath = fileparts(mfilename('fullpath'));
    addpath([mypath filesep 'vbgmm']);       
        
    % Variational Bayesian Gaussian mixture options
    vbopts.Display     = 'off';        % No display
    vbopts.TolBound    = 1e-8;         % Minimum relative improvement on variational lower bound
    vbopts.Niter       = 2000;         % Maximum number of iterations
    vbopts.Nstarts     = 1;            % Number of runs
    vbopts.TolResponsibility = 0.5;    % Remove components with less than this total responsibility
    vbopts.ClusterInit = 'kmeans';     % Initialization of VB (methods are 'rand' and 'kmeans')
else
    vbmodel = [];
end

lnZ = NaN;  lnZ_var = NaN;

%% Initialization

% Evaluate fcn on random starting grid
Nrnd = Ninit - size(x0,1);
Xrnd = bsxfun(@plus,PLB,bsxfun(@times,PUB-PLB,rand(Nrnd,D)));
X = [x0;Xrnd];
X = bsxfun(@min,bsxfun(@max,LB,X),UB);  % Force X inside hard bounds
y = zeros(Ninit,1);
for i = 1:Ninit; y(i) = fun(X(i,:)); end

width = 0.5*(PUB - PLB);
switch lower(options.Algorithm)
    case 'bape'
        hyp = [];   % Use standard GPlite starting hyperparameter vector
    
    case 'agp'
        % Draw initial samples
        mu0 = 0.5*(PLB + PUB);
        sigma0 = width;
        Xs = bsxfun(@plus,bsxfun(@times,sigma0,randn(options.Ns,D)),mu0);
        Xs = bsxfun(@min,bsxfun(@max,LB,Xs),UB);  % Force Xs inside hard bounds

        % Fit single Gaussian to initial pdf as a VBGMM object
        vbmodel = vbgmmfit(Xs',1,[],vbopts);

        % Starting GP hyperparameter vector
        hyp = [log(width(:));log(std(y));log(1e-3)];            
end


%% Main loop
iter = 1;
while 1
    fprintf('Iter %d...', iter);
    N = size(X,1);
    
    fprintf(' Building GP approximation...');
    
    % How many hyperparameter samples?
    Ns_gp = min(round(options.NsMax_gp/10),round(options.NsMax_gp / sqrt(N)));
    if N >= options.StopGPSampling; Ns_gp = 0; end
    
    switch lower(options.Algorithm)
        case 'bape'    
            y_gp = y;
        case 'agp'
            % For AGP, fit difference wrt current posterior
            py = vbgmmpdf(vbmodel,X');      % Evaluate approximation at X    
            y_gp = y - log(py(:));          % Log difference
    end
    
    % At any given iteration only keep good points (necessary for stability)
    idx = isfinite(y_gp);
    X_gp = X(idx,:);
    y_gp = y_gp(idx);
    
    % Train GP
    hypprior = getGPhypprior(X_gp);    % Get prior over GP hyperparameters    
    [gp,hyp] = gplite_train(hyp,Ns_gp,X_gp,y_gp,gp_meanfun,hypprior,[],gpopts);
    
    % Sample from GP, if needed
    if gpsample_flag
        fprintf(' Sampling from GP...');
        switch lower(options.Algorithm)
            case 'bape'
                % Check bounds
                lnpfun = @(x) lnprior(x,[],LB,UB);
            case 'agp'
                % Add approximate log posterior and check bounds
                lnpfun = @(x) lnprior(x,vbmodel,LB,UB);
        end

        try
            Xs = gplite_sample(gp,options.Ns,[],options.SamplingMethod,lnpfun);
        catch
            error('bapegp:BadSampling','Unable to sample from approximate posterior due to numerical instabilities.');
        end

        % Plot current approximate posterior and training points
        if options.Plot
            %Xrnd = vbgmmrnd(vbmodel,1e4)';
            %cornerplot(Xrnd);    
            for i = 1:D; names{i} = ['x_{' num2str(i) '}']; end
            [~,ax] = cornerplot(Xs,names);
            for i = 1:D-1
                for j = i+1:D
                    axes(ax(j,i));  hold on;
                    scatter(X(:,i),X(:,j),'ok');
                end
            end
            drawnow;
        end
    end
    
    % Refit vbGMM
    if vbgmm_flag
        fprintf(' Refit vbGMM...\n');
        vbmodel = vbgmmfit(Xs',options.NcompMax,[],vbopts);

        %Xrnd = vbgmmrnd(vbmodel,1e5)';
        %Mean = mean(Xrnd,1);
        %Cov = cov(Xrnd);

        % Estimate normalization constant in HPD region
        [lnZ,lnZ_var] = estimate_lnZ(X,y,vbmodel);

        fprintf('Estimate of lnZ = %f +/- %f.\n',lnZ,sqrt(lnZ_var));
    end
    
    % Record stats
    stats(iter).N = N;
    % stats(iter).Mean = Mean;
    % stats(iter).Cov = Cov;
    stats(iter).lnZ = lnZ;
    stats(iter).lnZ_var = lnZ_var;
    stats(iter).gp = gplite_clean(gp);
    if vbgmm_flag
        stats(iter).vbmodel = vbmodel;
    end
    
    % Find max of approximation among GP samples and record approximate mode
    if vbgmm_flag
        ys = vbgmmpdf(vbmodel,Xs')';
        [~,idx] = max(ys);
        stats(iter).mode = Xs(idx,:);
    end
    
    if N >= options.MaxFunEvals; break; end
    
    % Select new points
    fprintf(' Active sampling...');
    for iNew = 1:Nstep
        
        if vbgmm_flag; Nsearch_rnd = floor(Nsearch/2); else Nsearch_rnd = Nsearch; end
        
        fprintf(' %d..',iNew);
        % Random uniform search inside search box
        width = max(X) - min(X);
        lb = min(X) - width*options.FracExpand; ub = max(X) + width*options.FracExpand;
        lb = max(LB,min(lb,PLB)); ub = min(UB,max(ub,PUB));
        [xnew,fval] = fminfill(@(x) options.AcqFun(x,vbmodel,gp,options),[],[],[],lb,ub,[],struct('FunEvals',Nsearch_rnd));
        
        if vbgmm_flag
            Nsearch_vbgmm = Nsearch - Nsearch_rnd;
            % Random search sample from vbGMM
            xrnd = vbgmmrnd(vbmodel,Nsearch_vbgmm)';
            xrnd = bsxfun(@min,bsxfun(@max,LB,xrnd),UB);  % Force Xs inside hard bounds
            frnd = options.AcqFun(xrnd,vbmodel,gp,options);
            [frnd_min,idx] = min(frnd);        
            if frnd_min < fval; xnew = xrnd(idx,:); fval = frnd_min; end
        end

        % Optimize from best point with CMA-ES
        insigma = (max(X) - min(X))'/sqrt(3);
        [xnew_cmaes,fval_cmaes] = cmaes_modded(func2str(options.AcqFun),xnew',insigma,cmaes_opts,vbmodel,gp,options,1);
        if fval_cmaes < fval; xnew = xnew_cmaes'; end
        
        % Add point
        ynew = fun(xnew);
        X = [X; xnew];
        y = [y; ynew];
        
        switch lower(options.Algorithm)
            case 'bape'
                ynew_gp = ynew;
            case 'agp'
                py = vbgmmpdf(vbmodel,xnew');   % Evaluate approximation at X    
                ynew_gp = ynew - log(py);       % Log difference
        end

        gp = gplite_post(gp,xnew,ynew_gp,[],1);   % Rank-1 update
        
        % Plot new candidate points
        if options.Plot
            for i = 1:D-1
                for j = i+1:D
                    axes(ax(j,i));  hold on;
                    scatter(xnew(:,i),xnew(:,j),'or','MarkerFaceColor','r');
                end
            end
            drawnow;
        end

    end
    fprintf('\n');
    
    iter = iter + 1;
end

output.X = X;
output.y = y;
output.stats = stats;

end

%--------------------------------------------------------------------------
function lp = lnprior(x,vbmodel,LB,UB)
%LNPRIOR Log prior and base function for approximate posterior.

% log_realmin = -708.3964185322641;   % Log of minimum nonzero double

if ~isempty(vbmodel)
    lp = log(vbgmmpdf(vbmodel,x'))';
    % lp = max(lp,log_realmin);  % Avoid infinities here
else
    lp = zeros(size(x,1),1);
end
    
if any(isfinite(LB)) || any(isfinite(UB))
    idx = any(bsxfun(@gt,x,UB),2) | any(bsxfun(@lt,x,LB),2);
    lp(idx) = -Inf;
end

end

%--------------------------------------------------------------------------
function [lnZ,lnZ_var] = estimate_lnZ(X,y,vbmodel)
%ESTIMATE_LNZ Rough approximation of normalization constant

hpd_frac = 0.2;     % Top 20% HPD
N = size(X,1);

lp = log(vbgmmpdf(vbmodel,X')');

% Take HPD points according to both fcn samples and model
[~,ord] = sort(lp + y,'descend');

idx_hpd = ord(1:ceil(N*hpd_frac));
lp_hpd = lp(idx_hpd);
y_hpd = y(idx_hpd);

delta = -(lp_hpd - y_hpd);

lnZ = mean(delta);
lnZ_var = var(delta)/numel(delta);

end

%--------------------------------------------------------------------------
function hypprior = getGPhypprior(X)
%GETGPHYPPRIOR Define empirical Bayes prior over GP hyperparameters.

D = size(X,2);
hypprior = [];
Nhyp = D+2;
hypprior.mu = NaN(1,Nhyp);
hypprior.sigma = NaN(1,Nhyp);
hypprior.df = 3*ones(1,Nhyp);    % Broad Student's t prior
hypprior.mu(1:D) = log(std(X));
hypprior.sigma(1:D) = max(2,log(max(X)-min(X)) - log(std(X)));
hypprior.mu(D+2) = log(1e-2);
hypprior.sigma(D+2) = 0.5;
    
end