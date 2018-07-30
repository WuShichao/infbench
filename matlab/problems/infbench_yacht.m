function y = infbench_yacht(x,infprob,mcmc_params)
%INFBENCH_YACHT Inference benchmark log pdf -- neuronal model from Goris et al. (2015).

if nargin < 3; mcmc_params = []; end

if isempty(x)
    if isempty(infprob) % Generate this document        

        xmin = [1.9524865143579 2.49659792454305 2.51000683457272 2.23086060546565 0.735456801336253 0.125716790676167 1.01987028960502 -4.54194495912707];
        fval = 597.272161345529;
        xmin_post = [1.88033136010335 2.47192221187381 2.2227379400558 2.16208146542603 0.740568649759497 0.118811630485353 0.922933862868271 -4.52793333046509];
        fval_post = 568.794848145181;        

        infprob = infbench_yacht([],0);
        if isempty(mcmc_params); id = 0; else; id = mcmc_params(1); end

        widths = 0.5*(infprob.PUB - infprob.PLB);
        LB = infprob.PLB - 10*widths;
        UB = infprob.PUB + 10*widths;        
        
        if id == 0

            D = infprob.D;

            % Setup options for CMA-ES optimization
            cmaes_opts = cmaes_modded('defaults');
            cmaes_opts.EvalParallel = 'no';
            cmaes_opts.DispFinal = 'off';
            cmaes_opts.SaveVariables = 'off';
            cmaes_opts.DispModulo = Inf;
            cmaes_opts.LogModulo = 0;
            cmaes_opts.CMA.active = 1;      % Use Active CMA (generally better)
            cmaes_opts.TolX = 1e-6;
            cmaes_opts.TolFun = 1e-6;            
            
            Niters = 1e3;
            
            xnew = zeros(Niters,D);
            for i = 1:Niters
                fprintf('%d..',i);
                x0 = 2*randn(1,D);
                [xnew(i,:),fvalnew(i)] = cmaes_modded('yacht_nll',x0(:),2*ones(D,1),cmaes_opts,infprob,0);
            end            

            xnew
            fvalnew
            
            [~,idx] = min(fvalnew);
            xmin = xnew(idx,:);
            fval = -fvalnew(idx);

            xpnew = zeros(Niters,D);
            for i = 1:Niters
                fprintf('%d..',i);
                x0 = 2*randn(1,D);
                [xpnew(i,:),fpvalnew(i)] = cmaes_modded('yacht_nll',x0(:),2*ones(D,1),cmaes_opts,infprob,1);
            end
            
            xpnew
            fpvalnew            
            
            [~,idx] = min(fpvalnew);
            xmin_post = xpnew(idx,:);
            fval_post = -fpvalnew(idx);
            
            fprintf('\n\t\t\txmin = %s;\n\t\t\tfval = %s;\n',mat2str(xmin),mat2str(fval));
            fprintf('\t\t\txmin_post = %s;\n\t\t\tfval_post = %s;\n',mat2str(xmin_post),mat2str(fval_post));

        elseif id > 0

            rng(id);
            widths = 0.5*(infprob.PUB - infprob.PLB);
            logpfun = @(x) -nlogpost(x,infprob);

            % Number of samples
            if numel(mcmc_params) > 1
                W_mult = mcmc_params(2);
            else
                W_mult = 200;
            end

            W = 2*(infprob.D+1);    % Number of walkers
            Ns = W*W_mult;             % Number of samples

            sampleopts.Thin = 10;
            sampleopts.Burnin = Ns*sampleopts.Thin;
            sampleopts.Display = 'notify';
            sampleopts.Diagnostics = false;
            sampleopts.VarTransform = false;
            sampleopts.InversionSample = false;
            sampleopts.FitGMM = false;
            sampleopts.TolX = 1e-6;
            % sampleopts.TransitionOperators = {'transSliceSampleRD'};

            x0 = xmin_post;
            LB = infprob.PLB - 10*widths;
            UB = infprob.PUB + 10*widths;

            [Xs,lls,exitflag,output] = eissample_lite(logpfun,x0,Ns,W,widths,LB,UB,sampleopts);

            filename = ['yacht_mcmc_id' num2str(id) '.mat'];
            save(filename,'Xs','lls','exitflag','output');                
        end
        
    else
        % Initialization call -- define problem and set up data
        D = infprob(1);

        % There is only one dataset.
        % The measured variable is the residuary resistance per unit weight of displacement.
        
        % Model parameters
        % 1-6 GP input log length scales for the following parameters:
        % 1. Longitudinal position of the center of buoyancy, adimensional;
        % 2. Prismatic coefficient, adimensional;
        % 3. Length-displacement ratio, adimensional
        % 4. Beam-draught ratio, adimensional;
        % 5. Length-beam ratio, adimensional;
        % 6. Froude number, adimensional.
        % 7. GP output log length scale.
        % 8. Log standard deviation of the noise.
              
        Mean_laplace = NaN(1,D);    Cov_laplace = NaN(D,D); lnZ_laplace = NaN;
        Mean_mcmc = NaN(1,D);       Cov_mcmc = NaN(D,D);    lnZ_mcmc = NaN;        
        switch D
            case 7
                xmin = [1.9524865143579 2.49659792454305 2.51000683457272 2.23086060546565 0.735456801336253 0.125716790676167 1.01987028960502 -4.54194495912707];
                fval = 597.272161345529;
                xmin_post = [1.88033136010335 2.47192221187381 2.2227379400558 2.16208146542603 0.740568649759497 0.118811630485353 0.922933862868271 -4.52793333046509];
                fval_post = 568.794848145181;                
        %         Mean_laplace = [-0.465520991260055 -1.69627543340411 -1.62447989201296 -0.767119415827957 0.470491515145298 -0.484169040138803 -2.60814931957517];
        %         Cov_laplace = [0.000229133759218794 1.82326721309945e-05 0.000410425618637872 -0.000282902243846033 1.37333646747451e-05 2.55742161512486e-05 -7.49219827856342e-06;1.82326721309945e-05 0.00860578855990285 0.0113987299239016 -0.0046236785662946 -0.000242809250998626 -0.000356073871350522 -0.000143256002177701;0.000410425618637872 0.0113987299239016 0.162017238465403 -0.103918933733934 0.000992228291153627 0.00350094756853489 0.000154939078874722;-0.000282902243846033 -0.0046236785662946 -0.103918933733934 0.089505239660401 0.000464757180894073 -0.00336613410893957 -0.000435454797885497;1.37333646747451e-05 -0.000242809250998626 0.000992228291153627 0.000464757180894073 0.000982265536813824 0.00228454532591384 -3.74450494783302e-05;2.55742161512486e-05 -0.000356073871350522 0.00350094756853489 -0.00336613410893957 0.00228454532591384 0.00701913099415825 -8.12472287376342e-05;-7.49219827856342e-06 -0.000143256002177701 0.000154939078874722 -0.000435454797885497 -3.74450494783301e-05 -8.12472287376342e-05 0.00888756642652754];
        %         lnZ_laplace = -2620.215196872;
                % R_max = 1.002. Ntot = 360000. Neff_min = 161301.2. Total funccount = 25571959.        
                Mean_mcmc = [1.91258915637948 2.40539412613218 2.33081369297902 2.29496344828024 0.700458948185911 0.122913596685063 0.940436334835358 -4.52710278040933];
                Cov_mcmc = [0.0202148392730233 -0.0084088762765728 0.013194883682484 0.00974306431979073 -0.00448952915614568 0.00220997880226289 0.00790855447707847 0.000214935183517879;-0.0084088762765728 0.0427259587066655 -0.0179797093713665 -0.0291862699911754 0.0135348309463766 -0.00178689776506099 0.00735668468445131 0.00112018189832896;0.013194883682484 -0.0179797093713665 0.130384106975222 -0.00827506852747216 -0.0148162403671505 0.000709248145849218 0.00593374846148504 -0.00118272607242899;0.00974306431979073 -0.0291862699911754 -0.00827506852747216 0.111334847456849 -0.0115266313251732 0.0029459470958035 0.00759640554936243 0.000529682578412785;-0.00448952915614568 0.0135348309463766 -0.0148162403671505 -0.0115266313251732 0.0148115291738516 -0.000684136966191492 0.00473508131051359 0.00122710526911367;0.00220997880226289 -0.00178689776506099 0.000709248145849218 0.0029459470958035 -0.000684136966191492 0.00271793382711153 0.00386130164652644 0.000732076645382729;0.00790855447707847 0.00735668468445131 0.00593374846148504 0.00759640554936243 0.00473508131051359 0.00386130164652644 0.0201011604109985 0.000273645665495188;0.000214935183517879 0.00112018189832896 -0.00118272607242899 0.000529682578412785 0.00122710526911367 0.000732076645382729 0.000273645665495188 0.0041088937975764];
                lnZ_mcmc = 559.238414166925;        
                xmin = xmin(1:D);
                xmin_post = xmin_post(1:D);
                Mean_mcmc = Mean_mcmc(1:D);
                Cov_mcmc = Cov_mcmc(1:D,1:D);
                
            case 8
                xmin = [1.9524865143579 2.49659792454305 2.51000683457272 2.23086060546565 0.735456801336253 0.125716790676167 1.01987028960502 -4.54194495912707];
                fval = 597.272161345529;
                xmin_post = [1.88033136010335 2.47192221187381 2.2227379400558 2.16208146542603 0.740568649759497 0.118811630485353 0.922933862868271 -4.52793333046509];
                fval_post = 568.794848145181;                
        %         Mean_laplace = [-0.465520991260055 -1.69627543340411 -1.62447989201296 -0.767119415827957 0.470491515145298 -0.484169040138803 -2.60814931957517];
        %         Cov_laplace = [0.000229133759218794 1.82326721309945e-05 0.000410425618637872 -0.000282902243846033 1.37333646747451e-05 2.55742161512486e-05 -7.49219827856342e-06;1.82326721309945e-05 0.00860578855990285 0.0113987299239016 -0.0046236785662946 -0.000242809250998626 -0.000356073871350522 -0.000143256002177701;0.000410425618637872 0.0113987299239016 0.162017238465403 -0.103918933733934 0.000992228291153627 0.00350094756853489 0.000154939078874722;-0.000282902243846033 -0.0046236785662946 -0.103918933733934 0.089505239660401 0.000464757180894073 -0.00336613410893957 -0.000435454797885497;1.37333646747451e-05 -0.000242809250998626 0.000992228291153627 0.000464757180894073 0.000982265536813824 0.00228454532591384 -3.74450494783302e-05;2.55742161512486e-05 -0.000356073871350522 0.00350094756853489 -0.00336613410893957 0.00228454532591384 0.00701913099415825 -8.12472287376342e-05;-7.49219827856342e-06 -0.000143256002177701 0.000154939078874722 -0.000435454797885497 -3.74450494783301e-05 -8.12472287376342e-05 0.00888756642652754];
        %         lnZ_laplace = -2620.215196872;
                % R_max = 1.002. Ntot = 360000. Neff_min = 161301.2. Total funccount = 25571959.        
                Mean_mcmc = [1.91258915637948 2.40539412613218 2.33081369297902 2.29496344828024 0.700458948185911 0.122913596685063 0.940436334835358 -4.52710278040933];
                Cov_mcmc = [0.0202148392730233 -0.0084088762765728 0.013194883682484 0.00974306431979073 -0.00448952915614568 0.00220997880226289 0.00790855447707847 0.000214935183517879;-0.0084088762765728 0.0427259587066655 -0.0179797093713665 -0.0291862699911754 0.0135348309463766 -0.00178689776506099 0.00735668468445131 0.00112018189832896;0.013194883682484 -0.0179797093713665 0.130384106975222 -0.00827506852747216 -0.0148162403671505 0.000709248145849218 0.00593374846148504 -0.00118272607242899;0.00974306431979073 -0.0291862699911754 -0.00827506852747216 0.111334847456849 -0.0115266313251732 0.0029459470958035 0.00759640554936243 0.000529682578412785;-0.00448952915614568 0.0135348309463766 -0.0148162403671505 -0.0115266313251732 0.0148115291738516 -0.000684136966191492 0.00473508131051359 0.00122710526911367;0.00220997880226289 -0.00178689776506099 0.000709248145849218 0.0029459470958035 -0.000684136966191492 0.00271793382711153 0.00386130164652644 0.000732076645382729;0.00790855447707847 0.00735668468445131 0.00593374846148504 0.00759640554936243 0.00473508131051359 0.00386130164652644 0.0201011604109985 0.000273645665495188;0.000214935183517879 0.00112018189832896 -0.00118272607242899 0.000529682578412785 0.00122710526911367 0.000732076645382729 0.000273645665495188 0.0041088937975764];
                lnZ_mcmc = 559.238414166925;        
        end
        % Yacht data (hard-coded)
        yacht_mat = [-2.3 0.568 4.78 3.99 3.17 0.125 0.11;-2.3 0.568 4.78 3.99 3.17 0.15 0.27;-2.3 0.568 4.78 3.99 3.17 0.175 0.47;-2.3 0.568 4.78 3.99 3.17 0.2 0.78;-2.3 0.568 4.78 3.99 3.17 0.225 1.18;-2.3 0.568 4.78 3.99 3.17 0.25 1.82;-2.3 0.568 4.78 3.99 3.17 0.275 2.61;-2.3 0.568 4.78 3.99 3.17 0.3 3.76;-2.3 0.568 4.78 3.99 3.17 0.325 4.99;-2.3 0.568 4.78 3.99 3.17 0.35 7.16;-2.3 0.568 4.78 3.99 3.17 0.375 11.93;-2.3 0.568 4.78 3.99 3.17 0.4 20.11;-2.3 0.568 4.78 3.99 3.17 0.425 32.75;-2.3 0.568 4.78 3.99 3.17 0.45 49.49;-2.3 0.569 4.78 3.04 3.64 0.125 0.04;-2.3 0.569 4.78 3.04 3.64 0.15 0.17;-2.3 0.569 4.78 3.04 3.64 0.175 0.37;-2.3 0.569 4.78 3.04 3.64 0.2 0.66;-2.3 0.569 4.78 3.04 3.64 0.225 1.06;-2.3 0.569 4.78 3.04 3.64 0.25 1.59;-2.3 0.569 4.78 3.04 3.64 0.275 2.33;-2.3 0.569 4.78 3.04 3.64 0.3 3.29;-2.3 0.569 4.78 3.04 3.64 0.325 4.61;-2.3 0.569 4.78 3.04 3.64 0.35 7.11;-2.3 0.569 4.78 3.04 3.64 0.375 11.99;-2.3 0.569 4.78 3.04 3.64 0.4 21.09;-2.3 0.569 4.78 3.04 3.64 0.425 35.01;-2.3 0.569 4.78 3.04 3.64 0.45 51.8;-2.3 0.565 4.78 5.35 2.76 0.125 0.09;-2.3 0.565 4.78 5.35 2.76 0.15 0.29;-2.3 0.565 4.78 5.35 2.76 0.175 0.56;-2.3 0.565 4.78 5.35 2.76 0.2 0.86;-2.3 0.565 4.78 5.35 2.76 0.225 1.31;-2.3 0.565 4.78 5.35 2.76 0.25 1.99;-2.3 0.565 4.78 5.35 2.76 0.275 2.94;-2.3 0.565 4.78 5.35 2.76 0.3 4.21;-2.3 0.565 4.78 5.35 2.76 0.325 5.54;-2.3 0.565 4.78 5.35 2.76 0.35 8.25;-2.3 0.565 4.78 5.35 2.76 0.375 13.08;-2.3 0.565 4.78 5.35 2.76 0.4 21.4;-2.3 0.565 4.78 5.35 2.76 0.425 33.14;-2.3 0.565 4.78 5.35 2.76 0.45 50.14;-2.3 0.564 5.1 3.95 3.53 0.125 0.2;-2.3 0.564 5.1 3.95 3.53 0.15 0.35;-2.3 0.564 5.1 3.95 3.53 0.175 0.65;-2.3 0.564 5.1 3.95 3.53 0.2 0.93;-2.3 0.564 5.1 3.95 3.53 0.225 1.37;-2.3 0.564 5.1 3.95 3.53 0.25 1.97;-2.3 0.564 5.1 3.95 3.53 0.275 2.83;-2.3 0.564 5.1 3.95 3.53 0.3 3.99;-2.3 0.564 5.1 3.95 3.53 0.325 5.19;-2.3 0.564 5.1 3.95 3.53 0.35 8.03;-2.3 0.564 5.1 3.95 3.53 0.375 12.86;-2.3 0.564 5.1 3.95 3.53 0.4 21.51;-2.3 0.564 5.1 3.95 3.53 0.425 33.97;-2.3 0.564 5.1 3.95 3.53 0.45 50.36;-2.4 0.574 4.36 3.96 2.76 0.125 0.2;-2.4 0.574 4.36 3.96 2.76 0.15 0.35;-2.4 0.574 4.36 3.96 2.76 0.175 0.65;-2.4 0.574 4.36 3.96 2.76 0.2 0.93;-2.4 0.574 4.36 3.96 2.76 0.225 1.37;-2.4 0.574 4.36 3.96 2.76 0.25 1.97;-2.4 0.574 4.36 3.96 2.76 0.275 2.83;-2.4 0.574 4.36 3.96 2.76 0.3 3.99;-2.4 0.574 4.36 3.96 2.76 0.325 5.19;-2.4 0.574 4.36 3.96 2.76 0.35 8.03;-2.4 0.574 4.36 3.96 2.76 0.375 12.86;-2.4 0.574 4.36 3.96 2.76 0.4 21.51;-2.4 0.574 4.36 3.96 2.76 0.425 33.97;-2.4 0.574 4.36 3.96 2.76 0.45 50.36;-2.4 0.568 4.34 2.98 3.15 0.125 0.12;-2.4 0.568 4.34 2.98 3.15 0.15 0.26;-2.4 0.568 4.34 2.98 3.15 0.175 0.43;-2.4 0.568 4.34 2.98 3.15 0.2 0.69;-2.4 0.568 4.34 2.98 3.15 0.225 1.09;-2.4 0.568 4.34 2.98 3.15 0.25 1.67;-2.4 0.568 4.34 2.98 3.15 0.275 2.46;-2.4 0.568 4.34 2.98 3.15 0.3 3.43;-2.4 0.568 4.34 2.98 3.15 0.325 4.62;-2.4 0.568 4.34 2.98 3.15 0.35 6.86;-2.4 0.568 4.34 2.98 3.15 0.375 11.56;-2.4 0.568 4.34 2.98 3.15 0.4 20.63;-2.4 0.568 4.34 2.98 3.15 0.425 34.5;-2.4 0.568 4.34 2.98 3.15 0.45 54.23;-2.3 0.562 5.14 4.95 3.17 0.125 0.28;-2.3 0.562 5.14 4.95 3.17 0.15 0.44;-2.3 0.562 5.14 4.95 3.17 0.175 0.7;-2.3 0.562 5.14 4.95 3.17 0.2 1.07;-2.3 0.562 5.14 4.95 3.17 0.225 1.57;-2.3 0.562 5.14 4.95 3.17 0.25 2.23;-2.3 0.562 5.14 4.95 3.17 0.275 3.09;-2.3 0.562 5.14 4.95 3.17 0.3 4.09;-2.3 0.562 5.14 4.95 3.17 0.325 5.82;-2.3 0.562 5.14 4.95 3.17 0.35 8.28;-2.3 0.562 5.14 4.95 3.17 0.375 12.8;-2.3 0.562 5.14 4.95 3.17 0.4 20.41;-2.3 0.562 5.14 4.95 3.17 0.425 32.34;-2.3 0.562 5.14 4.95 3.17 0.45 47.29;-2.4 0.585 4.78 3.84 3.32 0.125 0.2;-2.4 0.585 4.78 3.84 3.32 0.15 0.38;-2.4 0.585 4.78 3.84 3.32 0.175 0.64;-2.4 0.585 4.78 3.84 3.32 0.2 0.97;-2.4 0.585 4.78 3.84 3.32 0.225 1.36;-2.4 0.585 4.78 3.84 3.32 0.25 1.98;-2.4 0.585 4.78 3.84 3.32 0.275 2.91;-2.4 0.585 4.78 3.84 3.32 0.3 4.35;-2.4 0.585 4.78 3.84 3.32 0.325 5.79;-2.4 0.585 4.78 3.84 3.32 0.35 8.04;-2.4 0.585 4.78 3.84 3.32 0.375 12.15;-2.4 0.585 4.78 3.84 3.32 0.4 19.18;-2.4 0.585 4.78 3.84 3.32 0.425 30.09;-2.4 0.585 4.78 3.84 3.32 0.45 44.38;-2.2 0.546 4.78 4.13 3.07 0.125 0.15;-2.2 0.546 4.78 4.13 3.07 0.15 0.32;-2.2 0.546 4.78 4.13 3.07 0.175 0.55;-2.2 0.546 4.78 4.13 3.07 0.2 0.86;-2.2 0.546 4.78 4.13 3.07 0.225 1.24;-2.2 0.546 4.78 4.13 3.07 0.25 1.76;-2.2 0.546 4.78 4.13 3.07 0.275 2.49;-2.2 0.546 4.78 4.13 3.07 0.3 3.45;-2.2 0.546 4.78 4.13 3.07 0.325 4.83;-2.2 0.546 4.78 4.13 3.07 0.35 7.37;-2.2 0.546 4.78 4.13 3.07 0.375 12.76;-2.2 0.546 4.78 4.13 3.07 0.4 21.99;-2.2 0.546 4.78 4.13 3.07 0.425 35.64;-2.2 0.546 4.78 4.13 3.07 0.45 53.07;0 0.565 4.77 3.99 3.15 0.125 0.11;0 0.565 4.77 3.99 3.15 0.15 0.24;0 0.565 4.77 3.99 3.15 0.175 0.49;0 0.565 4.77 3.99 3.15 0.2 0.79;0 0.565 4.77 3.99 3.15 0.225 1.28;0 0.565 4.77 3.99 3.15 0.25 1.96;0 0.565 4.77 3.99 3.15 0.275 2.88;0 0.565 4.77 3.99 3.15 0.3 4.14;0 0.565 4.77 3.99 3.15 0.325 5.96;0 0.565 4.77 3.99 3.15 0.35 9.07;0 0.565 4.77 3.99 3.15 0.375 14.93;0 0.565 4.77 3.99 3.15 0.4 24.13;0 0.565 4.77 3.99 3.15 0.425 38.12;0 0.565 4.77 3.99 3.15 0.45 55.44;-5 0.565 4.77 3.99 3.15 0.125 0.07;-5 0.565 4.77 3.99 3.15 0.15 0.18;-5 0.565 4.77 3.99 3.15 0.175 0.4;-5 0.565 4.77 3.99 3.15 0.2 0.7;-5 0.565 4.77 3.99 3.15 0.225 1.14;-5 0.565 4.77 3.99 3.15 0.25 1.83;-5 0.565 4.77 3.99 3.15 0.275 2.77;-5 0.565 4.77 3.99 3.15 0.3 4.12;-5 0.565 4.77 3.99 3.15 0.325 5.41;-5 0.565 4.77 3.99 3.15 0.35 7.87;-5 0.565 4.77 3.99 3.15 0.375 12.71;-5 0.565 4.77 3.99 3.15 0.4 21.02;-5 0.565 4.77 3.99 3.15 0.425 34.58;-5 0.565 4.77 3.99 3.15 0.45 51.77;0 0.565 5.1 3.94 3.51 0.125 0.08;0 0.565 5.1 3.94 3.51 0.15 0.26;0 0.565 5.1 3.94 3.51 0.175 0.5;0 0.565 5.1 3.94 3.51 0.2 0.83;0 0.565 5.1 3.94 3.51 0.225 1.28;0 0.565 5.1 3.94 3.51 0.25 1.9;0 0.565 5.1 3.94 3.51 0.275 2.68;0 0.565 5.1 3.94 3.51 0.3 3.76;0 0.565 5.1 3.94 3.51 0.325 5.57;0 0.565 5.1 3.94 3.51 0.35 8.76;0 0.565 5.1 3.94 3.51 0.375 14.24;0 0.565 5.1 3.94 3.51 0.4 23.05;0 0.565 5.1 3.94 3.51 0.425 35.46;0 0.565 5.1 3.94 3.51 0.45 51.99;-5 0.565 5.1 3.94 3.51 0.125 0.08;-5 0.565 5.1 3.94 3.51 0.15 0.24;-5 0.565 5.1 3.94 3.51 0.175 0.45;-5 0.565 5.1 3.94 3.51 0.2 0.77;-5 0.565 5.1 3.94 3.51 0.225 1.19;-5 0.565 5.1 3.94 3.51 0.25 1.76;-5 0.565 5.1 3.94 3.51 0.275 2.59;-5 0.565 5.1 3.94 3.51 0.3 3.85;-5 0.565 5.1 3.94 3.51 0.325 5.27;-5 0.565 5.1 3.94 3.51 0.35 7.74;-5 0.565 5.1 3.94 3.51 0.375 12.4;-5 0.565 5.1 3.94 3.51 0.4 20.91;-5 0.565 5.1 3.94 3.51 0.425 33.23;-5 0.565 5.1 3.94 3.51 0.45 49.14;-2.3 0.53 5.11 3.69 3.51 0.125 0.08;-2.3 0.53 5.11 3.69 3.51 0.15 0.25;-2.3 0.53 5.11 3.69 3.51 0.175 0.46;-2.3 0.53 5.11 3.69 3.51 0.2 0.75;-2.3 0.53 5.11 3.69 3.51 0.225 1.11;-2.3 0.53 5.11 3.69 3.51 0.25 1.57;-2.3 0.53 5.11 3.69 3.51 0.275 2.17;-2.3 0.53 5.11 3.69 3.51 0.3 2.98;-2.3 0.53 5.11 3.69 3.51 0.325 4.42;-2.3 0.53 5.11 3.69 3.51 0.35 7.84;-2.3 0.53 5.11 3.69 3.51 0.375 14.11;-2.3 0.53 5.11 3.69 3.51 0.4 24.14;-2.3 0.53 5.11 3.69 3.51 0.425 37.95;-2.3 0.53 5.11 3.69 3.51 0.45 55.17;-2.3 0.53 4.76 3.68 3.16 0.125 0.1;-2.3 0.53 4.76 3.68 3.16 0.15 0.23;-2.3 0.53 4.76 3.68 3.16 0.175 0.47;-2.3 0.53 4.76 3.68 3.16 0.2 0.76;-2.3 0.53 4.76 3.68 3.16 0.225 1.15;-2.3 0.53 4.76 3.68 3.16 0.25 1.65;-2.3 0.53 4.76 3.68 3.16 0.275 2.28;-2.3 0.53 4.76 3.68 3.16 0.3 3.09;-2.3 0.53 4.76 3.68 3.16 0.325 4.41;-2.3 0.53 4.76 3.68 3.16 0.35 7.51;-2.3 0.53 4.76 3.68 3.16 0.375 13.77;-2.3 0.53 4.76 3.68 3.16 0.4 23.96;-2.3 0.53 4.76 3.68 3.16 0.425 37.38;-2.3 0.53 4.76 3.68 3.16 0.45 56.46;-2.3 0.53 4.34 2.81 3.15 0.125 0.05;-2.3 0.53 4.34 2.81 3.15 0.15 0.17;-2.3 0.53 4.34 2.81 3.15 0.175 0.35;-2.3 0.53 4.34 2.81 3.15 0.2 0.63;-2.3 0.53 4.34 2.81 3.15 0.225 1.01;-2.3 0.53 4.34 2.81 3.15 0.25 1.43;-2.3 0.53 4.34 2.81 3.15 0.275 2.05;-2.3 0.53 4.34 2.81 3.15 0.3 2.73;-2.3 0.53 4.34 2.81 3.15 0.325 3.87;-2.3 0.53 4.34 2.81 3.15 0.35 7.19;-2.3 0.53 4.34 2.81 3.15 0.375 13.96;-2.3 0.53 4.34 2.81 3.15 0.4 25.18;-2.3 0.53 4.34 2.81 3.15 0.425 41.34;-2.3 0.53 4.34 2.81 3.15 0.45 62.42;0 0.6 4.78 4.24 3.15 0.125 0.03;0 0.6 4.78 4.24 3.15 0.15 0.18;0 0.6 4.78 4.24 3.15 0.175 0.4;0 0.6 4.78 4.24 3.15 0.2 0.73;0 0.6 4.78 4.24 3.15 0.225 1.3;0 0.6 4.78 4.24 3.15 0.25 2.16;0 0.6 4.78 4.24 3.15 0.275 3.35;0 0.6 4.78 4.24 3.15 0.3 5.06;0 0.6 4.78 4.24 3.15 0.325 7.14;0 0.6 4.78 4.24 3.15 0.35 10.36;0 0.6 4.78 4.24 3.15 0.375 15.25;0 0.6 4.78 4.24 3.15 0.4 23.15;0 0.6 4.78 4.24 3.15 0.425 34.62;0 0.6 4.78 4.24 3.15 0.45 51.5;-5 0.6 4.78 4.24 3.15 0.125 0.06;-5 0.6 4.78 4.24 3.15 0.15 0.15;-5 0.6 4.78 4.24 3.15 0.175 0.34;-5 0.6 4.78 4.24 3.15 0.2 0.63;-5 0.6 4.78 4.24 3.15 0.225 1.13;-5 0.6 4.78 4.24 3.15 0.25 1.85;-5 0.6 4.78 4.24 3.15 0.275 2.84;-5 0.6 4.78 4.24 3.15 0.3 4.34;-5 0.6 4.78 4.24 3.15 0.325 6.2;-5 0.6 4.78 4.24 3.15 0.35 8.62;-5 0.6 4.78 4.24 3.15 0.375 12.49;-5 0.6 4.78 4.24 3.15 0.4 20.41;-5 0.6 4.78 4.24 3.15 0.425 32.46;-5 0.6 4.78 4.24 3.15 0.45 50.94;0 0.53 4.78 3.75 3.15 0.125 0.16;0 0.53 4.78 3.75 3.15 0.15 0.32;0 0.53 4.78 3.75 3.15 0.175 0.59;0 0.53 4.78 3.75 3.15 0.2 0.92;0 0.53 4.78 3.75 3.15 0.225 1.37;0 0.53 4.78 3.75 3.15 0.25 1.94;0 0.53 4.78 3.75 3.15 0.275 2.62;0 0.53 4.78 3.75 3.15 0.3 3.7;0 0.53 4.78 3.75 3.15 0.325 5.45;0 0.53 4.78 3.75 3.15 0.35 9.45;0 0.53 4.78 3.75 3.15 0.375 16.31;0 0.53 4.78 3.75 3.15 0.4 27.34;0 0.53 4.78 3.75 3.15 0.425 41.77;0 0.53 4.78 3.75 3.15 0.45 60.85;-5 0.53 4.78 3.75 3.15 0.125 0.09;-5 0.53 4.78 3.75 3.15 0.15 0.24;-5 0.53 4.78 3.75 3.15 0.175 0.47;-5 0.53 4.78 3.75 3.15 0.2 0.78;-5 0.53 4.78 3.75 3.15 0.225 1.21;-5 0.53 4.78 3.75 3.15 0.25 1.85;-5 0.53 4.78 3.75 3.15 0.275 2.62;-5 0.53 4.78 3.75 3.15 0.3 3.69;-5 0.53 4.78 3.75 3.15 0.325 5.07;-5 0.53 4.78 3.75 3.15 0.35 7.95;-5 0.53 4.78 3.75 3.15 0.375 13.73;-5 0.53 4.78 3.75 3.15 0.4 23.55;-5 0.53 4.78 3.75 3.15 0.425 37.14;-5 0.53 4.78 3.75 3.15 0.45 55.87;-2.3 0.6 5.1 4.17 3.51 0.125 0.01;-2.3 0.6 5.1 4.17 3.51 0.15 0.16;-2.3 0.6 5.1 4.17 3.51 0.175 0.39;-2.3 0.6 5.1 4.17 3.51 0.2 0.73;-2.3 0.6 5.1 4.17 3.51 0.225 1.24;-2.3 0.6 5.1 4.17 3.51 0.25 1.96;-2.3 0.6 5.1 4.17 3.51 0.275 3.04;-2.3 0.6 5.1 4.17 3.51 0.3 4.46;-2.3 0.6 5.1 4.17 3.51 0.325 6.31;-2.3 0.6 5.1 4.17 3.51 0.35 8.68;-2.3 0.6 5.1 4.17 3.51 0.375 12.39;-2.3 0.6 5.1 4.17 3.51 0.4 20.14;-2.3 0.6 5.1 4.17 3.51 0.425 31.77;-2.3 0.6 5.1 4.17 3.51 0.45 47.13;-2.3 0.6 4.34 4.23 2.73 0.125 0.04;-2.3 0.6 4.34 4.23 2.73 0.15 0.17;-2.3 0.6 4.34 4.23 2.73 0.175 0.36;-2.3 0.6 4.34 4.23 2.73 0.2 0.64;-2.3 0.6 4.34 4.23 2.73 0.225 1.02;-2.3 0.6 4.34 4.23 2.73 0.25 1.62;-2.3 0.6 4.34 4.23 2.73 0.275 2.63;-2.3 0.6 4.34 4.23 2.73 0.3 4.15;-2.3 0.6 4.34 4.23 2.73 0.325 6;-2.3 0.6 4.34 4.23 2.73 0.35 8.47;-2.3 0.6 4.34 4.23 2.73 0.375 12.27;-2.3 0.6 4.34 4.23 2.73 0.4 19.59;-2.3 0.6 4.34 4.23 2.73 0.425 30.48;-2.3 0.6 4.34 4.23 2.73 0.45 46.66];
        yacht_mat(:,7) = yacht_mat(:,7);
        
        % Standardize data
        yacht_mat = bsxfun(@minus,yacht_mat,mean(yacht_mat));
        yacht_mat = bsxfun(@rdivide,yacht_mat,std(yacht_mat));
        
        data.X = yacht_mat(:,1:6);
        data.y = yacht_mat(:,7);
        
        lb = -Inf(1,D);
        ub = Inf(1,D);
        plb = -ones(1,D);
        pub = ones(1,D);
        noise = [];
                
        Mean = zeros(1,D);
        Cov = eye(D);
        Mode = xmin;
                
        y.D = D;
        y.LB = lb;
        y.UB = ub;
        y.PLB = plb;
        y.PUB = pub;
        
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
                        
        y.Post.Mean = Mean_mcmc;
        y.Post.Mode = xmin_post;          % Mode of the posterior
        y.Post.ModeFval = fval_post;        
        y.Post.lnZ = lnZ_mcmc;
        y.Post.Cov = Cov_mcmc;
                
        % Save data
        y.Data = data;
        
        % Create base GP
        hyp = zeros(8,1);
        y.gp = gplite_post(hyp,data.X,data.y,'zero');
        
    end
    
else
        
    % Iteration call -- evaluate objective function (GP likelihood)
    try
        % Fixed noise case
        if numel(x) == 7; x = [x(:); log(0.01)]; end
        nlZ = gplite_nlZ(x(:),infprob.gp);        
    catch
        nlZ = Inf;
    end        
    y = -nlZ;    
        
end

end

%--------------------------------------------------------------------------
function y = nlogpost(x,infprob)
    y = -infbench_yacht(x,infprob);
    infprob.PriorMean = infprob.Prior.Mean;
    infprob.PriorVar = diag(infprob.Prior.Cov)';
    lnp = infbench_lnprior(x,infprob);
    y = y - lnp;
end