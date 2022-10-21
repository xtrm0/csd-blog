+++
# The title of your blogpost. No sub-titles are allowed, nor are line-breaks.
title = "Robustness between the worst and average case"
# Date must be written in YYYY-MM-DD format. This should be updated right before the final PR is made.
date = 2022-09-06

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

Typically in machine learning, we fit a model to some training data, and evaluate the model's predictions on a separate test set. We generally assume that the training and test data come from the same distribution, however this is not always the case. For example, the labels could be noisy -- human labelers are not perfect, and make mistakes. The distribution of the data could also change over time, due to changes in the environment, or using the model in a new scenario. Additionally, the inputs to the model could be corrupted in some manner at inference time, whether that be due to natural effects such as weather, or due to an adversary purposely attempting to change the model's prediction. In general, we can consider robustness as *the performance of the model when the train and test distributions differ*.

Consider the task of multi-class image classification using a deep neural network. We define a neural network \\( h_\theta : \mathcal{X} \rightarrow \mathbb{R}^k \\) with parameters \\( \theta \\) that takes as input an image \\( x \\) and outputs a \\( k \\)-dimensional vector, where \\( k \\) is the number of classes in our task. We define a loss function \\( \ell : \mathbb{R}^k \times \mathbb{Z}\_+ \rightarrow \mathbb{R}\_+ \\) that takes as input the model output and the ground truth label, i.e. the index of the true class. The *risk* of a classifier is its expected loss under the true distribution of samples,
$$ \mathbf{E}\_{x, y \sim \mathcal{D}} [ \ell(h\_{\theta}(x),y) ].$$ Alternatively, we can evaluate the model using the *adversarial risk*: 
$$ \mathbf{E}\_{x, y \sim \mathcal{D}} \big[ \max\_{\delta: ||\delta||\_p \leq \epsilon} \ell(h\_\theta(x+\delta),y) \big], $$
where we compute the *worst-case* loss on some region around the image. We may want to consider the worst-case performance of a classifier if we are concerned about some adversary purposely attempting change the output of our model, e.g. consider malware and spam detectors. In some scenarios, however, we are less interested in a classifier’s performance on worst-case perturbations, and more interested in how they might perform in settings that are not adversarial, but that are different from the setting they were trained on. For example, we may wish to evaluate the performance of a self-driving camera in the presence of severe weather, or evaluate a facial recognition system on blurred images. This could be construed as shifting the focus from worst-case perturbations, to a focus on robustness to random perturbations, or average robustness. This can be described by evaluating a classifier via the following objective, 
$$ \mathbf{E}\_{x, y \sim \mathcal{D}} \big[ \mathbf{E}\_{x \sim P(x)} [\ell(h\_\theta(x+\delta), y)] \big] $$
where \\( P(x) \\) denotes some distribution over the possible perturbations. This formulation also underlies standard data augmentation strategies in deep learning, where random transformations are applied to the training images.

Adversarial example (worst-case) | Common corruptions (average-case)
:------------------:|:------------------:
![Adversarial example](https://openai.com/content/images/2017/02/adversarial_img_1.png)| ![Common corruptions](./common-corruptions.jpeg) 

There exist several issues with these two extreme notions of robustness. For example, often times worst-case robustness is considered to be too conservative. In reality, an adversary may not be able to construct the absolute worst-case perturbation for a given example. Additionally, optimizing for worst-case robustness presents challenges for training, often resulting in worse performance on the original, unperturbed images as compared to minimizing the standard risk. And while the main criticism of worst-case robustness is that it focuses too much on the worst case, the criticism of average-case is that it is not robust enough. Considering again we do have an adversary trying to fool our image classifier, even if they can’t construct the worst-case perturbation, they can likely still construct a perturbed image that is more difficult for the classifier than a randomly chosen perturbation. This suggests that there could be value from something in the middle, between these two extremes. 

## A simple generalization of robustness

First, we present a simple generalization of robustness, that encompasses the spectrum between these two extreme notions of robustness. We make the observation that there is a natural interpolation between the notions of adversarial robustness and robustness to random perturbations. We show this as follows:

Define the \\( q \\)-norm of a function \\( f \\) with density \\( \mu \\):

$$ ||f||\_{\mu, q} = \mathbf{E}\_{x \sim \mu} [|f(x)|^q]^{1/q} = \Big( \int |f(x)^q \mu(x)dx) \Big)^{1/q} $$

