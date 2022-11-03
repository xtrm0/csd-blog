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
Machine learning systems are becoming increasingly prevalent in the world we live in. As machine learning is incorporated in security critical applications, such as autonomous driving and healthcare, how can we ensure these systems we use are reliable and trustworthy? This question is still largely unanswered, motivating the need for studying *robustness* in machine learning. While robustness is a rather broad term, in this blog post, study the reliability of machine learning models upon receiving inputs that have been *corrupted* in some manner. For example, a traffic light classifier on a self-driving car should correctly classify the color of the light even in the presence of heavy rain, and an eye disease detector should correctly detect sight-threatening diseases in the presence of sensor noise. 

A large body of work on robustness in machine learning has focused on the specific notion of adversarial robustness, which refers to the correctness of the model when the input has been corrupted by the worst-case, i.e. adversarial, perturbation in some set of possible perturbations. However, adversarial robustness is often criticized as being an overconservative objective. Training a model to be adversarially robust is challenging, and encountering worst-case perturbations, i.e. adversarial attacks, in practice is considered to be somewhat unrealistic. Given these limitations of adversarial robustness, separate studies have focused on a more natural notion of robustness that can be broadly interpreted as the correctness of the model on random perturbations from some perturbation distribution. Rather than measuring the robustness of the model based on its worst-case performance over all perturbations, in this setting we typically measure the robustness of the model in terms of its *average* performance on random perturbations. However, while the worst-case robustness objective can overconcentrate on adversarial perturbations that are relatively unlikely to occur, the average-case objective can ignore challenging perturbations that have a low yet non-negligble probability of occurring. 

The shortcomings of these two opposing notions of robustness suggest the need for a robustness objective in between these two extremes. 




## A simple generalization of robustness

First, we present a simple generalization of robustness, that encompasses the spectrum between these two extreme notions of robustness. We make the observation that there is a natural interpolation between the notions of adversarial robustness and robustness to random perturbations.

We define a neural network \\( h \\) with parameters \\( \theta \\) that takes as input an image \\( x \\), and a loss function \\( \ell \\) that measures how different the model predictions are from the true label \\( y \\). Our general robustness objective is the following:

$$ \mathbf{E}\_{x, y \sim \mathcal{D}} \Big[ ||\ell(h\_\theta(x+\delta), y)||\_{\mu, q} \Big] $$

For conciseness, let \\( L(\delta) = \ell(h\_\theta(x+\delta), y) \\). The \\( q \\)-norm of the loss with perturbation density \\( \mu \\) is the following:

$$ ||L(\delta)||\_{\mu, q} = \mathbf{E}\_{\delta \sim \mu} [|L(\delta)|^q]^{1/q} = \Big( \int |L(\delta)|^q \mu(\delta)d\delta) \Big)^{1/q} $$

This corresponds to average-case robustness (expected loss on random samples from 
\\( \mu \\)) when \\( q = 1 \\), worst-case robustness (the expected adversarial loss over the domain of \\( \mu \\)) when \\( q = \infty \\), and what we call *intermediate* robustness when \\( 1 < q < \infty \\). Now we have enabled a full spectrum of robustness measurements, which we term intermediate-\\( q \\) robustness. This allows us to evaluate the performance of classifiers in a wide range between these two extremes. 

## Approximating intermediate-\\( q \\) robustness

The integral above cannot be computed exactly in most cases owing to the fact that it requires computing a high dimensional integral over the perturbation space, however we can use numerical approximation methods. 

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

Hamiltonian Monte Carlo is a one such MCMC method that better avoids random walk behavior by borrowing a concept from physics called Hamiltonian dynamics. Each state \\( \delta \\) is considered to be the position of the system, and is artificially augmented with a momentum term \\( p \\). The physical system is described by the Hamiltonian function, which is just a function of potential and kinetic energy. The position and momentum terms are updated by discretizing the differential equations of the Hamiltonian function. This approach requires computing the gradient of the logarithm of the target density, and so in our case, this requires the loss to be a differentiable function of the perturbation distribution.

$$ H(\delta, p) = -t \log (\ell(h_\theta(x+\delta),y)) + \log \mu(\delta) + \frac{||p||^2}{\delta^2}$$


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
