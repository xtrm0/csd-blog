+++
# The title of your blogpost. No sub-titles are allowed, nor are line-breaks.
title = "T2FPV: Dataset and Method for Correcting First-Person View Errors in Pedestrian Trajectory Prediction"
# Date must be written in YYYY-MM-DD format. This should be updated right before the final PR is made.
date = 2024-03-19

[taxonomies]
# Keep any areas that apply, removing ones that don't. Do not add new areas!
areas = ["Artificial Intelligence"]
# Tags can be set to a collection of a few keywords specific to your blogpost.
# Consider these similar to keywords specified for a research paper.
tags = ["computer-vision", "social-navigation", "trajectory-prediction", "simulation", "robotics"]

[extra]
# For the author field, you can decide to not have a url.
# If so, simply replace the set of author fields with the name string.
# For example:
#   author = "Harry Bovik"
# However, adding a URL is strongly preferred
author = {name = "Benjamin Stoler", url = "https://benstoler.com" }
# The committee specification is simply a list of strings.
# However, you can also make an object with fields like in the author.
committee = [
    {name = "Reid Simmons", url = "http://www.cs.cmu.edu/~reids/"},
    {name = "Matthew O'Toole", url = "https://www.cs.cmu.edu/~motoole2/"},
    {name = "Steven Jecmen", url = "https://sjecmen.github.io/"}
]
+++


As AI technology advances, more and more autonomous robots are being tasked with
navigating among people in shared environments. Such applications span academia
and industry, including, for example, sidewalk delivery robots, robotic museum
guides, and automated room service in hotels.  In order to have robust,
socially-compliant navigation policies, these robots must be adept at predicting
(or forecasting) pedestrian motion in busy environments.  In these environments,
the most natural setting for humans and robots is an egocentric, first-person
view (FPV), where a camera is placed on the robot itself as it moves around, as
highlighted in the figure below:

<figure style="text-align:center;">
<img src=./sidewalk_robot.png  width="400" alt="Coco Delivery sidewalk robot" title="Coco Delivery sidewalk robot">
<figcaption style="margin-top:10px">A Coco Delivery robot.</figcaption>
</figure>

However, the vast majority of prior work in pedestrian trajectory forecasting
has instead relied on third-person sensing, where cameras are mounted 
on infrastructure (such as rooftops) or on a stationary drone hovering
above the scene in order to record naturalistic behavior of humans.
These birds-eye view (BEV) recordings are then processed into datasets
comprising ground truth examples of how humans navigate among each other, and 
used to train downstream trajectory prediction models.
So, **why has this been the standard approach**, and **why is it problematic**?

## Background

Pedestrian motion forecasting is important as it is used to inform a robot's
planning module as to other peoples' intents and likely paths. This is used not
just to avoid collisions, but also to ensure social compliance---that is, moving
in a way so as to not cause disruption, discomfort, or general inconvenience to
humans in the scene.

While heuristic models, such as social forces, have long been utilized, the
advancement of deep learning techniques has dominated the recent
state-of-the-art (SOTA).  In these approaches, a machine learning model is
trained on a dataset of recorded human behavior as a form of static
learning-from-demonstration.  These datasets are considered trajectory datasets,
containing at minimum the coordinates over time (or trajectory) of all people
(or "agents") in a given scene.  High quality dataset curation is thus paramount
for high quality model performance.

A majority of existing datasets for this problem utilize a top-down perspective,
such as the the ETH/UCY [1] collection of pedestrian datasets, shown below. One
reason for this approach is the ease of annotation.  In a BEV perspective,
peoples' trajectories can be easily tracked in ground-plane coordinates over
time.  This is in stark contrast to FPV, where 3D segmentation and detection
algorithms are required to annotate observed pedestrians. Furthermore, using BEV
eliminates much of the occlusion problem, where people may be impossible to
annotate when behind other people, buildings, or objects.  This occlusion can
lead to tracking errors, like mis-association or losing somebody's trajectory
altogether, which can require data imputation to fill the missing values.
Together, these errors and noise from FPV sensing are denoted as "FPV errors".