Now consider the expectation: 

$$ \mathbf{E}\_{x, y \sim \mathcal{D}} \Big[ ||\ell(h\_\theta(x+\delta), y)||\_{\mu, q} \Big] $$

For a smooth loss \\( \ell \\), This corresponds to average-case robustness (expected loss on random samples from 
\\( \mu \\)) when \\( q = 1 \\), worst-case robustness (the expected adversarial loss over the domain of \\( \mu \\)) when \\( q = \infty \\), and what we call *intermediate* robustness when \\( 1 < q < \infty \\). Now we have enabled a full spectrum of robustness measurements, which we term intermediate-\\( q \\) robustness. This allows us to evaluate the performance of classifiers in a wide range between these two extremes. 

## Approximating intermediate-\\( q \\) robustness

The integral above cannot be computed exactly in most cases owing to the fact that it requires computing a high dimensional integral over the perturbation space, however we can use numerical approximation methods. Consider the integral:

$$ Z := \Big( \int \ell \big( h\_\theta(x+\delta), y \big)^q \mu(\delta) d\delta \Big)^{1/q}$$

One could naively estimate this integral by using Monte Carlo sampling, and draw \\( m \\) perturbation samples randomly from density \\( \mu \\), and approximate the objective as the following empirical mean:

$$ \hat{Z}\_\text{Monte Carlo} := \Big( \frac{1}{m} \sum\_{i=1}^m \ell \big( h\_\theta(x+\delta^{(i)}), y \big)^q \Big)^{1/q}$$

However, because the integral will be dominated by values with large loss, Monte Carlo sampling will be insufficient to approximate this integral well for larger values of \\( q \\), as random sampling will place too much weight on regions of low loss.

Instead, we can reformulate the problem as one of evaluating the partition function or normalizing constant, of a particular unnormalized probability density. Specifically, we define an (unnormalized) density over the perturbation as follows: \\( \tilde{p}(\delta|q) = \ell(h\_\theta(x+\delta),y)^q\mu(\delta) \\). The partition function is an integral over the unnormalized probability of all states: \\( \int \tilde{p}(\delta | q) \\). Then we can see that evaluating the (\\( q \\)-th root of) partition function of this distribution is exactly the same as that of computing the integral of interest. The reasoning behind reformulating the problem in this manner, is that there are a large number of techniques developed for partition function estimation. One such approach, which we choose to use, is called path sampling, introduced by Gelman and Meng. 

TODO insert proof

Path sampling:
Linearly interpolate \\( t^{(i)} \\) between 0 and \\( q \\) and sample \\( \delta^{(i)} \\) from
$$ p(\delta|t^{(i)}) \propto \ell(h\_\theta(x+\delta),y)^t \mu(\delta)$$

$$ \hat{Z}\_\text{Path sampling} := \Big( \prod\_{i=1}^m \ell \big( h\_\theta(x+\delta^{(i)}), y \big)^q \Big)^{1/m}$$

In order to generate the samples for the path sampling estimation from the desired distribution \\( p(\delta|t^{(i)}) \\), we can use Markov chain Monte Carlo (MCMC) methods. MCMC methods allow us to draw samples from this distribution, provided we know a functional proportional to it, such as the unnormalized distribution we defined previously, for which the values can be calculated.

## Experiments
Consider perturbations \\( \delta \\) continuous uniformly distributed within the set \\( \Delta \\), the \\( \ell\_\infty \\)-norm ball with radius \\( \epsilon \\) where \\( \Delta = \{ \delta: ||\delta||\_\infty \leq \epsilon \} \\). 
\\(||\delta||\_\infty = \max\_i |\delta\_i| \\)
i.e. each component of 𝛿 is uniformly distributed between \\( [-\epsilon, \epsilon] \\).

q=1 | q=100
:------------------:|:------------------:
![q=1](./convergence-q=1.jpeg)| ![q=100](./convergence-q=100.jpeg) 

<img src=./interpolating.jpeg  width="500">

q=1 | q=100
:------------------:|:------------------:
![q=1](./train_q1.png)| ![q=100](./train_q100.png) 
