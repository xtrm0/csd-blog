+++
# The title of your blogpost. No sub-titles are allowed, nor are line-breaks.
title = "Robustness between the worst and average case"
# Date must be written in YYYY-MM-DD format. This should be updated right before the final PR is made.
date = 2023-01-31

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
As machine learning systems become increasingly implemented in safety-critical applications, such as autonomous driving and healthcare, we need to ensure these systems are reliable and trustworthy. For example, we might wish to determine whether a traffic light classifier on a self-driving car can correctly classify the color of the light even in the presence of heavy rain, or an eye disease detector can correctly detect sight-threatening diseases in the presence of sensor noise. Existing methods for evaluating the robustness of a machine learning model, given some distribution of input corruptions, are largely based on either measuring the average performance on random corruptions, or measuring the worst performance across all possible corruptions. Each of these extreme notions of robustness has its limitations. Worst-case, or adversarial, performance is often criticized as being an overconservative evaluation metric, whereas average-case performance can account poorly for low-probability corruptions that cause the model to fail. In this blog post, we present an alternative method for evaluating the test-time performance of machine learning models over some distribution of input corruptions that measures robustness between the worst and average case. 

To motivate our intermediate robustness metric, consider the following scenario in which we are interested in evaluating the robustness of an image classification model to Gaussian noise. The leftmost image below is a sample from the ImageNet validation dataset, with the ground-truth label "tench", which an image classifier trained on ImageNet training dataset correctly classifies with 73% confidence. Given 1,000 random samples of Gaussian noise, the model classifies 85% of these noised images correctly as "tench", e.g. as shown in the middle image below. The rightmost image, however, shows a randomly noised image that the model classifies with high confidence as "Komodo dragon" instead of the correct class "tench". Given the model correctly classifies a large majority of the randomly perturbed images, the average-case robustness evaluation will place too much weight on samples like the middle image, and not enough weight on "adversarial" samples like the rightmost image. However, with Gaussian noise being unbounded, the worst-case robustness evaluation of this image classification model will place too much weight on arbitrarily large amounts of noise that have an extremely small probability of occurring. 

<img src=./fish.png  width="1000">

## An intermediate robustness metric

We observe that there exists a natural interpolation between measuring adversarial or worst-case robustness and robustness to random perturbations. First, we define a neural network \\( h \\) with parameters \\( \theta \\), and a loss function \\( \ell \\) that measures how different the model predictions are from the true label \\( y \\) given an input \\( x \\). We are interested in measuring the robustness of this model to perturbations \\( \delta \\) from some perturbation distribution with density \\( \mu \\). Now consider the following expectation over the functional \\( q \\)-norm of the loss according to this perturbation density,

$$ \mathbf{E}\_{x, y \sim \mathcal{D}} \Big[ ||\ell(h\_\theta(x+\delta), y)||\_{\mu, q} \Big], $$

where the \\( q \\)-norm of the loss with perturbation density \\( \mu \\) is defined as follows:

$$ ||\ell(h\_\theta(x+\delta), y)||\_{\mu, q} = \mathbf{E}\_{\delta \sim \mu} [|\ell(h\_\theta(x+\delta), y)|^q]^{1/q} = \Big( \int |\ell(h\_\theta(x+\delta), y)|^q \mu(\delta)d\delta) \Big)^{1/q} $$

This expectation corresponds to the expected loss on random perturbations (average-case) when \\( q = 1 \\), and the expected maximum loss over all possible perturbations (worst-case) when \\( q = \infty \\). With \\( 1 < q < \infty \\), we enable a full spectrum of intermediate robustness measurements. This allows us to evaluate a model's robustness in a wide range between the two extremes of average and worst case performance.

## Approximating the metric using path sampling

Unfortunately, in most cases, the metric we just defined cannot be calculated exactly because it requires computing a high-dimensional integral over the perturbation space, and so we must resort to numerical approximation methods. We can naively estimate the intermediate robustness metric by using Monte Carlo sampling, drawing random samples from the perturbation distribution, and approximating the objective by way of the following empirical mean:

