+++
# The title of your blogpost. No sub-titles are allowed, nor are line-breaks.
title = "Understanding Setup Times"
# Date must be written in YYYY-MM-DD format. This should be updated right before the final PR is made.
date = 2021-08-13

[taxonomies]
# Keep any areas that apply, removing ones that don't. Do not add new areas!
areas = ["Systems", "Theory"]
# Tags can be set to a collection of a few keywords specific to your blogpost.
# Consider these similar to keywords specified for a research paper.
tags = ["queueing theory","multiserver systems", "setup times", "exceptional first service"]

[extra]
# For the author field, you can decide to not have a url.
# If so, simply replace the set of author fields with the name string.
# For example:
#   author = "Harry Bovik"
# However, adding a URL is strongly preferred
author = {name = "Jalani Williams", url ="https://jalaniw.github.io/" }
# The committee specification is simply a list of strings.
# However, you can also make an object with fields like in the author.
committee = [
    "Dimitrios Skarlatos",
    "Alan Scheller-Wolf",
    "Arjun Teh",
]
+++

# Why setup times are important

Nobody *likes* waiting in line.
But some of the most frustrating experiences that I’ve ever had waiting are when I get in a super long line, I peek around to the front of the line, and I see that the server isn’t even ready to serve --*they're still setting up!*
It's **terrible,** and it happens *everywhere:*
- You’re at the store and you just want to buy a pack of gum, but somehow it takes forever for the cashier’s register to boot up.
- It’s lunch and you want a slice of pizza, but somehow the pizza oven still needs time to get hot.
- You’re dead-tired from being sick and you just want to grab your antibiotics and go to sleep, but somehow the pharmacist has to go through an *excruciatingly long* badge-in process.
The frustrating part of these situations isn’t really the waiting *per se* –kids learn to wait their turn in kindergarten.
No, the frustrating part is that somehow you’re waiting and it feels almost unnecessary; why weren’t these servers ready before this huge line formed in the first place?
**Why do we spend so much time waiting for servers to set up?**

# Why we wait
Of course, the answer to “why do we wait?” is the usual answer: because not-waiting costs money.
In basically all of these queueing systems, you could just have all of your servers running all the time.
And if the only thing you cared about was how long people spent waiting, then of course you would just have all of your servers running all the time.
But keeping a server on costs money –even if that server is not actively doing work.
That’s why, in many queyueing systems, instead of keeping their servers on all the time, system managers will actively scale the number of servers that are on in a dynamic way.
It turns out that if you do this ''dynamic control'' in the right way, then you can cut down on operating costs A LOT.
For example, Google’s version of dynamic scaling, called Autopilot, was able to cut average resource waste in half, from 46% to 23%.
And keep in mind that when we say ``wasted resources,’’ we’re not just talking about wasted money –we’re also talking about unnecessary CO2 emissions, and, in the labor setting, unnecessarily long hours for workers.

# Why we (only sometimes) wait
Alright, so then why doesn’t everyone implement the most-extreme version of dynamic scaling they can imagine, always keeping their system an inch away from being understaffed?
Well, the answer is simple: *nobody likes waiting,* and if your customers have to wait for too long, then they’ll take their business elsewhere.
If you want to keep your customers while also conserving resources, you’ve got to balance *waiting* with *wasting* when you design your system.
In the best case scenario, you find a design sitting in that optimal sweet spot, where your system uses just enough resources to be sure that your customers don’t spend too long waiting.
Unfortunately, we’re not even close to being able to find that sweet spot, since we haven’t been able to answer one of the most basic questions in this space: **“How does the average waiting time behave in systems with setup times?”**

# Why the problem is so much worse than we thought
At this point you might be wondering whether setup times actually hurt performance that much.
The short answer is: yes, they do.
The long answer is: yes, they do, and the situation is *so much worse* than we initially thought.
When setup times are small compared to service times, setup times have a small effect o
But in real systems, where setup times can be *thousands* of times larger than service times, the effect of setup times can be gigantic.
In fact, we’ve known the setup effect can be significant for a long time.
But it’s only very recently that we’ve uncovered how bad the problem actually is, since up to now we’ve all been studying the wrong model.
To explain why the entire field has been studying setup in the wrong way, first let’s go into a little bit more detail about what makes setup systems hard to understand.

# What makes setup hard?

## First reason: The setup effect can be *invisible.*
There are two reasons why setup is so hard to understand.
First, the harm caused by setup times can be invisible.
For example, if I’m the first person in line when the pharmacist starts badging in, then I can directly see the reason why I’m waiting; I can observe the setup process.
But, while I’m waiting in line, other people will get in line behind me, and when I finally do receive service, the line might be pretty long.
At that point, everyone in the line knows exactly why we have been waiting for so long: setup times.
But if another customer arrives after the pharmacist has badged, then they’ll have no idea why the line is so long; the harm caused by setup times has become invisible.

