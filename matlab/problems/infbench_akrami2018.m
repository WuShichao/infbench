function [y,y_std] = infbench_akrami2018(x,infprob,mcmc_params)
%INFBENCH_AKRAMI2018 Inference benchmark log pdf -- exponential averaging model for mice data.

if nargin < 3; mcmc_params = []; end

problem_name = 'akrami2018';
infbench_fun = str2func(['infbench_' problem_name]);


if isempty(x)
    if isempty(infprob) % Generate this document        
        fprintf('\n');

        % Add sampler directory to MATLAB path
        pathstr = fileparts(mfilename('fullpath'));
        addpath([pathstr,filesep(),'..',filesep(),'infalgo',filesep(),'parallel-GP-SL',filesep(),'utils',filesep(),'mcmcstat-master']);
                
        for n = 1     
            name = ['S' num2str(n)];
            
            infprob = infbench_fun([],n);
            infprob.DeterministicFlag = true;
            if isempty(mcmc_params); id = 0; else; id = mcmc_params(1); end

            D = infprob.D;
            trinfo = infprob.Data.trinfo;
            
            % Prior used for sampling
            infprob.PriorMean = infprob.Prior.Mean;
            infprob.PriorVar = diag(infprob.Prior.Cov)';
            infprob.PriorVolume = prod(infprob.UB - infprob.LB);
            infprob.PriorType = 'uniform';            

            LB = infprob.LB;
            UB = infprob.UB;
            PLB = infprob.PLB;
            PUB = infprob.PUB;
            
            if id == 0
            
                % Compute optimum
                Nopts = 2;
                
                opts = struct('Display','iter','MaxFunEvals',2e3);

                for iOpt = 1:Nopts                
                    x0 = rand(1,D).*(PUB - PLB) + PLB;
                    fun = @(x) -infbench_fun(x,infprob);                    
                    [xnew(iOpt,:),fvalnew(iOpt)] = bads(fun,x0,LB,UB,PLB,PUB,[],opts);
                end
                
                [fvalnew,idx_best] = min(fvalnew);
                xnew = xnew(idx_best,:);
                
                fvalnew = -fvalnew;
                xmin = warpvars(xnew,'inv',trinfo);
                fval = fvalnew + warpvars(xnew,'logp',trinfo);

                x0 = xmin;
                x0 = warpvars(x0,'d',trinfo);   % Convert to unconstrained coordinates            
                fun = @(x) -logpost(x,infprob);
                [xnew,fvalnew] = bads(fun,x0,LB,UB,PLB,PUB,[],opts);

                fvalnew = -fvalnew;
                xmin_post = xmin;
                xmin_post = warpvars(xnew,'inv',trinfo);
                fval_post = fvalnew + warpvars(xnew,'logp',trinfo);

                fprintf('\t\t\tcase %d\n',n);
                fprintf('\t\t\t\tname = ''%s'';\n\t\t\t\txmin = %s;\n\t\t\t\tfval = %s;\n',name,mat2str(xmin),mat2str(fval));
                fprintf('\t\t\t\txmin_post = %s;\n\t\t\t\tfval_post = %s;\n',mat2str(xmin_post),mat2str(fval_post));
                
            elseif id > 0 && n == mcmc_params(2)

                rng(id);
                widths = 0.5*(PUB - PLB);
                logpfun = @(x) logpost(x,infprob);
                
                % Number of samples
                if numel(mcmc_params) > 2
                    Ns = mcmc_params(3);
                else
                    Ns = 1e3;
                end
                
                W = 2*(infprob.D+1);    % Number of walkers
                
                sampleopts.Thin = 17;
                sampleopts.Burnin = Ns*sampleopts.Thin;
                sampleopts.Display = 'notify';
                sampleopts.Diagnostics = false;
                sampleopts.VarTransform = false;
                sampleopts.InversionSample = false;
                sampleopts.FitGMM = false;
                sampleopts.TolX = 1e-5;
                % sampleopts.TransitionOperators = {'transSliceSampleRD'};

                x0 = infprob.Post.Mode;
                x0 = warpvars(x0,'d',trinfo);
                
                [Xs,lls,exitflag,output] = eissample_lite(logpfun,x0,Ns,W,widths,LB,UB,sampleopts);
                