<figure style="text-align:center;">
<img src=./hotel_bev.png  width="400" alt="Hotel example from ETH/UCY" title="Hotel example from ETH/UCY">
<figcaption style="margin-top:10px">Hotel example from ETH/UCY.</figcaption>
</figure>

Another problem that BEV perspective addresses is ensuring naturalistic human
behavior.  To collect data in FPV, either robots or humans themselves have to
wear cameras when navigating among others.  This can lead to several
psychological effects, such as the Hawthorne effect, where people's behavior can
change when they know they're being observed, as well as the novelty effect [10].
Thus, while FPV datasets for pedestrian trajectory forecasting exist, they
contain both FPV errors as well as no guarantees of naturalistic behavior in the
first place.

However, BEV data has a very serious flaw: in nearly all deployed
situations, a robot does **not** have access to top-down, perfect information of
others in the scene. Training a prediction policy which **relies** on having
this information, rather than having to deal with FPV errors, causes prediction
models to be unrealistically effective, leading to a false sense of confidence
in their abilities.

## Our Approach: T2FPV

To address the above limitations, we propose "Trajectories to First Person View"
(T2FPV), a method for constructing an FPV version of data from a trajectory-only
dataset.  This process entails starting with a BEV-recorded dataset and then
performing a high-fidelity simulation from each person's FPV perspective. We use
this approach to generate, annotate, and release a version of the popular
ETH/UCY dataset in this new perspective.  Then, we conduct SOTA detection and
tracking therein to get realistic partial perception from each person's view. In
this setting, we observe the effects of FPV errors, and develop a module to
address them by refining the initial imputation of missing data in an end-to-end
manner with trajectory prediction.  This "Correction of FPV Errors" (CoFE)
module decreases prediction displacement errors by more than 10% on average when
compared to all tested imputation and forecasting approach combinations.

## Constructing an FPV Dataset

We begin by leveraging the SEANavBench [2] simulation environment, consisting of
the five high-fidelity pre-modeled locations, or "folds", within the ETH/UCY
dataset.  We then replay the recorded data by attaching a simulated camera to
each pedestrian, requiring a few simplifying assumptions: pedestrians are all
roughly the same height, using randomly selected human models, and also their
gazes are aligned with the direction they're moving in. We render vidoes for
each person and output ground truth (GT) annotations at each frame, consisting of the
list of which other people are visible at any given time.

Next, we conduct SOTA detection and tracking on these rendered videos, in order
to emulate realistic perception which a deployed social navigation robot uses.
We employ an off-the-shelf object detector, DD3D [3], as well as a very
effective probabilistic tracker [4]. We make some small modifications to improve
performance on our specific task, such as altering the tracker's matching metric
and modifying the feature map thresholds in DD3D. As is common for ETH/UCY
evaluation, we train one model for each of the five folds as a test set, using
the other four folds as training and validation in a leave-one-out manner.
Overall, we find that this approach performs reasonably well on standard metrics
including Average Precision and Average Multi-Object Tracking Accuracy.

Finally, we put together these outputs into an FPV dataset. We start with the
standard scene segmentation steps on ETH/UCY, where scenes are considered in a
fixed-length, sliding window manner over the original data, and only scenes with
at least two agents present at the same time are kept. These scenes consist of
20 timesteps at 2.5 frames per second, where the first eight are kept as
"history" and the next 12 are considered the "future" to be predicted. We
utilize the Hungarian matching algorithm [11] to associate together the GT set of
visible agents (from our simulation annotations directly) with the observed set
of people from detection and tracking. Where a given BEV scene has *N* people
moving around at the same time, we thus create *N* FPV variations of this scene,
from each agent's perspective. Importantly, **these scenes contain FPV errors!**

