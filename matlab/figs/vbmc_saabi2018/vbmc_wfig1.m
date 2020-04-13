% FIGURE 1 for VBMC workshop paper. Plot benchmark on synthetic likelihoods.

options.BestOutOf = 1;
options.NumZero = 1e-3;
YlimMax = [1e4,1e4];
options.Method = 'IR';
options.ErrorBar = 1;
options.BootStrap = 1e5;
options.SampleFrequency = NaN;
options.AdaptiveYlim = 1;
plots = {'lnZ','gsKL'};

algos = {'vbmc@acqusreg','vbmc@acqf2reg','vbmc@acqfregvlnn','vbmc@acqfregvsqrtn','vbmc@const','vbmc@se','vbmc@acqproreg'};

dims = {'2D','6D','10D'};
% dims = {'2D','4D','6D','8D','10D'};
noise = [];

n = 1;
probset = 'vbmc18';
probs = {'lumpy','studentt','cigar'};

figname = {'vbmc_wfig1a','vbmc_wfig1b'};
mypath = fileparts(mfilename('fullpath'));
mypath = '.';

for iPlot = 1:numel(plots)
    options.Metric = plots{iPlot};
    options.YlimMax = YlimMax(iPlot);
    options.DisplayLegend = iPlot == numel(plots);
    figure(iPlot);
    infbench_plot(probset,probs,dims,noise,algos,[],{'prob','subprob'},options);
    pos = [50,50,900,750];
    set(gcf,'Position',pos);
    set(gcf,'Units','inches'); pos = get(gcf,'Position');
    set(gcf,'PaperPositionMode','Auto','PaperUnits','Inches','PaperSize',[pos(3), pos(4)])
    drawnow;
    saveas(gcf,[mypath filesep() figname{iPlot} '.pdf']);
end