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
As machine learning systems become increasingly implemented in safety-critical applications, such as autonomous driving and healthcare, we need to ensure these systems are reliable and trustworthy. For example, we might wish to determine whether a traffic light classifier on a self-driving car can correctly classify the color of the light even in the presence of heavy rain, or an eye disease detector can correctly detect sight-threatening diseases in the presence of sensor noise. Existing methods for evaluating the robustness of a machine learning model given some distribution of input corruptions, are largely based on either measuring its average performance on randomly sampled corruptions, or measuring its worst performance across all possible corruptions. Each of these extreme notions of robustness has its limitations. Worst-case, or adversarial, performance is often criticized as being an overconservative evaluation metric, whereas average-case performance can account poorly for low-probability corruptions that cause the model to fail. In this blog post, we present an alternative method for evaluating the test-time performance of machine learning models, over some distribution of input corruptions, that measures robustness *between* the worst and average case. 

To motivate such an intermediate robustness metric, consider the following scenario in which we are interested in evaluating the robustness of an image classification model to Gaussian noise applied to the input images. The leftmost image below is a sample from the ImageNet validation dataset, with the ground-truth label "tench", which an image classifier trained on the ImageNet training dataset correctly classifies with 73% confidence. Given one thousand random samples of Gaussian noise, the model classifies 85% of these noised images correctly, e.g. as shown in the middle image below. The rightmost image, however, shows a randomly noised image that the model incorrectly classifies with high confidence as "Komodo dragon". 

<img src=./fish.png  width="1000">

Given the model correctly classifies a large majority of the randomly perturbed images, evaluating according to average-case robustness will place too much weight on "easy" noise samples like the middle image, and not enough weight on samples like the rightmost image that are harder for the model to classify correctly, though not necessarily adversarial. Evaluating the image classifier according to worst-case robustness doesn't make much sense for this particular noise distribution, because the worst-case noise could be an arbitrarily large amount of noise with extremely low probability due to the Gaussian distribution being unbounded. In general, we argue that a more practical evaluation of robustness considers something stricter than simply average performance on random perturbations, but not quite as strict as adversarial robustness.

## An intermediate robustness metric

We observe that there exists a natural interpolation between measuring adversarial or worst-case robustness and robustness to random perturbations. First, let us define a neural network \\( h \\) with parameters \\( \theta \\), and a loss function \\( \ell \\) that measures how different the model predictions are from the true label \\( y \\) given an input \\( x \\). Consider we are interested in measuring the robustness of this model to perturbations \\( \delta \\) from some perturbation distribution with density \\( \mu \\). Now consider the following expectation over the functional \\( \ell_q\\) or \\( q \\)-norm[^1] of the loss according to this perturbation density,

$$ \mathbf{E}\_{x, y \sim \mathcal{D}} \Big[ ||\ell(h\_\theta(x+\delta), y)||\_{\mu, q} \Big], $$

where the \\( q \\)-norm of the loss with perturbation density \\( \mu \\) is defined as follows:

$$ ||\ell(h\_\theta(x+\delta), y)||\_{\mu, q} = \mathbf{E}\_{\delta \sim \mu} [|\ell(h\_\theta(x+\delta), y)|^q]^{1/q} = \Big( \int |\ell(h\_\theta(x+\delta), y)|^q \mu(\delta)d\delta) \Big)^{1/q}.$$

Assuming a smooth, non-negative loss function, this expectation corresponds to the expected loss on random perturbations (average-case) when \\( q = 1 \\), 

$$ || \ell(h\_\theta(x+\delta), y) ||\_{\mu, 1} = \mathbf{E}\_{\delta \sim \mu} [\ell(h\_\theta(x+\delta), y)], $$

and the expected maximum loss over all possible perturbations (worst-case) when \\( q = \infty \\), 

$$ || \ell(h\_\theta(x+\delta), y) ||\_{\mu, \infty} = \text{max}\_{\delta \in \text{Supp}(\mu)}[\ell(h\_\theta(x+\delta), y)],$$

