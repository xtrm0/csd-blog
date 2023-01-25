+++
# The title of your blogpost. No sub-titles are allowed, nor are line-breaks.
title = "Robustness between the worst and average case"
# Date must be written in YYYY-MM-DD format. This should be updated right before the final PR is made.
date = 2022-11-04

[taxonomies]
# Keep any areas that apply, removing ones that don't. Do not add new areas!
areas = ["Artificial Intelligence"]
# Tags can be set to a collection of a few keywords specific to your blogpost.
# Consider these similar to keywords specified for a research paper.
tags = ["machine-learning", "robustness"]

[extra]
# For the author field, you can decide to not have a url.
# If so, simply replace the set of author fields with the name string.
# For example:
#   author = "Harry Bovik"
# However, adding a URL is strongly preferred
author = {name = "Leslie Rice", url = "https://leslierice1.github.io/" }
# The committee specification is simply a list of strings.
# However, you can also make an object with fields like in the author.
committee = [
    "TODO",
    "TODO",
    {name = "Harry Q. Bovik", url = "http://www.cs.cmu.edu/~bovik/"},
]
+++
As machine learning systems become increasingly implemented in safety-critical applications, such as autonomous driving and healthcare, we need to ensure these systems are reliable and trustworthy. For example, we might wish to determine whether a traffic light classifier on a self-driving car can correctly classify the color of the light even in the presence of heavy rain, or an eye disease detector can correctly detect sight-threatening diseases in the presence of sensor noise. Existing methods for evaluating the robustness of a machine learning model, given some distribution of input corruptions, are largely based on either measuring the average performance on random corruptions, or measuring the worst performance across all possible corruptions. In this blog post, we present a method for evaluating the test-time performance of machine learning models over some distribution of input corruptions.

Studies on robustness in machine learning have largely focused on the specific notion of adversarial robustness. Adversarial robustness considers minimizing the *worst-case* performance of the model across some set of possible perturbations, where model performance is typically measured by some loss function that quantifies how different the model's prediction is from the ground truth label. Deep neural network image classifiers have been shown to be particularly brittle to adversarially perturbed images, causing reason for concern as deep neural networks are increasingly deployed in real-world applications. Unfortunately, training a model to be adversarially robust is quite difficult in practice. Computing the worst-case perturbation can be challenging, and the worst-case loss is often considered an overconservative objective that degrades the model's performance on unperturbed images. Due to these challenges, separate studies have focused on a more practical notion of robustness that can be broadly interpreted as the average performance of the model on random perturbations from some distribution. However, measuring the average loss over random perturbations can account poorly for low-probability perturbations that cause an incorrect prediction by the model. 

Until now, these two types of robustness have typically been seen as largely separate notions. We believe there is inherent value in generalizing these two notions to place them in a unified framework. While the worst-case robustness objective can overconcentrate on adversarial perturbations that are relatively unlikely to occur, the average-case objective can ignore challenging perturbations that have a low yet non-negligble probability of occurring. The shortcomings of these two opposing notions of robustness suggest the need for a robustness objective in between these two extremes. In this blog post, we propose a more fine-grained spectrum of robustness objectives, and a simple approach to numerically approximate these objectives. 

To motivate our notion of intermediate robustness, consider the following example from the ImageNet classification dataset shown below. The leftmost image is the original image, with the ground-truth label of "tench". The image classifier correctly classifies this image with 73% confidence. We randomly sample 1,000 Gaussian noise perturbations, and the model classifies 85% of these perturbed versions of this image correctly as "tench" (e.g. the middle image). However, even just by randomly sampling we can encounter adversarial examples, such as the rightmost image, which the model classifies with high confidence as "Komodo dragon" instead of the correct class "tench". Worst-case robustness does not make much sense here, because the perturbation distributon we are considering here is unbounded. On the other hand, given the model has low loss for a large majority of the randomly perturbed images, average-case robustness will place too much weight on samples like the middle image, and not enough weight on samples like the rightmost image. 

<img src=./fish.png  width="1000">

## A simple generalization of robustness