## Second reason: Servers can *interact.*
The second hard-to-understand aspect of setup times only emerges when there are multiple servers in play.
Setup gets more complicated in multiserver systems because now their server states can interact.
For example, suppose there are two pharmacists on hand, but only one is currently badged in and serving customers –the other pharmacist is in the back filling prescriptions.
If the line gets too long, the pharmacist in the back might think they need to start serving customers, and thus begin the long drawn-out badge-in process.
If, however, the already-serving front pharmacist somehow quickly works through the line, then it might not even make sense for the not-yet-serving back pharmacist to complete the badge-in process; it might make sense for them to cancel their setup.
Note that something like this would never happen if there was only one pharmacist, since, if there’s only one pharmacist and they’re currently badging in, there’s no way for the line to disappear.
More generally, if we scale up when the line is long and scale down when the line is short, then the setup behavior of our servers becomes governed by how quickly the already-on servers are working.
This interaction between servers makes the behavior of multiserver setup way, way more complex, since, if you cancel setup sometimes, then you now need to start tracking how far every server has gotten in the setup process.

# Where we went wrong before
The main issue with all the previous research on setup lies in how they dealt with this "interaction" complication.
For context, when studying complicated systems, reality is often way too hard to understand directly.
In order to make progress, researchers need to make simplifying assumptions about various aspects of their system.
Done correctly, these simplifying assumptions can allow us to discard the unnecessary details of a system and draw meaningful conclusions about the parts that actually matter.
That said, if these simplifying assumptions are too unrealistic, then, even if we can study that simplified model, the conclusions we obtain could end up meaningless. 

## First issue: An unrealistic, but tractable model.
Before our work, every studied model of multiserver setup made an extremely unrealistic simplification.
I mean ``extremely unrealistic’’ in two different ways.
First, the model behavior is just weird.
Without going too much into detail, what ends up happening in their model is that the speed of setup ends up scaling with the number of servers in setup.
For example, if 100 servers are setting up, the first few servers end up setting up ~100 times faster.
In real systems, this couldn’t be further from what actually happens: when you turn on a computer, it goes through a series of steps which takes almost the same amount of time, every time. 
That said, plenty of useful models contain strange or unrealistic edge cases in their behavior; that, in and of itself, is not enough to prevent a model from being useful.


## Second issue: Unrealistic behavior => Poor predictions
However, whereas the unrealistic behavior of their model might be forgivable, the second problem of prior work practically dooms it: previous models *vastly* underestimate the harm caused by setup times.
In our experiments, we’ve found that, compared to what actually happens, the average waiting time of a customer can be orders of magnitude larger than what previous models predict.
Although the predictions of our model and the previous model are somewhat close when studying small systems, the gap between these predictions rapidly widens as we increase the system scale.
This gigantic prediction error makes previous research essentially impossible to use in any practical setting.


# How our results change the game
To recap, our results change the game in three major ways: Compared to previous work, we 1) study a much more realistic model, 2) prove much stronger theoretical results, and 3) greatly improve the practical application of work.
Let’s describe each point in a little more detail.

# Our model is more realistic.
First, let’s talk about how the setup process in our model is more realistic than in previous models.
As we noted before, there’s a big difference in performance between systems with and without setup times.
But previous models make an unrealistic assumption about setup times, an assumption which leads them to dramatically underestimate the harm caused by setup times.
In particular, their assumption makes it so that, when more servers set up, the setup process happens faster.
In contrast, in our model, setup times take the same amount of time, every time.
If booting up a server takes a minute, then booting up 100 servers also takes a minute. 
In other words, we study setup times as they actually occur in real systems.

# Our results are stronger.
Second, let’s discuss how our main results are stronger than all previous results.
First theoretical analysis of realistic model
First closed-form analysis for any finite server model
In particular, under mild assumptions, give closed-form upper and lower bounds which we prove are within a constant factor of the true value.
Our two main results investigate the average waiting time in our new, more realistic model.
In particular, we give both an upper bound and a lower bound on the average wait in our model, and also show that these upper and lower bounds differ by at most a multiplicative factor.
Moreover, our bounds are just an explicit closed-form formula; no additional computation is needed (though the bounds are somewhat hard-to-parse to the untrained eye, and so are omitted from this particular blogpost).
While our results are more meaningful due to our more realistic model, these are also the first closed-form results ever for any finite-server system with setup times.


# Our results are more practically useful.
-  Our results more prac useful
   - Prev, two issues: opaque (so no intution), expensive, inaccurate.


The strength of our results directly lead into our third contribution: a simple and extremely accurate predictor of the average waiting time.

For context, previously, a prospective system designer had two options for predicting the average waiting time in their system: either they ran long, slowly-converging simulations, or they needed to solve a complicated system of polynomial equations.
Both options come with the same pair of issues:
By contrast, 