with the \\( \ell_\infty \\)-norm being the limit of the \\( \ell_q \\)-norm as \\( q  \rightarrow \infty \\). Intuitively, as we increase \\( q > 1\\), more emphasis will be placed on high loss values, as the losses become more strongly "peaked" due to the exponent of \\( q \\). And so by increasing \\(q \\) from \\( 1 \\) to \\( \infty \\), we enable a full spectrum of intermediate robustness measurements that are increasingly strict by placing more weight on high loss values. This formulation allows us to evaluate a model's robustness in a wide range between the two extremes of average and worst case performance, as well as place existing notions of robustness under the same general framework.

[^1] Note that this is typically called the \\( \ell_p \\) or \\( p \\)-norm or rather than the \\( q \\)-norm, however we wanted to differentiate between the common use of \\( \ell_p \\) -norm balls as perturbation regions in adversarial robustness studies. We emphasize that intermediate robustness can be evaluated according to any perturbation distribution.

## Approximating the metric using path sampling

Unfortunately, in most cases, the metric we just defined cannot be calculated exactly because it requires computing a high-dimensional integral over the perturbation space, and so we must resort to numerical approximation methods. We first discuss how the simple Monte Carlo estimator, which is based on random samples drawn from the perturbation distribution, will not provide a good approximation of the intermediate robustness metric for larger values of \\( q \\), due to value of the integral being dependent on fewer perturbations that result in higher loss values. We propose the use of an alternative estimator known as path sampling [Gelman and Meng, 1998] to more accurately approximate the intermediate robustness metric, doing so by sampling from certain annealed densities, resulting in perturbations that contribute more significantly to the integral.  

To begin, we can naively estimate the intermediate robustness metric by using Monte Carlo sampling, drawing random samples from the perturbation distribution, and approximating the objective by way of the following empirical mean:

$$ \hat{Z}\_\text{Monte Carlo} := \Big( \frac{1}{m} \sum\_{i=1}^m \ell \big( h\_\theta(x+\delta^{(i)}), y \big)^q \Big)^{1/q}$$

With enough samples, this method theoretically should eventually converge to something close to the desired integral. However, as we increase the value of \\( q \\), the integral we are interested in estimating will be progressively dominated by values with large loss. With larger values of \\( q \\), Monte Carlo sampling will be insufficient to approximate this integral well, as random sampling will place too much weight on regions of low loss. This can be visualized in the plots below for approximating the integral \\( \int f(x)^q \mu(x)dx \\) for an arbitrary function \\( f \\) and probability density \\( \mu \\). When the probability distribution is concentrated in a region that contributes less to the integral approximation (i.e. low values of \\( f \\) in this case), then as we increase \\( q \\), Monte Carlo sampling will be less and less effective at approximating the integral. This can be observed in the figure below by comparing the plots for increasing values of \\( q \\) from left to right. 

<img src=./integral.png  width="1000">

We can alternatively view our case of integral approximation as the well-studied problem of estimating the partition function, or normalizing constant, of a probability density. Often, when considering a density \\( p(\delta) \\), we can evaluate the unnormalized density \\( \tilde{p}(\delta) \\), where \\( p(\delta) = \frac{1}{Z}\tilde{p}(\delta) \\), but cannot directly calculate the partition function, or normalizing constant, \\( Z = \int \tilde{p}(\delta)\mu(\delta) \\). Importance sampling is one common approach to this problem that boosts samples in regions that contribute more largely to the integral by sampling from some alternative density that approximates the target density \\( p \\), rather than sampling directly from \\( \mu \\). For example, we can consider some class of proposal densities on the same space \\( p(\delta|t)=\frac{1}{Z(t)}\tilde{p}(\delta|t) \\), defined by some parameter \\( t \\) , and sample from one of \\( p(\delta|t) \\). Such sampling can be done using Markov chain Monte Carlo (MCMC) methods, which allow us to draw samples from a given probability density provided we know a functional proportional to it for which the values can be calculated. An improvement over importance sampling, bridge sampling [Bennett, 1976; Meng and Wong, 1996] is a way of further reducing the approximation errors that involves sampling from more than one approximate density, e.g. more than one \\( p(\delta|t) \\), to reduce the distance between the target and proposal densities. Taking this one step further, path sampling [Gelman and Meng, 1998] is an estimator that uses infinitely many bridge densities to more accurately approximate the partition function.