First, we present a simple generalization of robustness that encompasses these two extreme notions of robustness. We make the observation that there is a natural interpolation between the notions of adversarial robustness and robustness to random perturbations. We define a neural network \\( h \\) with parameters \\( \theta \\) that takes as input an image \\( x \\), and a loss function \\( \ell \\) that measures how different the model predictions are from the true label \\( y \\). We consider robustness to perturbations \\( \delta \\) from some perturbation distribution with density \\( \mu \\). Now consider the following expectation over the functional \\( q \\)-norm of the loss according to this perturbation density,

$$ \mathbf{E}\_{x, y \sim \mathcal{D}} \Big[ ||\ell(h\_\theta(x+\delta), y)||\_{\mu, q} \Big], $$

where the \\( q \\)-norm of the loss with perturbation density \\( \mu \\) is defined as follows:

$$ ||\ell(h\_\theta(x+\delta), y)||\_{\mu, q} = \mathbf{E}\_{\delta \sim \mu} [|\ell(h\_\theta(x+\delta), y)|^q]^{1/q} = \Big( \int |\ell(h\_\theta(x+\delta), y)|^q \mu(\delta)d\delta) \Big)^{1/q} $$

This expectation corresponds to average-case robustness (the expected loss on random perturbations) when \\( q = 1 \\), and worst-case robustness (the expected maximum loss over all possible perturbations) when \\( q = \infty \\). When we set \\( 1 < q < \infty \\), we enable a full spectrum of robustness measurements, which we term intermediate-\\( q \\) robustness. This allows us to evaluate robustness in a wide range between these two extremes.

## Approximating the objective using path sampling

Simply writing the objective in this manner is not particularly useful on its own. In most cases, the objective we just defined cannot be computed exactly because it requires computing a high dimensional integral over the perturbation space, and so we must resort to numerical approximation methods. We can naively estimate this integral by using Monte Carlo sampling, drawing random samples from the perturbation distribution, and approximating the objective by way of the following empirical mean:

$$ \hat{Z}\_\text{Monte Carlo} := \Big( \frac{1}{m} \sum\_{i=1}^m \ell \big( h\_\theta(x+\delta^{(i)}), y \big)^q \Big)^{1/q}$$

By the law of large numbers, with enough samples this method will eventually converge to the desired integral. However, for larger values of \\( q \\), the integral will be dominated by values with large loss, and Monte Carlo sampling will be insufficient to approximate this integral well, as random sampling will place too much weight on regions of low loss. This can be simply visualized in the following plots, where we show for when the probability distribution is concentrated in a region that contributes less to the integral approximation, then as we increase \\( q \\), this is only further dramaticized. 

<img src=./integral.png  width="1000">

Instead, we can reformulate the problem of estimating our desired integral as one of estimating the ratio of normalizing constants. The advantage of this reformulation is that we can use a wealth of techniques developed for estimating ratios of normalizing constants. Specifically, we argue to use the MCMC-based method called path sampling [Gelman and Meng, 1998] to approximate our desired ratio. We show that for the precise form of the integral in question, the eventual estimator produced by this method takes on a very simple form: it consists of the geometric mean over samples generated from a certain annealed loss-based distribution. Specifically, we linearly interpolate \\( t^{(i)} \\) between 0 and \\( q \\) and sample \\( \delta^{(i)} \\) from \\( p(\delta|t^{(i)}) \propto \ell(h\_\theta(x+\delta),y)^t \mu(\delta) \\). Then the path sampling estimator is given by the following:

$$ \hat{Z}\_\text{Path sampling} := \Big( \prod\_{i=1}^m \ell \big( h\_\theta(x+\delta^{(i)}), y \big)^q \Big)^{1/m}$$

In order to sample from the loss-based distribution, we can use Markov chain Monte Carlo (MCMC) methods, which allow us to draw samples from this distribution, provided we know a functional proportional to it for which the values can be calculated. Specifically, we use the Hamiltonian Monte Carlo (HMC) method [Duane et al., 1987] due to its sample efficiency in high-dimensional spaces.


## Evaluating along the spectrum of robustness

