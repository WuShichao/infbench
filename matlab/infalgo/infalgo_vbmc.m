function [history,post,algoptions] = infalgo_vbmc(algo,algoset,probstruct)

algoptions = vbmc('all');                   % Get default settings

ControlRunFlag = false;     % Do NOT run in control mode

% VBMC old defaults -- some of these may have changed
algoptions.FunEvalsPerIter = 5;
algoptions.AcqFcn = '@vbmc_acqskl';

algoptions.MinFunEvals = probstruct.MaxFunEvals;
algoptions.MaxFunEvals = probstruct.MaxFunEvals;
algoptions.MinIter = 0;     % No limits on iterations
algoptions.MaxIter = Inf;
algoptions.WarpNonlinear = 'off';   % No nonlinear warping for now

if probstruct.Debug
    algoptions.TrueMean = probstruct.Post.Mean;
    algoptions.TrueCov = probstruct.Post.Cov;
end

% Use prior as proposal function
algoptions.ProposalFcn = @(X_) exp(infbench_lnprior(X_,probstruct));

% Options from current problem
switch algoset
    case {0,'debug'}; algoset = 'debug'; algoptions.Debug = 1; algoptions.Plot = 'on';
    case {1,'base'}; algoset = 'base';           % Use defaults
    case {2,'acqus'}; algoset = 'acqus'; algoptions.SearchAcqFcn = @vbmc_acqus;
    case {3,'acqev'}; algoset = 'acqev'; algoptions.SearchAcqFcn = @vbmc_acqev;
    case {4,'detvars5'}; algoset = 'detvars'; algoptions.DetEntropyMinD = 5; 
    case {5,'detvars3'}; algoset = 'detvars'; algoptions.DetEntropyMinD = 3;
    case {6,'newbnd'}; algoset = 'newbnd'; % Changed variational posterior bounds
    case {7,'K1'}; algoset = 'K1'; algoptions.Kfun = 1; algoptions.KfunMax = 1; algoptions.Kwarmup = 1;
    case {8,'acqf2'}; algoset = 'acqf2'; algoptions.SearchAcqFcn = @vbmc_acqf2;
    case {9,'acqf'}; algoset = 'acqf'; algoptions.SearchAcqFcn = @vbmc_acqf;
    case {10,'acqf1'}; algoset = 'acqf1'; algoptions.SearchAcqFcn = @vbmc_acqf1;
    case {11,'acqfreg'}; algoset = 'acqfreg'; algoptions.SearchAcqFcn = @vbmc_acqfreg;
    case {12,'new'}; algoset = 'new'; algoptions.SearchAcqFcn = @vbmc_acqfreg; algoptions.StableGPSamples = 2;
        
        
        
        
    otherwise
        error(['Unknown algorithm setting ''' algoset ''' for algorithm ''' algo '''.']);
end

% Increase base noise with noisy functions
if ~isempty(probstruct.Noise) || probstruct.IntrinsicNoisy
    algoptions.UncertaintyHandling = 'on';
    NoiseEstimate = probstruct.NoiseEstimate;
    if isempty(NoiseEstimate); NoiseEstimate = 1; end    
    algoptions.NoiseSize = NoiseEstimate(1);
else
    algoptions.UncertaintyHandling = 'off';
end

PLB = probstruct.PLB;
PUB = probstruct.PUB;
LB = probstruct.LB;
UB = probstruct.UB;
x0 = probstruct.InitPoint;
D = size(x0,2);

% Add log prior to function evaluation 
% (the current version of VBMC is agnostic of the prior)
probstruct.AddLogPrior = true;

algo_timer = tic;
[vp,elbo,elbo_sd,exitflag,output,stats] = ...
    vbmc(@(x) infbench_func(x,probstruct),x0,LB,UB,PLB,PUB,algoptions);
TotalTime = toc(algo_timer);

% Remove training data from GPs, too bulky (can be reconstructed)
for i = 1:numel(stats.gp)
    stats.gp(i).X = [];
    stats.gp(i).y = [];
end

if ~ControlRunFlag
    
    history = infbench_func(); % Retrieve history
    history.scratch.output = output;
    history.TotalTime = TotalTime;
    history.Output.stats = stats;
    
    % Store computation results (ignore points discarded after warmup)
    history.Output.X = output.X_orig(output.X_flag,:);
    history.Output.y = output.y_orig(output.X_flag);
    post.lnZ = elbo;
    post.lnZ_var = elbo_sd^2;
    [post.gsKL,post.Mean,post.Cov,post.Mode] = computeStats(vp,probstruct);

    % Return estimate, SD of the estimate, and gauss-sKL with true moments
    Nticks = numel(history.SaveTicks);
    for iIter = 1:Nticks
        idx = find(stats.N == history.SaveTicks(iIter),1);
        if isempty(idx); continue; end
        
        % VBMC would return the current variational solution only if stable,
        % otherwise it would return a recent solution with best ELCBO 
        % (and warn the user of lack of stability)
        if stats.stable(idx)
            idx_safe = idx;
        else
            laststable = find(stats.stable(1:idx),1,'last');
            if isempty(laststable)
                BackIter = ceil(idx*0.25);  % Go up to this iterations back if no previous stable iteration
                idx_start = max(1,idx-BackIter);
            else
                idx_start = laststable;
            end
            SafeSD = 5; % Large penalization for uncertainty
            lnZ_iter = stats.elbo(idx_start:idx);
            lnZsd_iter = stats.elboSD(idx_start:idx);        
            elcbo = lnZ_iter - SafeSD*lnZsd_iter;
            [~,idx_safe] = max(elcbo);
            % [~,idx_safe] = min(lnZsd_iter);
            idx_safe = idx_start + idx_safe - 1;
        end
        
        history.Output.N(iIter) = history.SaveTicks(iIter);
        history.Output.lnZs(iIter) = stats.elbo(idx_safe);
        history.Output.lnZs_var(iIter) = stats.elboSD(idx_safe)^2;
        [gsKL,Mean,Cov,Mode] = computeStats(stats.vp(idx_safe),probstruct);
        history.Output.Mean(iIter,:) = Mean;
        history.Output.Cov(iIter,:,:) = Cov;
        history.Output.gsKL(iIter) = gsKL;
        history.Output.Mode(iIter,:) = Mode;    
    end
else
    % Control condition -- run VBMC as normal but compute marginal likelihood
    % and posterior via other methods

    history = infbench_func(); % Retrieve history
    
    % Start warmup
    
    % Store all points (no warmup pruning)
    X = output.X_orig(1:output.Xmax,:);
    y = output.y_orig(1:output.Xmax);
    Niter = find(size(X,1) == history.SaveTicks,1);
    N = history.SaveTicks(1:Niter);
    
    % Find when warm-up ends
    idx = find(stats.vpK > 2,1);
    if isempty(idx); endWarmupN = Inf; else; endWarmupN = stats.N(idx); end
    
    mu = zeros(1,Niter);
    ln_var = zeros(1,Niter);

    % Parameters for WSABI
    diam = probstruct.PUB - probstruct.PLB;
    kernelCov = diag(diam/10);     % Input length scales for GP likelihood model
    lambda = 1;                     % Ouput length scale for GP likelihood model
    alpha = 0.8;
    
    for iIter = 1:Niter        
        X_train = X(1:N(iIter),:);
        y_train = y(1:N(iIter));
        % Prune trials after warmup
        if N(iIter) >= endWarmupN
            idx_keep = output.X_flag(1:N(iIter));
            X_train = X_train(idx_keep,:);
            y_train = y_train(idx_keep);
        end
        X_iter{iIter} = X_train;
        y_iter{iIter} = y_train;
        lnp = infbench_lnprior(X_train,probstruct);
        y_train = y_train - lnp;  % Remove log prior for WSABI
        [mu(iIter),ln_var(iIter)] = ...
            wsabi_oneshot('L',probstruct.PriorMean,diag(probstruct.PriorVar),kernelCov,lambda,alpha,X_train,y_train);
    end
    vvar = max(real(exp(ln_var)),0);
    
    [history,post] = ...
        StoreAlgoResults(probstruct,[],Niter,X_iter{Niter},y_iter{Niter},mu,vvar,X_iter,y_iter,TotalTime);
    history.scratch.output = output;
    history.Output.stats = stats;    
    
end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [gsKL,Mean,Cov,Mode] = computeStats(vp,probstruct)
%COMPUTE_STATS Compute additional statistics.
    
% Compute Gaussianized symmetric KL-divergence with ground truth
Ns_moments = 1e6;
xx = vbmc_rnd(Ns_moments,vp,1,1);
Mean = mean(xx,1);
Cov = cov(xx);
[kl1,kl2] = mvnkl(Mean,Cov,probstruct.Post.Mean,probstruct.Post.Cov);
gsKL = 0.5*(kl1 + kl2);

% Compute mode
Mode = vbmc_mode(vp,1);

end