This entire process is highlighted in the figure below, showing how a single top-down scene
produces many first-person scenes. The heading titles such as "Sec IV-A" refer to sections in 
our reference paper, for further reading [5]:

<figure style="text-align:center;">
<img src=./overview.png  width="800" alt="T2FPV process overview" title="T2FPV process overview">
</figure>

## Improving Robustness to Perception Errors: CoFE

As discussed above, one key type of FPV error is that of missing observations in
the history portion of a trajectory due to detection and tracking errors,
requiring the imputation of missing data points for most trajectory prediction
methods. Although many prior works leverage simple imputation approaches like
linear interpolation and exponential smoothing, there are more sophisticated,
SOTA deep learning imputation techniques such as NAOMI [6]. However, these
approaches still rely on unrealistic assumptions, at least for human motion
forecasting: 1) data points are missing in a random manner; and 2) data points
observed around missing values can be trusted. The first assumption doesn't hold
because data is missing pathologically due to errors in the perception system,
whereas the second fails because surrounding data points also incur positional
estimation errors from perception.

Therefore, we propose to incorporate a new module to sit in between the
imputation and prediction steps of the pipeline, consisting of a neural network
trained end-to-end (E2E) with the downstream prediction model. This "Correction
of FPV Errors", or CoFE, module is similar to previous recurrent neural network
(RNN) prediction approaches. The model first takes in an initial guess at
imputation from some upstream method (e.g. NAOMI). Then, it proceeds in an
encoder-decoder manner, where an encoder RNN is used to build a hidden state
representation of this input sequence. A decoder RNN is next used to
sequentially output **refinements** of the trajectory, before passing it on to
the trajectory forecasting phase.  To encourage this module to perform such
refinements, a simple mean-square error (MSE) loss objective is utilized,
between the refined history track (i.e., the output of the decoder) and the
ground truth associated history. The refined trajectory is used **instead of**
the trajectory produced directly from the detection and tracking modules, to
train both the CoFE module as well as the trajectory prediction model itself in
an E2E fashion, along with the original loss objective of the prediction model. 

The full architecture is visualized in the figure below, with
a deeper discussion of each component explained in our paper:

<figure style="text-align:center;">
<img src=./cofe.png  width="800" alt="CoFE module architecture" title="CoFE module architecture">
</figure>


## Experiments and Results

We implemented several representative approaches for the ETH/UCY trajectory
prediction task, standing out along key techniques in human motion prediction:
variational prediction (VRNN [7]), social awareness (A-VRNN [8]), and goal
conditioning (SGNet [9]). For data imputation, we also incorporate three
relevant approaches, including the commonly-used linear interpolation,
exponential smoothing, and the aforementioned NAOMI deep learning method.

We utilized the standard leave-one-out evaluation methodology for ETH/UCY, where
one model is trained for each of the five folds and each imputation and
prediction approach combination. We trained one version of the prediction
approach with our CoFE module and objective, and one version without it.
Finally, we used the standard metrics in the trajectory prediction task of
Average and Final Displacement Errors (ADE and FDE), measuring the L2-distance
between the predicted future path and ground truth for the entire predicted
portion and just the last time step respectively. Our results are summarized in
the table below, where the final column refers to the average of ADE / FDE
respectively over the five folds. As shown, all combinations of
approaches performed better with our CoFE module than without, by an average of
more than 10%.

<figure style="text-align:center;">
<img src=./results.png  width="400" alt="Experiment results" title="Experiment results">
</figure>

To gain further insight into the behavior of CoFE, we conducted an ablation
study and various qualitative analyses. In the ablation, we find that the E2E
training is essential for the improved performance, as is the effect of only
refining the missing, imputed data points rather than surrounding observed
points as well. We include an example of the qualitative analysis below:

<figure style="text-align:center;">
<img src=./qualitative.png  width="1000" alt="Qualitative example" title="Qualitative example">
</figure>