%                 % Re-evaluate final lls with higher precision
%                 fprintf('Re-evaluate log posteriors...\n');
%                 infprob.Ng = 501;
%                 lls = zeros(size(Xs,1),1);
%                 for i = 1:size(Xs,1)
%                     lls(i) = logpost(Xs(i,:),infprob);
%                     if mod(i,ceil(size(Xs,1)/10))==0; fprintf('%d/%d..',i,size(Xs,1)); end
%                 end
%                 fprintf('\nDone.\n');
                
                
                filename = [problem_name '_mcmc_n' num2str(n) '_id' num2str(id) '.mat'];
                save(filename,'Xs','lls','exitflag','output');                
            end
            
        end
        
    else
        % Initialization call -- define problem and set up data
        n = infprob(1);
        
        % Are we transforming the entire problem to unconstrained space?
        transform_to_unconstrained_coordinates = false;
        
        % Add problem directory to MATLAB path
%        pathstr = fileparts(mfilename('fullpath'));
%        addpath([pathstr,filesep(),problem_name]);
        
        % Define parameter upper/lower bounds
        lb = [-3*ones(1,4),-3*ones(1,2)];
        ub = [3*ones(1,4),3*ones(1,2)];
        plb = [-1*ones(1,4),-1*ones(1,2)];
        pub = [1*ones(1,4),1*ones(1,2)];
        noise = [];
        
        D = numel(lb);
        xmin = NaN(1,D);       fval = Inf;
        xmin_post = NaN(1,D);  fval_post = Inf;
        Mean_mcmc = NaN(1,D);  Cov_mcmc = NaN(D,D);    lnZ_mcmc = NaN;
        
        if transform_to_unconstrained_coordinates
            trinfo = warpvars(D,lb,ub,plb,pub);     % Transform to unconstrained space
            trinfo.mu = zeros(1,D);     % Necessary for retro-compatibility
            trinfo.delta = ones(1,D);
        else
            trinfo = [];
        end
        
        switch n
			case 1
				name = 'S1';
				xmin = [0.601488995312693 0.92918748567871 -0.90322157872528 -1.25478386895628 0.532511789213771 -0.215398837418348];
				fval = -12641.3043560369;
				xmin_post = [0.601793829351664 0.929253306239843 -0.903550788760185 -1.25475757941604 0.532740216702223 -0.215424839407206];
				fval_post = -12652.054974019;
                % R_max = 1.006. Ntot = 100000. Neff_min = 89595.7. Total funccount = 8396758.
                Mean_mcmc = [-1.36599353769662 -1.88960972718479 0.0541149000000237 0.110712038723506 0.0359808007844354 1.6748398057123 3.43106825333691 3.30107447162769];
                Cov_mcmc = [0.0502558292505181 0.0216278640554018 -0.00254778518307619 -7.75848335730976e-05 -0.0014119610394125 -0.0508255600849554 -0.0585779610097104 -0.0956270554699201;0.0216278640554018 0.10742117182685 -0.00237775520878403 -0.00168170904989171 -0.000877626601615884 -0.0809046687360803 -0.195924043610106 -0.134970199535634;-0.00254778518307619 -0.00237775520878403 0.00295271996583016 -0.000117087352124262 6.9754685366636e-06 0.00049432562494269 0.00119688396822461 -0.000858448310023431;-7.75848335730976e-05 -0.00168170904989171 -0.000117087352124262 0.00461886362504913 -0.000579389274078338 -0.000833219854770625 -0.0166362120976628 -0.00868947613304207;-0.0014119610394125 -0.000877626601615884 6.9754685366636e-06 -0.000579389274078338 0.00105031720397544 0.000576735958176922 -0.00283347115137788 -0.00221829576363554;-0.0508255600849554 -0.0809046687360803 0.00049432562494269 -0.000833219854770625 0.000576735958176922 0.646187570396557 0.735503726514117 0.75944822900212;-0.0585779610097104 -0.195924043610106 0.00119688396822461 -0.0166362120976628 -0.00283347115137788 0.735503726514117 2.89967920153727 2.55845926948532;-0.0956270554699201 -0.134970199535634 -0.000858448310023431 -0.00868947613304207 -0.00221829576363554 0.75944822900212 2.55845926948532 2.4220775128761];
                lnZ_mcmc = -219.580300204325;
        end

        % Read and preprocess data
        temp = csvread('akrami2018_data.csv',1);
        x = temp(:,1:2);
        %x = x - min(x(:));
        %x = x / max(x(:));
        data.X = x;
        data.y = temp(:,3);
        data.Ntrials = size(x,1);
                
        xmin = warpvars(xmin,'d',trinfo);
        fval = fval + warpvars(xmin,'logp',trinfo);
        
        Mean = zeros(1,D);
        Cov = eye(D);
        Mode = xmin;
                
        y.D = D;
        y.LB = warpvars(lb,'d',trinfo);
        y.UB = warpvars(ub,'d',trinfo);
        y.PLB = warpvars(plb,'d',trinfo);
        y.PUB = warpvars(pub,'d',trinfo);
        
        y.lnZ = 0;              % Log normalization factor
        y.Mean = Mean;          % Distribution moments
        y.Cov = Cov;
        y.Mode = Mode;          % Mode of the pdf
        y.ModeFval = fval;
        
        priorMean = 0.5*(y.PUB + y.PLB);
        priorSigma2 = (0.5*(y.PUB - y.PLB)).^2;
        priorCov = diag(priorSigma2);
        y.Prior.Mean = priorMean;
        y.Prior.Cov = priorCov;
        
        % Compute each coordinate separately
        xmin_post = warpvars(xmin_post,'d',trinfo);
        fval_post = fval_post + warpvars(xmin_post,'logp',trinfo);
                
        y.Post.Mean = Mean_mcmc;
        y.Post.Mode = xmin_post;          % Mode of the posterior
        y.Post.ModeFval = fval_post;        
        y.Post.lnZ = lnZ_mcmc;
        y.Post.Cov = Cov_mcmc;
                
        data.IBSNreps = 200; % Reps used for IBS estimator
        
        % Read marginals from file
