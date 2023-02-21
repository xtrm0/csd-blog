+++
# The title of your blogpost. No sub-titles are allowed, nor are line-breaks.
title = "Classification with Strategically Withheld Data"
# Date must be written in YYYY-MM-DD format. This should be updated right before the final PR is made.
date = 2023-02-21

[taxonomies]
# Keep any areas that apply, removing ones that don't. Do not add new areas!
areas = ["Artificial Intelligence"]
# Tags can be set to a collection of a few keywords specific to your blogpost.
# Consider these similar to keywords specified for a research paper.
tags = ["mechanism design", "strategic classification"]

[extra]
# For the author field, you can decide to not have a url.
# If so, simply replace the set of author fields with the name string.
# For example:
#   author = "Harry Bovik"
# However, adding a URL is strongly preferred
author = {name = "Hanrui Zhang", url = "https://www.andrew.cmu.edu/user/hanruiz1/" }
# The committee specification is simply a list of strings.
# However, you can also make an object with fields like in the author.
committee = [
    {name = "Fei Fang", url = "https://feifang.info/"},
    {name = "Steven Jecmen", url = "https://sjecmen.github.io/"},
    {name = "Nihar Shah", url = "https://www.cs.cmu.edu/~nihars/"},
]
+++

*This blog post is based on a [research paper](https://arxiv.org/pdf/2012.10203.pdf) with the same title, authored by Anilesh Krishnaswamy, Haoming Li, David Rein, Hanrui Zhang, and Vincent Conitzer, published at AAAI 2021.*

*TL;DR: We investigate a classification problem where each data point being classified is controlled by an agent who has its own goals or incentives, and may strategically withhold certain features in order to game the classifer and get a more desirable label.  We use (an oversimplied version of) college admissions as a running example to illustrate how traditional methods may fail in such settings, as well as how insights from the economic field of mechanism design may help.  We then demonstrate a principled method --- Incentive-Compatible Logistic Regression --- for classification problems with strategically withheld features, which achieves remarkable empirical performance on credit approval data.*

Applicants to most colleges in the US are required to submit their scores for at least one of the SAT and the ACT.
Applicants usually take one of these two tests --- [whichever works to their advantage](https://www.princetonreview.com/college/sat-act).
However, given the growing competitiveness of college admissions, many applicants now take both tests and then strategically decide whether to [drop one of the scores](https://blog.collegevine.com/should-you-submit-your-sat-act-scores/) (if they think it will hurt their application) or report both.
The key issue here is that it is impossible to distinguish between an applicant who takes both tests but reports only one, and an applicant who takes only one test --- for example, because the applicant simply took the one required by their school, the dates for the other test did not work with their schedule, or for other reasons that are not strategic in nature.
Such ambiguity makes it harder for colleges to accurately evaluate applicants, especially since colleges now increasingly [rely on machine learning techniques to help make admissions decisions](https://www.fastcompany.com/90342596/schools-are-quietly-turning-to-ai-to-help-pick-who-gets-in-what-could-go-wrong).


## What Can Go Wrong?

Consider the following simplified scenario: each applicant may naturally (i.e., before they strategically drop one of the scores) have an SAT score, an ACT score, or both.
We also assume these scores are normalized, so they become real numbers between 0 and 1.
Suppose the true competitiveness of an applicant is the average of the scores they naturally have --- that is, if an applicant naturally has only one score, then that score is their true competitiveness; if an applicant naturally has both scores, then their true competitiveness is the average of the two scores.
We will use this setup as our running example from now on.
We will not try to "solve" this example problem (later we will see that in some cases, there is no satisfactory solution to the problem), but rather, we will use the example to illustrate the limitations of some classical methods, as well as to motivate the more principled method that we propose.

Now a college wishes to assess each applicant's competitiveness based on the scores, and admit all applicants whose competitiveness is at least 0.5 (or some threshold chosen by the college).
Assuming all applicants report all scores they naturally have, it is easy to make admissions decisions: the college simply computes each applicant's average score, and admits that applicant if the average is at least 0.5.
In other words, the college implements a simple **classifier**, which assigns any applicant **label "admitted"** if the average value of their ***natural* features** is at least 0.5.

However, the simple classifier has its problems: after it is used for admissions for a couple of years, applicants may eventually figure out how it works (for example, by talking to past applicants and researching their test scores and application results).
Once applicants know how the decisions are made, they can easily game the system by strategically withholding information.
Consider, for example, an applicant with an SAT score of 0.6 and an ACT score of 0.2.
The applicant would normally be rejected since their true competitiveness is 0.4, which is smaller than the classifier's threshold, 0.5.
However, knowing how the classifier works, the applicant can withhold the ACT score and report the SAT score only to the college.
Then the classifier would mistakenly believe that the applicant's competitiveness is 0.6, and admit the applicant.
As a result, the classifier is not accurate anymore when applicants act strategically and try to game it.


## (How) Can We Fix It?

Taking into consideration the fact that applicants will eventually figure out how decisions are made, and in response to that, withhold scores strategically to maximize their chances, is it still possible for the college to admit exactly those applicants that the college wants to admit?
The answer is --- perhaps not so surprisingly --- it *depends on the **distribution** of applicants*, including how often each score is missing, as well as how the two scores correlate.
To illustrate this dependence, below we discuss two extreme cases.

![two extreme cases](./examples.png)

In one extreme case (illustrated in the left of the figure), every applicant naturally has both scores and the college knows that.
Then, the college's problem is again simple: the college admits an applicant if and only if that applicant reports both scores, and the average of the two scores is at least 0.5.
This ensures that no applicant would want to withhold a score, because that would lead to automatic rejection.
Moreover, no applicant would be mistakenly rejected because they cannot report both scores, since everyone naturally has both scores.

In another extreme case (illustrated in the right of the figure), there are only two types of applicants: a type-1 applicant naturally has an SAT score of 0.6 and does not have an ACT score; a type-2 applicant naturally has an SAT score of 0.6 and an ACT score of 0.2.
Ideally, the college would like to admit all type-1 applicants (because their competitiveness is 0.6), and reject all type-2 applicants (because their competitiveness is 0.4).
However, this is impossible once applicants respond strategically to the college's classifier.
For example, if the college admits all type-1 applicants whose SAT score is 0.6 and ACT score is missing, then a type-2 applicant would pretend to be a type-1 applicant by withholding their ACT score, and get admitted too.
On the other hand, to prevent type-2 applicants getting in by pretending to be type-1 applicants, the college would have to reject all type-1 applicants too, eventually admitting no one.


## A Principled Approach via Mechanism Design

The above discussion highlights one fact: when applicants respond strategically, the optimal classifier must depend on the distribution of applicants, even if the college's criteria for admissions stays the same, and there is no restrictions whatsoever on how many applicants can be admitted.
This is reminiscent of problems in [mechanism design](https://en.wikipedia.org/wiki/Mechanism_design).
In a mechanism design problem, a **principal** designs and commits to a decision rule, or a **mechanism** --- in the admissions problem discussed above, the principal is the college, and the decision rule is the classifier used for admissions.
Self-interested **agents** (e.g., applicants) then respond to this rule by reporting (possibly nontruthfully) their private information (e.g., their test scores) to the principal.
The mechanism then chooses an **outcome** (e.g., admissions decisions) based on the reported information.
Taking the agents' strategic behavior into consideration, the principal aims to design a mechanism to maximize their own **utility** (e.g., accuracy of admissions decisions), which generally depends on both the outcome and the agents' private information.
In fact, in our running example, the college's problem can be cast directly as a mechanism design problem.
Below we will see how tools from mechanism design can help in solving the college's classification problem.

### Incentive Compatibility and the Revelation Principle

A key notion in mechanism design is [incentive compatibility](https://en.wikipedia.org/wiki/Incentive_compatibility): a mechanism is incentive-compatible if it is always in the agents' best interest to truthfully report their private information.
Applied to our running example, incentive compatibility means that applicants would never want to withhold a test score that they naturally have.
One reason that incentive compatibility is so important in mechanism design is that it is often *without loss of generality*: if there is no restriction on the ways in which an agent can (mis)report their private information, then for any (possibly not incentive-compatible) mechanism, there always exists an "incentive-compatible version" of that mechanism which achieves the same effects.
This is famously known as the [revelation principle](https://en.wikipedia.org/wiki/Revelation_principle).
The reason that the revelation principle holds is simple: the principal can adapt any mechanism into an incentive-compatible one by "misreporting for" the agents, in the exact way that the agents would misreport in response to the original mechanism.
We show that a variant of the revelation principle applies to the college's classification problem (and more generally, to all classification problems with strategically withheld features).
This greatly simplifies the problem, because without loss of generality, we only need to consider classifiers under which applicants have no incentive to withhold any score.
This effectively removes the strategic aspect and leaves a clean classification problem.

### Incentive-Compatible Logistic Regression

Given the revelation principle, we propose a principled method, **incentive-compatible logistic regression**, for classification problems with strategically withheld data.
The idea is simple: we run the classical gradient-based algorithm for logistic regression, *but with the search space restricted to classifiers that are incentive-compatible*.
The college can then use the resulting model to classify applicants in an incentive-compatible way.
We will see below how this can be done by adding a projection step to the region of incentive-compatible classifiers, after each gradient step.

Recall that in logistic regression, the goal is to learn a set of coefficients \\(\{\beta_i\}\\), one for each feature \\(i\\), as well as an intercept \\(\beta_0\\), such that for each data point \\((x, y)\\), the predicted label \\(\hat{y}\\) given by
\\[
    \hat{y} = \mathbb{I}\left[\sigma\left(\beta_0 + \sum_i x_i \cdot \beta_i\right) \ge 0.5\right]
\\]
fits the true label \\(y\\) as well as possible.
Here, \\(\sigma\\) is the logistic function, defined as
\\[
    \sigma(t) = 1 / (1 + e^{-t}).
\\]
Mapping these notions back to our running example, each data point \\((x, y)\\) corresponds to an applicant, where each feature \\(x_i\\) is one of the two scores, and the true label \\(y\\) is \\(1\\) (corresponding to "admitted") if the applicant's true competitiveness is at least the college's desired threshold, and \\(0\\) (corresponding to "rejected") otherwise.
The classifier computes a predicted label \\(\hat{y}\\) for each data point, which is the admissions decision for that specific applicant.
Naturally, the college wants \\(\hat{y}\\) to fit \\(y\\) as well as possible.

It turns out there is a simple condition for the classifier of the above form to be incentive-compatible.
Without loss of generality, suppose each feature \\(x_i\\) is always nonnegative.
this is naturally true in our running example, since each feature is a score between \\(0\\) and \\(1\\); in general, we can shift the features if they are not nonnegative.
Moreover, if a feature is missing in a data point, then we simply treat that feature as \\(0\\).
Then a classifier induced by \\(\{\beta_i\}\\) is incentive-compatible if and only if each \\(\beta_i\\) is nonnegative.
This is because if some \\(\beta_i < 0\\), then a data point with feature \\(x_i > 0\\) will be able to increase their score, \\(\sigma\left(\beta_0 + \sum_i x_i \cdot \beta_i\right)\\), by withholding feature \\(x_i\\).
Depending on the values of other features, this will sometimes change the predicted label of that data point from \\(0\\) (i.e., rejected) to \\(1\\) (i.e., admitted).
In other words, such a classifier cannot be incentive-compatible.
On the other hand, if each \\(\beta_i\\) is nonnegative, then for any data point, withholding a feature \\(x_i\\) can never increase the score, so there is no incentive to withhold any feature.

Given the above characterization, we can simply adapt the gradient-based algorithm for (unconstrained) logistic regression to find a good incentive-compatible classifier.
We initialize the classifier arbitrarily, and repeat the following steps for each data point \\((x, y)\\) until convergence:

- **The gradient step**: Let
\\[
    \beta_0 \gets \beta_0 - \eta_t \cdot \left(\sigma\left(\beta_0 + \sum_i x_i \cdot \beta_i\right) - y\right).
\\]
For each feature \\(i\\), let
\\[
    \beta_i \gets \beta_i - \eta_t \cdot \left(\sigma\left(\beta_0 + \sum_i x_i \cdot \beta_i\right) - y\right) \cdot x_i.
\\]
Here, \\(\eta_t\\) is the learning rate in step \\(t\\).
This rate normally decreases in \\(t\\), e.g., \\(\eta_t = 1 / \sqrt{t}\\).

- **The projection step**: For each feature \\(i\\), let
\\[
    \beta_i \gets \max\\{0, \beta_i\\}.
\\]

This can be viewed as an instantiation of the projected gradient descent algorithm: the gradient step is exactly the same as in (unconstrained) logistic regression, and the projection step ensures that the incentive-compatibility constraint is satisfied.

Coming back to our running example, incentive-compatible logistic regression will assign a nonnegative weight to each test score and admit an applicant if the weighted sum of the two scores exceeds some threshold.  Note that this does not "solve" the college's problem in all cases: for example, between the two extreme cases discussed above, incentive-compatible logistic regression would work very well in the first case, but in the second case its performance would not be practically meaningful, simply because the second case is intrinsically hard and no classifier can achieve a reasonable accuracy there.

## Experimental Results

We empirically evaluate incentive-compatible logistic regression on 4 real-world credit approval datasets from the [UCI ML Repository](http://archive.ics.uci.edu/ml/index.php), based on historical data collected in Australia, Germany, Poland, and Taiwan.
Each data point in each dataset corresponds to a single credit application, with tens of features (3 datasets provide 15-23 features, and the other provides 64), including annual income, employment status, current balance in savings account, etc.
Each data point has a binary label, which is either "approve" (i.e., 1) or "reject" (i.e., 0).
We preprocess the datasets by randomly dropping some features for each data point, thus simulating naturally missing features.
We consider two ways of reporting in our evaluation:

- **Truthful reporting**: Each data point always reveals all features it naturally has to the classifier.
This is the assumption made by the baseline methods, which we compare against in our evaluation.

- **Strategic reporting**: In reponse to the classifier, each data point optimally withholds a subset of features to maximize the chance of getting approved (i.e., label 1).
For incentive-compatible logistic regression, strategic reporting is equivalent to truthful reporting.
However, as we will see, the baseline methods perform significantly worse with strategic reporting (which is natural, since they were not designed to be robust against strategic manipulation).

As for the baseline methods, we compare against **logistic regression** (without incentive-compatibility), **neural networks**, and **random forests**.
These are the most popular and accurate methods in credit approval applications.
For more details of the experiments, please see Section 6 of [our paper](https://arxiv.org/pdf/2012.10203.pdf).

The accuracy of each classifier tested on each dataset can be found in the table below.
Note that there are two numbers in each cell: the left one corresponds to the accuracy under truthful reporting, and the right one corresponds to the accuracy under strategic reporting.

| Classifier | Australia | Germany | Poland | Taiwan |
| ------------------------------------------- | --------- | ------- | ------ | ------ |
| Incentive-compatible logistic regression    | **0.800** / **0.800** | 0.651 / **0.651** | 0.698 / **0.698** | 0.646 / **0.646** |
| Logistic regression (baseline)              | **0.800** / 0.763 | **0.652** / 0.580 | 0.714 / 0.660 | 0.670 / 0.618 |
| Artificial neural networks (baseline)       | **0.800** / 0.747 | **0.652** / 0.580 | **0.719** / 0.636 | **0.688** / 0.543 |
| Random forest (baseline)                    | 0.797 / 0.541 | 0.633 / 0.516 | 0.709 / 0.522 | 0.684 / 0.588 |

Here we make two observations:

- Under strategic reporting, incentive-compatible logistic regression is consistently much more accurate than all 3 baseline methods.
This highlights the importance of robustness against strategic manipulation by design.
- The accuracy of incentive-compatible logistic regression under strategic reporting is often comparable to that of the baseline methods under truthful reporting.
In other words, although strategic manipulation poses challenges in the design of a good classifier, from an information-theoretic perspective, the classification problem does not become much harder.

## Conclusion

We study the problem of classification when each data point can strategically withhold some of its features to obtain a more favorable outcome.
We propose a principled classification method, incentive-compatible logistic regreggsion, which is robust to strategic manipulation.
The new method is tested on real-world datasets, showing that it outperforms out-of-the-box methods that do not account for strategic behavior.
More generally, we draw connections between strategic classification and mechanism design, which may inspire future work in other strategic classification settings.
