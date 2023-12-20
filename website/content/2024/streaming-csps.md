+++
# The title of your blogpost. No sub-titles are allowed, nor are line-breaks.
title = "Streaming algorithms for Maximum Directed Cut"
# Date must be written in YYYY-MM-DD format. This should be updated right before the final PR is made.
date = 2023-12-20

[taxonomies]
areas = ["Theory"]
tags = ["streaming-algorithms", "local-algorithms", "constraint-satisfaction-problems"]

[extra]
author = {name = "Noah G. Singer", url = "https://noahsinger.org" }
committee = [
    {name = "David P. Woodruff", url = "http://www.cs.cmu.edu/~dwoodruf/"},
    {name = "Magdalene Dobson", url = "https://magdalendobson.github.io"}
]
+++

# Introduction

* We're doing streaming algorithms for constraint satisfaction problems

## Streaming algorithms

Motivated by applications to "big data", in the last two decades, models of computing on massive inputs have been widely studied in the theory community. In these models, the algorithm is given *limited*, *partial* access to some input object, and is required to produce an output fulfilling some guarantee related to that object. Some general models include:
* *Property testing*, where an algorithm must decide whether a large object either has a property \\(P\\) or "really doesn't have \\(P\\)"[^ppty-tst] while making few queries to an object; depending on the specific scenario, the algorithm may be able to decide these queries adaptively, or, even more restrictively, they might just be randomly and independently sampled according to some distribution.
* *Online algorithms*, where an algorithm is forced to make progressive decisions about an object while it is revealed piece by piece.
* *Streaming algorithms*, where an algorithm is allowed to make a decision after seeing revealed progressively in a "stream", but the amount of information which can be stored in memory is limited.

This blog post is primarily concerned with streaming algorithms. In this setting, *space* is the most important limited resource: Sometimes, we can even design algorithms which pass over a data stream of length \\(n\\) but maintain an internal state using only \\(O(\log n)\\) bits of memory! Another exciting aspect of the streaming model of computation is that space restrictions can be studied mathematically, often from the standpoint of information theory, meaning that one can actually prove impossibility results.[^contrast]

### Norm estimation

Some seminal early works on streaming algorithms studied a problem called "norm estimation". I'm going to dive into this problem a little bit, because one of the algorithms I'll describe later will use norm estimation as a subroutine.

Imagine a sequence of \\(m+1\\) vectors, each of which has \\(n\\) integer-valued coordinates, denoted \\(\mathbf{v}^{(0)}, \ldots, \mathbf{v}^{(m)}\\). The starting vector \\(\mathbf{v}^{(0)} = (0,\ldots,0)\\) is the vector whose entries are all \\(0\\), and the final vector is \\(\mathbf{v}^{(m)} = \mathbf{v}\\) for short. Each successive vector \\(\mathbf{v}^{(t)}\\) is obtained from the previous vector \\(\mathbf{v}^{(t-1)}\\) by adding \\(\delta_t \in \\{\pm 1\\}\\) to the \\(i_t\\)-th coordinate. Letting \\(\mathbf{v} := \mathbf{v^{(m)}}\\) denote the final vector, the goal is to estimate \\(\mathbf{v}\\)'s \\(p\\)-norm

\\[\\|\mathbf{v}\\|_p := \left(\sum\_{i=1}^n |v\_i|^p \right)^{1/p}. \\]

We can view this as a "streaming" problem of "dynamic" updates to a vector \\(\mathbf{v}\\) which starts as \\(\mathbf{v}^{(0)}\\): The stream consists of updates \\((i_t, \delta_t)\\) for \\(t = 1,\ldots, n\\) to \\(\mathbf{v}\\) (each of which means "add \\(\delta_t\\) to coordinate \\(i_t\\)"). The goal is to estimate the norm \\(\\|\mathbf{v}\\|_p\\), but we don't have enough memory space to store more than a few updates and a few coordinates of \\(\mathbf{v}\\) at a time. (Note that in general, the change in the norm caused by updating a coordinate of the vector depends on the current value of that coordinate.)

The seminal work of Alon, Matias, and Szegedy in 1996 introduced this problem and showed how to estimate the \\(2\\)-norm using \\(O(\log n)\\) space. In 2000, Indyk gave a general scheme for the \\(p\\)-norm for (\\(0 < p \leq 2\\)), also using \\(O(\log n)\\) space.

## Constraint satisfaction problems

* These are a broad and heavily studied class of problems
* Typically, $n$ variables, each is assigned to an element of some *alphabet* \\(\Sigma\\)
* Local constraints, kind of "requests" like "I will be happy if $(x_1,...,x_2)$ have any of the following values"
   * For instance, "Max-CUT": Alphabet is binary, i.e., \\(0,1\\), and each constraint is of the form "I will be happy if \\(x_{i_1} \neq x_{i_2}\\)"
* Includes e.g. 3SAT which everyone studies in their intro theory class
   * "I will be happy if \\(x_3 \vee \wedge x_6 \vee \wedge x_8\\)".
* We're interested in maximization problems: General goal is to satisfy as many constraints as possible
* Distinguishing problems. (Related to approximation problems.)

# Problem setup: Max-\\(2\\)AND and Max-DICUT

* We're interested in a specific type of problem, namely, \\(Max-2AND\\), where 
* Sparsification: Typically assume linear constraints. (Formally, )

# Smaller space alg

* An \\(O(\log n)\\)-space algorithm (from CGV20 but from my joint work BHPSV)

# Better alg

* Our contribution: better algorithms in slightly relaxed models
   * Notion of "template"
   * How to estimate template in different models?
      * Random ordering
      * Two passes
      * Sublinear space (the tricky one)

# Finale {#finale}

* Lots of interesting open questions
   * Lower bounds for space?
   * Better approximations?
   * Extending to other CSPs?

[^ppty-tst]: More precisely, this typically means that the object is "far from" the set of objects having \\(P\\) in some mathematical sense. For instance, if the objects are graphs and the property \\(P\\) is a graph property like bipartitness, "really not having \\(P\\)" might mean that many edges in the graph must be added or deleted in order to get \\(P\\) to hold.
[^contrast]: This is in contrast to more traditional areas of theory, such as time complexity, where many impossibility results are "conditional" on conjectures like \\(\mathbf{P} \neq \mathbf{NP}\\).