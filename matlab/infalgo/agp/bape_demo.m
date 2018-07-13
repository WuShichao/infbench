%BAPE_DEMO Run demo of BAPE on shallow Rosenbrock function.
% Reference:
%   1. Wang, H., & Li, J. (2017). Adaptive Gaussian process approximation 
%      for Bayesian inference with expensive likelihood functions. 
%      arXiv preprint arXiv:1703.09930. 

options = [];
options.Algorithm = 'bape';
options.Plot = 1;   % Plot posterior and search points each iteration
options.Meanfun = 'const';

fun = @rosenbrock_test;     % This is a shallow Rosenbrock function
x0 = [0 0];                 % Starting point
LB = [-5 -5];               % Hard bounds - this makes the problem easier
UB = [5 5];
PLB = [-1 -1];              % Plausible bounds identify initial region
PUB = [1 1];

[vbmodel,exitflag,output] = bapegp(fun,x0,LB,UB,PLB,PUB,options);

% Now try without the bounds...
[vbmodel,exitflag,output] = bapegp(fun,x0,[],[],PLB,PUB,options);