We will now show the results of evaluating various levels of robustness of an image classifier trained on the CIFAR-10 dataset, comparing estimates by the proposed path sampling/HMC method to those by the naive Monte Carlo method. We consider perturbations \\( \delta \\) continuous uniformly distributed within the \\( \ell\_\infty \\)-norm ball with radius \\( \epsilon \\), i.e. each component of 𝛿 is uniformly distributed between \\( [-\epsilon, \epsilon] \\). The intermediate-\\( q \\) robustness for different values of \\( q \\) are shown below:

<img src=./interpolating.jpeg  width="500">

This figure shows that our intermediate-\\( q \\) robustness objective does indeed interpolate between average-case robustness (\\( q=1 \\)) and worst-case (adversarial) robustness by varying \\( q \\). While both of the approximation methods result in a similar objective value for \\( q=1 \\), for larger values of \\( q \\), path sampling results in a more accurate (higher) estimate of the objective value, given the same computational budget. 

We compare the convergence of the two estimators as we increase the computational budget (e.g. number of samples), as shown below:

Convergence with \\( q=1 \\) | Convergence with \\( q=100 \\)
:------------------:|:------------------:
![q=1](./convergence-q=1.jpeg)| ![q=100](./convergence-q=100.jpeg) 

When approximating the objective with \\( q=1 \\), as shown on the left, both methods converge to the same estimate with relatively few iterations. However, when approximating the objective with \\( q=100 \\), as shown on the right, the Monte Carlo method fails to accurately approximate the objective, even with a large number of iterations.

## Training for different levels of robustness

We can also *train* models to specific levels of robustness by minimizing our intermediate robustness objective for different values of \\( q \\). However, this is computationally challenging because a non-trivial number of samples is needed to accurately estimate the robustness objective. Due to the computational complexity, we train an image classifier on the simpler MNIST dataset (considering the same set of perturbation as described above), minimizing the intermediate robustness objective for different values of \\( q \\) (estimated using path sampling and HMC). We then evaluate the performance of each model at different levels of robustness, as shown below:

Training with \\( q=1 \\) | Training with \\( q=100 \\)
:------------------:|:------------------:
![q=1](./train_q1.png)| ![q=100](./train_q100.png)

On the left, the model trained with \\( q=1 \\) is just like data augmentation, training on randomly sampled perturbations from the distribution. The model trained with \\( q=100 \\), shown on the right, is much more robust when evaluated using larger values of  \\( q \\) as compared to the model trained with \\( q=1 \\). The main takeaway here is that the choice of \\( q \\) allows for fine-grained control over the desired level of robustness.

## Conclusion

We proposed a new robustness objective that smooths the gap between robustness to random perturbations and adversarial robustness by generalizing these notions of robustness as functional \\( q \\)-norms of the loss function over the perturbation distribution. We introduced a method for approximating this objective using path sampling, an MCMC-based method. We showed experimentally this technique produces more accurate and efficient estimates of the objective than simple Monte Carlo sampling. Finally, we highlighted the ability to train for specific levels of robustness using our objective and approximation method. For more details, see our paper [here](https://proceedings.neurips.cc/paper/2021/file/ea4c796cccfc3899b5f9ae2874237c20-Paper.pdf) and code [here](https://github.com/locuslab/intermediate_robustness).

## References

Andrew Gelman and Xiao-Li Meng. Simulating normalizing constants: From importance sampling
to bridge sampling to path sampling. Statistical science, pages 163–185, 1998.

Simon Duane, Anthony D Kennedy, Brian J Pendleton, and Duncan Roweth. Hybrid monte carlo.
Physics letters B, 195(2):216–222, 1987

## Acknowledgements

This blog post is based on the NeurIPS 2021 paper titled [Robustness between the worst and average case](https://proceedings.neurips.cc/paper/2021/file/ea4c796cccfc3899b5f9ae2874237c20-Paper.pdf), which was joint work with [Anna Bair](https://annaebair.github.io/), [Huan Zhang](https://www.huan-zhang.com/), and [Zico Kolter](http://zicokolter.com/). This work was supported by a grant from the Bosch Center for Intelligence. 