In order to use the path sampling estimator in our setting, we observe that integral we are interested in approximating is the same as the partition function of the following unnormalized probability density function,

$$ \tilde{p}(\delta) = \ell(h_\theta(x+\delta),y)^q \mu(\delta).$$

We can consider the following class of proposal densities on the same space,

$$ p(\delta|t) \propto \ell(h\_\theta(x+\delta),y)^t \mu(\delta),$$

and construct a path by interpolating \\( t^{(i)} \\) between 0 and \\( q \\) and sampling a perturbation \\( \delta^{(i)} \\) from \\( p(\delta|t^{(i)}) \\). The path sampling estimator of the intermediate robustness metric ultimately takes the form of the geometric mean of the losses given the sampled perturbations from these annealed proposal densities,

$$ \hat{Z}\_\text{Path sampling} := \Big( \prod\_{i=1}^m \ell \big( h\_\theta(x+\delta^{(i)}), y \big) \Big)^{1/m}.$$


## Evaluating the intermediate robustness of an image classifier

Now that we have introduced a metric for evaluating the intermediate robustness of a model, along with methods for approximating this metric, we can evaluate the performance of a model at different robustness levels given some perturbation distribution. We show that the intermediate robustness metric interpolates between measurements of average and the worst-case robustness, providing a multitude of additional ways in which we can measure a model's robustness. We also highlight the advantage of the path sampling estimator over the Monte Carlo estimator for approximating intermediate robustness by showing how the Monte Carlo estimator consistently underestimates the metric for larger values of \\( q \\).

Because it is a setting commonly considered in the adversarial (worst-case) robustness literature, we evaluate the robustness of an image classifier to (continuous) perturbations \\( \delta \\) uniformly distributed within the \\( \ell\_\infty \\)-norm ball with radius \\( \epsilon \\), i.e. each component of \\( \delta \\) is uniformly distributed between \\( [-\epsilon, \epsilon] \\). In the figure below, we plot the test-time performance of an image classifier, trained on the CIFAR-10 dataset, using our intermediate robustness metric for different values of \\( q \\), showing approximations both by the Monte Carlo sampling and path sampling methods. We additionally plot the adversarial, worst-case loss incurred by the model within this perturbation set.

<img src=./interpolating.jpeg  width="500">

This figure shows that our proposed intermediate robustness metric does indeed capture the gap between the two existing robustness metrics, effectively interpolating between average-case robustness (\\( q=1 \\)) and worst-case (adversarial) robustness measurements when increasing the value of \\( q \\). Additionally, this figure illustrates that while both of the approximation methods result in a similar estimate for \\( q=1 \\), for larger values of \\( q \\), path sampling results in a higher, more accurate estimate of the intermediate robustness metric, more closely approaching the adversarial loss, when compared to Monte Carlo sampling. The benefit of the path sampling estimator can be further shown in the figure below, which plots the convergence of the Monte Carlo sampling and path sampling estimates of the intermediate robustness metric given an increasing number of samples \\( m \\).

Convergence with \\( q=1 \\) | Convergence with \\( q=100 \\)
:------------------:|:------------------:
![q=1](./convergence-q=1.jpeg)| ![q=100](./convergence-q=100.jpeg) 

Again, when approximating the robustness metric for \\( q=1 \\), shown on the left, both estimators converge to the same value with relatively few iterations. However, when approximating the intermediate robustness metric for \\( q=100 \\), shown on the right, the Monte Carlo sampler results in estimates that are consistently lower and less accurate than those of path sampling, even with a large number of samples. 

## Training for different levels of robustness