$$ \hat{Z}\_\text{Monte Carlo} := \Big( \frac{1}{m} \sum\_{i=1}^m \ell \big( h\_\theta(x+\delta^{(i)}), y \big)^q \Big)^{1/q}$$

By the law of large numbers, with enough samples this method should eventually converge close to the desired integral. However, as we increase the value of \\( q \\), the integral we are interested in estimating will be progressively dominated by values with large loss. With larger values of \\( q \\), Monte Carlo sampling will be insufficient to approximate this integral well, as random sampling will place too much weight on regions of low loss. This can be visualized in the plots below for approximating the integral \\( \int f(x)^q \mu(x)dx \\) for an arbitrary function \\( f \\) and probability density \\( \mu \\). When the probability distribution is concentrated in a region that contributes less to the integral approximation (i.e. low values of \\( f \\) in this case), then as we increase \\( q \\), Monte Carlo sampling will be less and less effective at approximating the integral. This can be observed in the figure below by comparing the plots for increasing values of \\( q \\) from left to right. 

<img src=./integral.png  width="1000">

Given the insufficiency of naive Monte Carlo sampling for large values of \\( q \\), we instead can more accurately estimate the integral of interest by using path sampling [Gelman and Meng, 1998]. Path sampling is a technique for approximating partition functions (normalizing constants) of unnormalized probability density functions. The integral we are interested in approximating is in fact the same as the partition function of the following unnormalized probability density function,

$$ \tilde{p}(\delta) = \ell(h_\theta(x+\delta),y)^q \mu(\delta). $$

Estimating a partition function using path sampling requires constructing and sampling from a "path" of probability density functions. In our setting, we can construct such a path by interpolating \\( t^{(i)} \\) between 0 and \\( q \\) and sampling a perturbation \\( \delta^{(i)} \\) from \\( p(\delta|t^{(i)}) \propto \ell(h\_\theta(x+\delta),y)^t \mu(\delta) \\). The path sampling estimation of the intermediate robustness metric ultimately takes the form of the geometric mean of the losses given the sampled perturbations,

$$ \hat{Z}\_\text{Path sampling} := \Big( \prod\_{i=1}^m \ell \big( h\_\theta(x+\delta^{(i)}), y \big) \Big)^{1/m}.$$

In order to sample from each \\( p(\delta|t) \\), we can use Markov chain Monte Carlo (MCMC) methods, which allow us to draw samples from a given probability density provided we know a functional proportional to it for which the values can be calculated. Hamiltonian Monte Carlo (HMC) is one such method [Duane et al., 1987] that is particularly useful due to its sample efficiency in high-dimensional spaces.


## Evaluating the intermediate robustness of an image classifier

Now that we have introduced a metric for evaluating the intermediate robustness of a model, along with methods for approximating this metric, we can evaluate the performance of a model at different robustness levels given some perturbation distribution. Because it is a setting commonly considered in the adversarial (worst-case) robustness literature, we evaluate the robustness of an image classifier to (continuous) perturbations \\( \delta \\) uniformly distributed within the \\( \ell\_\infty \\)-norm ball with radius \\( \epsilon \\), i.e. each component of \\( \delta \\) is uniformly distributed between \\( [-\epsilon, \epsilon] \\). Specifically, in the figure below, we plot the intermediate robustness of an image classifier trained on the CIFAR-10 dataset.

<img src=./interpolating.jpeg  width="500">

This figure shows that the proposed intermediate-\\( q \\) robustness metric does indeed capture the gap between the two existing robustness metrics, effectively interpolating between average-case robustness (\\( q=1 \\)) and worst-case (adversarial) robustness measurements by increasing the value of \\( q \\). We additionally compare the two methods we discussed for approximating the intermediate robustness metric. While both of the approximation methods result in a similar estimate for \\( q=1 \\), for larger values of \\( q \\), path sampling results in a more accurate (higher) estimate given the same computational budget, more closely approaching the adversarial loss. 

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