%        marginals = load([problem_name '_marginals.mat']);
%        y.Post.MarginalBounds = marginals.MarginalBounds{n};
%        y.Post.MarginalPdf = marginals.MarginalPdf{n};
        
        % Save data and coordinate transformation struct
        data.trinfo = trinfo;
        y.Data = data;
        y.DeterministicFlag = false;
                
    end
    
else
    
    % Iteration call -- evaluate objective function
    
    % Transform unconstrained variables to original space
    x_orig = warpvars(x,'i',infprob.Data.trinfo);
    dy = warpvars(x,'logpdf',infprob.Data.trinfo);   % Jacobian correction
    
    % Compute log likelihood of data and possibly std of log likelihood
    if infprob.DeterministicFlag
        LL = akrami2018_llfun(x_orig,infprob.Data);
        y_std = 0;
    else
        ibs_opts = struct('Nreps',infprob.Data.IBSNreps,...
            'ReturnPositive',true,'ReturnStd',true);
        [LL,y_std] = ibslike(@akrami2018_gendata,x_orig,infprob.Data.y,[],ibs_opts,infprob.Data);
    end
    y = LL + dy;
    
end

end

%--------------------------------------------------------------------------
function y = logpost(x,infprob)    
    y = infbench_akrami2018(x,infprob);
    lnp = infbench_lnprior(x,infprob);
    y = y + lnp;
end

function ll = akrami2018_llfun(theta,data)

% Unpack parameters
w1_start = theta(1);
w1_end = theta(2);
w2_start = theta(3);
w2_end = theta(4);
bias_start = theta(5);
bias_end = theta(6);
lambda = 0.01;

Ntrials = data.Ntrials;

w1_vec = linspace(w1_start,w1_end,Ntrials)';
w2_vec = linspace(w2_start,w2_end,Ntrials)';
bias_vec = linspace(bias_start,bias_end,Ntrials)';

p_left = 1./(1+exp(w1_vec.*data.X(:,1) + w2_vec.*data.X(:,2) + bias_vec));
p_lresp = (data.y == 1).*p_left + (data.y == 2).*(1-p_left);
p_lresp = (1-lambda)*p_lresp + lambda/2;

ll = sum(log(p_lresp));

end



function R = akrami2018_gendata(theta,idx,data)

% Unpack parameters
w1_start = theta(1);
w1_end = theta(2);
w2_start = theta(3);
w2_end = theta(4);
bias_start = theta(5);
bias_end = theta(6);
lambda = 0.01;

Ntrials = data.Ntrials;

w1_vec = linspace(w1_start,w1_end,Ntrials)';
w2_vec = linspace(w2_start,w2_end,Ntrials)';
bias_vec = linspace(bias_start,bias_end,Ntrials)';

p_left = 1./(1+exp(w1_vec.*data.X(:,1) + w2_vec.*data.X(:,2) + bias_vec));
p_lresp = (1-lambda)*p_left + lambda/2;

pl_vec = p_lresp(idx);

R = double(rand(size(pl_vec)) < pl_vec);
R(R == 0) = 2;

end


function akrami2018_test(infprob)

theta = randn(1,6);
LL = akrami2018_llfun(theta,infprob.Data);
ibs_opts = struct('Nreps',infprob.Data.IBSNreps,...
    'ReturnPositive',true,'ReturnStd',true);
[LL_ibs,y_std] = ibslike(@akrami2018_gendata,theta,infprob.Data.y,[],ibs_opts,infprob.Data);

[LL,LL_ibs,y_std]
[LL - LL_ibs, y_std]

end