We can also *train* machine learning models according to specific levels of robustness by choosing a value of \\( q \\) and minimizing the intermediate robustness objective. However, training intermediate robust models is computationally challenging because a non-trivial number of perturbation samples is needed to accurately estimate the robustness objective, even when using the path sampling method. While evaluating models simply requires one iteration over the test dataset, training requires multiple iterations over the training dataset, resulting in an extremely expensive procedure when effectively multiplying the dataset size by the number of perturbaton samples. Due to this computational complexity, we train an image classifier on the simpler MNIST dataset (considering the same set of perturbations as described previously) to minimize the intermediate robustness objective for different values of \\( q \\) (approximated using the path sampling). Specifically, we train one model with \\( q=1 \\), which is just like training with data augmentation (training on randomly sampled perturbations), and we train one model with \\( q=100 \\), which is somewhere in between training with data augmentation and adversarial training (training on worst-case perturbations). We then evaluate the intermediate and adversarial robustness of each of the final trained models, and present the results in the figure below.

Training with \\( q=1 \\) | Training with \\( q=100 \\)
:------------------:|:------------------:
![q=1](./train_q1.png)| ![q=100](./train_q100.png)

While the model trained with \\( q=1 \\), shown on the left, and the model trained with \\( q=100 \\), shown on the right, have similar performance when evaluated at less strict robustness levels, \\( q=1 \\) and \\( q=10 \\), the model trained with \\( q=100 \\) is much more robust when comparing the stricter \\( q=1000 \\) and adversarial robustness measurements. Ultimately, the main takeaway from training using the proposed intermediate robustness objective is that the choice of \\( q \\) allows for fine-grained control over the desired level of robustness, rather than being restricted to average-case or worst-case objectives.

## Conclusion

In this work, we proposed a new robustness metric that allows for evaluating a machine learning model's intermediate robustness, bridging the gap between evaluating robustness to random perturbations and robustness to worst-case perturbations. This intermediate robustness metric generalizes average-case and worst-case notions of robustness under the same framework as functional \\( q \\)-norms of the loss function over the perturbation distribution. We introduced a method for approximating this metric using path sampling, which results in a more accurate estimate of the metric compared to naive Monte Carlo sampling when evaluating at robustness levels approaching adversarial robustness. We empirically showed, by evaluating an image classifier on additive noise perturbations, that the proposed intermediate robustness metric enables a broader spectrum of robustness measurements, between the least strict notion of average performance on random perturbations and the most conservative notion of adversarial robustness. Finally, we highlighted the potential ability to train for specific levels of robustness using intermediate-\\( q \\) robustness as a training objective. For additional details, see our paper [here](https://proceedings.neurips.cc/paper/2021/file/ea4c796cccfc3899b5f9ae2874237c20-Paper.pdf) and code [here](https://github.com/locuslab/intermediate_robustness).

## References

Andrew Gelman and Xiao-Li Meng. Simulating normalizing constants: From importance sampling
to bridge sampling to path sampling. Statistical science, pages 163–185, 1998.

Bennett, Charles H. "Efficient estimation of free energy differences from Monte Carlo data." Journal of Computational Physics 22.2 (1976): 245-268.

Meng, Xiao-Li, and Wing Hung Wong. "Simulating ratios of normalizing constants via a simple identity: a theoretical exploration." Statistica Sinica (1996): 831-860.

Simon Duane, Anthony D Kennedy, Brian J Pendleton, and Duncan Roweth. Hybrid monte carlo.
Physics letters B, 195(2):216–222, 1987

## Acknowledgements

This blog post is based on the NeurIPS 2021 paper titled [Robustness between the worst and average case](https://proceedings.neurips.cc/paper/2021/file/ea4c796cccfc3899b5f9ae2874237c20-Paper.pdf), which was joint work with [Anna Bair](https://annaebair.github.io/), [Huan Zhang](https://www.huan-zhang.com/), and [Zico Kolter](http://zicokolter.com/). This work was supported by a grant from the Bosch Center for Intelligence.