In this example, NAOMI by itself trusts surrounding points in the data too much,
performing a simple extrapolation. When paired with CoFE, the approach is more
effective at capturing underlying patterns in the data, correcting the FPV
errors and resulting in better forecasting.

## Future Work

While our T2FPV approach and CoFE module is effective, we note here some
potential avenues of future improvement. Although SEANavBench is a high-fidelity
environment, further effort in improving its realism would be useful. Realism
could be enhanced not just by increasing the 3D-modeling asset and animation
qualities, but also by further improving alignment between the reproduced
scenery and the original locations. Additionally, for associating detection and
tracking trajectories with their corresponding GT tracks, we relied on Hungarian
matching on our tracking output directly, which incurred some number of identity
association errors.  Incorporating recent works on affinity-based techniques
re-tracking algorithms could be a promising way to help with this problem and
even further reduce FPV errors. One further thread of research is also applying
these techniques to related domains where FPV sensing is required, such as
autonomous driving. While this related field has its own challenges, considering
imputation and prediction together to account for sensing errors could be a
promising direction therein.

## Conclusion

In existing work, pedestrian trajectory prediction has mainly been studied in an
unrealistic BEV perspective. In this work, we introduce a more realistic
first-person view trajectory prediction problem where agents need to make
predictions based on partial, imprecise information. We present T2FPV, a method
for generating high-fidelity FPV datasets for pedestrian navigation by
leveraging existing real-world trajectory datasets, and use it to create and
release an FPV version of ETH/UCY. We also propose and evaluate CoFE, a module
that successfully refines imputation of missing data in an end-to-end manner
with trajectory forecasting algorithms to reduce FPV errors. Therefore, we argue
that incorporating more realism throughout the perception pipeline is an
important direction to move toward in enabling robots to navigate in the real
world. For more information, please see our paper [5].

## References

[1] Pellegrini, Stefano, et al. "You'll never walk alone: Modeling social behavior for multi-target tracking." 2009 IEEE 12th international conference on computer vision. IEEE, 2009.

[2] Tsoi, Nathan, et al. "An approach to deploy interactive robotic simulators on the web for hri experiments: Results in social robot navigation." 2021 IEEE/RSJ International Conference on Intelligent Robots and Systems (IROS). IEEE, 2021.

[3] Park, Dennis, et al. "Is pseudo-lidar needed for monocular 3d object detection?." Proceedings of the IEEE/CVF International Conference on Computer Vision. 2021.

[4] Chiu, Hsu-kuang, et al. "Probabilistic 3d multi-object tracking for autonomous driving." arXiv preprint arXiv:2001.05673 (2020).

[5] Stoler, Benjamin, et al. "T2FPV: Dataset and Method for Correcting First-Person View Errors in Pedestrian Trajectory Prediction." 2023 IEEE/RSJ International Conference on Intelligent Robots and Systems (IROS). IEEE, 2023. 

[6] Liu, Yukai, et al. "Naomi: Non-autoregressive multiresolution sequence imputation." Advances in neural information processing systems 32 (2019).

[7] Chung, Junyoung, et al. "A recurrent latent variable model for sequential data." Advances in neural information processing systems 28 (2015).

[8] Bertugli, Alessia, et al. "AC-VRNN: Attentive Conditional-VRNN for multi-future trajectory prediction." Computer Vision and Image Understanding 210 (2021): 103245.

[9] Wang, Chuhua, et al. "Stepwise goal-driven networks for trajectory prediction." IEEE Robotics and Automation Letters 7.2 (2022): 2716-2723.

[10] Irfan, Bahar, et al. "Social psychology and human-robot interaction: An uneasy marriage." Companion of the 2018 ACM/IEEE international conference on human-robot interaction. 2018.

[11] Kuhn, Harold W. "The Hungarian method for the assignment problem." Naval research logistics quarterly 2.1‐2 (1955): 83-97.

