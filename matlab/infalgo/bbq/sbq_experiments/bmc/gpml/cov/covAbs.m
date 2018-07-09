function K = covAbs(cov, hyp, x, z, i)

%
% David Duvenaud
%
% meanScale - compose a mean function as a scaled version of another one.
%
% k(x^p,x^q) = sf^2 * k_0(x^p,x^q)
%
% The hyperparameter is:
%
% hyp = [ log(sf)  ]
%
% This function doesn't actually compute very much on its own, it merely does
% some bookkeeping, and calls other mean function to do the actual work.
%
% Copyright (c) by Carl Edward Rasmussen & Hannes Nickisch 2010-09-10.
%
% See also MEANFUNCTIONS.M.

if nargin<3                                        % report number of parameters
  K = feval(cov{:}); return
end
if nargin<4, z = []; end                                   % make sure, z exists

[n,D] = size(x);
%sf2 = exp(2*hyp(1));                                           % signal variance

if nargin<5                             % covariances
    if numel(z) == 0 || strcmp(z, 'diag')
        K = feval(cov{:},hyp(1:end),abs(x),z);
    else
        K = feval(cov{:},hyp(1:end),abs(x),abs(z));
    end
else                                                               % derivatives
  if i==1
    K = 2*feval(abs(cov{:}),hyp(1:end),abs(x),abs(z));
  else
    K = feval(abs(cov{:}),hyp(1:end),abs(x),abs(z),i-1);
  end
end