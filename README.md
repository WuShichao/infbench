- This repository contains code for the inference benchmarks and results reported in several papers on *Variational Bayesian Monte Carlo* (VBMC) [[1,2,3](#references)]. 

- The Variational Bayesian Monte Carlo (VBMC) algorithm is available at [this repository](https://github.com/lacerbi/vbmc).

# Inference benchmark (`infbench`)

The goal of `infbench` is to compare various sample-efficient approximate inference algorithms which have been proposed in the machine learning literature so as to deal with (moderately) expensive likelihoods. In particular, we want to infer the posterior over model parameters and (an approximation of) the model evidence or marginal likelihood, that is the normalization constant of the posterior. Crucially, we assume that the budget of likelihood evaluations is of the order of a few or several hundreds.

Notably, this goal is more ambitious than simply finding the maximum of the posterior (MAP), problem that we previously tackled with [Bayesian Adaptive Direct Search](https://github.com/lacerbi/bads) (aka BADS).

Our first benchmark shows that existing inference algorithms perform quite poorly at reconstructing posteriors (or evaluating their normalization constant) with both syntethic and real pdfs that have moderately challenging features, showing that this is a much harder problem [[1](#reference)].

## How to run the benchmark (`vbmc18`)

You can run the benchmark on one test problem in the `vbmc18` problem set as follows:
```
> options = struct('SpeedTests',false);
> [probstruct,history] = infbench_run('vbmc18',testfun,D,[],algo,id,options);
```
The arguments are:

- `testfun` (string) is the test pdf, which can be `'cigar'`, `'lumpy'`, `'studentt'` (synthetic test functions with different properties), or `'goris2015'` (real model fitting problem with neuronal data, see [here](https://github.com/lacerbi/infbench/tree/master/matlab/problems/goris2015)).
- `D` (integer) is the dimensionality of the problem for the synthetic test functions (typical values are from `D=2` to `D=10`), and `7` or `8` for the `goris2015` test set (corresponding to two different neuron datasets).
- `algo` (string) is the inference algorithm being tested. Specific settings for the chosen inference algorithm are selected with `'algo@setting'`, e.g. `'agp@debug'`.
- `id` (integer) is the run id, used to set the random seed. It can be an array, such as `id=1:5`, for multiple consecutive runs.
- `options` (struct) sets various options for the benchmark. For a fast test, I recommend to set the field `SpeedTests` to `false` since initial speed tests can be quite time consuming.

The outputs are:

- `probstruct` (struct) describes the current problem in detail.
- `history` (struct array) summary statistics of the run for each id.


## References

1. Acerbi, L. (2018). Variational Bayesian Monte Carlo. In *Advances in Neural Information Processing Systems 31*: 8222-8232. ([paper + supplement on arXiv](https://arxiv.org/abs/1810.05558), [NeurIPS Proceedings](https://papers.nips.cc/paper/8043-variational-bayesian-monte-carlo))
2. Acerbi, L. (2019). An Exploration of Acquisition and Mean Functions in Variational Bayesian Monte Carlo. In *Proc. Machine Learning Research* 96: 1-10. 1st Symposium on Advances in Approximate Bayesian Inference, Montréal, Canada. ([paper in PMLR](http://proceedings.mlr.press/v96/acerbi19a.html))
3. Acerbi, L. (2020). Variational Bayesian Monte Carlo with Noisy Likelihoods. arXiv preprint (to appear).

### Contact

This repository is currently actively used for research, stay tuned for updates:

- [Follow me on Twitter](https://twitter.com/AcerbiLuigi) for updates about my work on model inference and other projects I am involved with;
- If you have questions or comments about this work, get in touch at <luigi.acerbi@unige.ch> (putting 'infbench' in the subject of the email).

### License

The inference benchmark is released under the terms of the [GNU General Public License v3.0](https://github.com/lacerbi/infbench/blob/master/LICENSE.txt).
