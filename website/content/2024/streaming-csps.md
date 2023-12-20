+++
# The title of your blogpost. No sub-titles are allowed, nor are line-breaks.
title = "Better streaming algorithms for Maximum Directed Cut via 'snapshots'"
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

In this blog post, I'll discuss some new algorithms from two joint papers of mine with Raghuvansh Saxena, Madhu Sudan, and Santhoshini Velusamy (appearing in SODA'23 and FOCS'23). To use some jargon, these algorithms "approximate" a problem called "maximum directed cut", or **Max-DICUT** for short, in some versions of the "streaming setting", and they are based on estimating a new directed graph parameter which we call the "first-order snapshot".

# Introduction

To start, we will define the particular algorithmic model (streaming algorithms) and computational problem (Max-DICUT) which we are interested in.

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

The seminal work of Alon, Matias, and Szegedy in 1996 introduced this problem and showed how to estimate the \\(2\\)-norm using \\(O(\log n)\\) space. In 2000, Indyk gave a general scheme for the \\(p\\)-norm for (\\(0 < p \leq 2\\)), also using \\(O(\log n)\\) space.[^factor]

## Constraint satisfaction problems

Many "classical" computational problems can be recast into questions in the streaming model. Here, we are interested in one class of problems which has been particularly well-studied classically, namely *constraint satisfaction problems* (CSPs). These occur often in practice, not just in theory, and include many problems one might encounter in introductory algorithms courses, such as **Max-3SAT**, **Max-CUT**, and **Max-\\(q\\)Coloring**. CSPs are defined by variables and local constraints over a finite alphabet. More formally, a CSP is defined by:
* A finite set \\(\Sigma\\), called an *alphabet*; in the typical "Boolean" case, \\(\Sigma=\\{0,1\\}\\).
* A number of *variables*, \\(n\\).
* A number of local *constraints*, \\(m\\), and constraints \\(C_1,\ldots,C_m\\); each constraint \\(C_j\\) consists of a *weight* \\(w_j \geq 0\\), an *arity* \\(k_j \geq 1 \in \mathbb{N}\\), a subset \\(S_j \subseteq \{1,\ldots,n\}\\) of \\(|S_j|=k_j\\) variables, and a *predicate* (or "goal" function) \\(f_j : \Sigma^{S_j} \to \\{0,1\\}\\) for those variables.

The CSPs asks us to optimize over potential *assignments*, which are functions \\(x : \\{1,\ldots,n\\} \to \Sigma\\) mapping each variable to an element of \\(C_j\\). In particular, the objective is to maximize[^max] the number of "satisfied" (or "happy", if you'd like) constraints, where a constraint \\(C_j\\) is "satisfied" if the assigned values for \\(x\\) on its variables \\(S_j\\) satisfy its predicate \\(f_j\\). The maximum number of constraints satisfied by any assignment is called the *value* of the CSP.

Some examples of CSPs are:

* In **Max-CUT**, the alphabet is Boolean (\\(\Sigma = \\{0,1\\}\\)), and all constraints are binary and use the same predicate: \\(f(x,y) = x \oplus y\\). I.e., if we apply a constraint to the variables \\(i_1,i_2\\), then the corresponding constraint is satisfied iff \\(x(i_1) \neq x(i_2)\\) (or, in the equivalent "graph view",[^graph-view] an edge is satisfied if its two endpoints are on different sides of the cut). **Max-\\(q\\)Coloring** is the same problem, except over a larger alphabet (of size \\(q\\)).
* In **Max-3SAT**, the alphabet is also Boolean, all constraints are ternary, and use assorted predicates such as \\(f(x,y,z) = x \vee \neg y \vee z\\) or \\(f(x,y,z) = \neg x \vee \neg y \vee \neg z\\).)

In both cases, we can "build up" instances on arbitrarily many variables by applying to predicates to "local" sets of \\(2\\) or \\(3\\) variables at a time.

**Technical note:** For various reasons, we are interested in studying the feasibility of *approximating* the values of CSPs (and not *exactly* determining this value). The reasons include that exact computation is very hard in the streaming setting, and hardest for dense graphs like many other streaming problems, whereas approximation versions are hardest for sparse graphs; and that the approximability of CSPs by "classical" (i.e., polynomial-time) algorithms is a subject of intense interest, stemming from connections to probabilistically checkable proofs and semidefinite programming.

# Problem setup: **Max-DICUT**

The intersection of

> When can an algorithm approximate the value of (the best global assignment to) a CSP given a streaming pass over its list of local constraints?

The intersection of local and global knowledge

Striking hardness results for Max-CUT

But an algorithmic result for DICUT (based out of CMU!)

* Sparsification: Typically assume linear constraints. (Formally, )

* We're interested in a specific type of problem, namely, \\(Max-2AND\\), where 

* An \\(O(\log n)\\)-space algorithm (from CGV20 but from my joint work BHPSV). Equivalent to 

# Better alg

* Oblivious algorithms
* "First-order snapshot"
* How to estimate the template in different models?

## Two passes

## Random ordering

## Sublinear space

# Finale {#finale}

* Lots of interesting open questions
   * Lower bounds for space?
   * Better approximations?
   * Extending to other CSPs?

[^ppty-tst]: More precisely, this typically means that the object is "far from" the set of objects having \\(P\\) in some mathematical sense. For instance, if the objects are graphs and the property \\(P\\) is a graph property like bipartitness, "really not having \\(P\\)" might mean that many edges in the graph must be added or deleted in order to get \\(P\\) to hold.
[^contrast]: This is in contrast to more traditional areas of theory, such as time complexity, where many impossibility results are "conditional" on conjectures like \\(\mathbf{P} \neq \mathbf{NP}\\).
[^factor]: More precisely, for all \\(\epsilon>0\\) these algorithms output some value \\(\hat{v}\\) satisfying \\(\hat{v} \in (1\pm\epsilon) \\|\mathbf{v}\\|_p\\) with high probability, and use \\(O(\log n/\epsilon^{O(1)})\\) space.
[^max]: It is also interesting to study *minimization* versions of CSPs (i.e., trying to minimize the number of *unsatisfied* constraints), but that is out of scope for this post.
[^graph-view]: By this, I just mean to form an undirected graph on \\(n\\) vertices from the **Max-CUT** instance by putting edges between each pair of vertices with weight equal to the weight on the corresponding **Max-CUT** constraint (zero if there is no constraint).