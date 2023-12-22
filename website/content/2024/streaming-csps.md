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

* In **Max-CUT**, the alphabet is Boolean (\\(\Sigma = \\{0,1\\}\\)), and all constraints are binary and use the same predicate: \\(f(x,y) = x \oplus y\\) (where \\(\oplus\\) denotes the Boolean XOR operation). I.e., if we apply a constraint to the variables \\(i_1,i_2\\), then the corresponding constraint is satisfied iff \\(x(i_1) \neq x(i_2)\\). **Max-\\(q\\)Coloring** is similar, over a larger alphabet (of size \\(q\\)), with the predicate \\(f(x,y)=1 \iff x \neq y\\). (Note that **Max-CUT** is more traditionally viewed as a problem whose input is a *graph*, not a list of constraints. These views are equivalent, as we will explain in the next section.)
* In **Max-3SAT**, the alphabet is also Boolean, all constraints are ternary, and use assorted predicates such as \\(f(x,y,z) = x \vee \neg y \vee z\\) or \\(f(x,y,z) = \neg x \vee \neg y \vee \neg z\\).)

In both cases, we can "build up" instances on arbitrarily many variables by applying to predicates to "local" sets of \\(2\\) or \\(3\\) variables at a time.

**Technical note:** For various reasons, we are interested in studying the feasibility of *approximating* the values of CSPs (and not *exactly* determining this value). The reasons include that exact computation is very hard in the streaming setting, and hardest for dense graphs like many other streaming problems, whereas approximation versions are hardest for sparse graphs; and that the approximability of CSPs by "classical" (i.e., polynomial-time) algorithms is a subject of intense interest, stemming from connections to probabilistically checkable proofs and semidefinite programming.

# Streaming algorithms meet CSPs: **Max-CUT** and **Max-DICUT**

Constraint satisfaction problems consist of many small, local constraints acting on a global assignments. Thus, it is natural to ask whether streaming algorithms can take advantage of (a stream of) this "local" information to deduce something about the quality of the best global assignment. In other words,

> When can an algorithm approximate the value of (the best global assignment to) a CSP given a small-space streaming pass over its list of local constraints?

&nbsp;

This question was first posed at the 2011 Bertinoro workshop on sublinear algorithms (see [the `sublinear.info` wiki](https://sublinear.info/index.php?title=Open_Problems:45)). In this section, we examine this question through the lens of two of the simplest and most widely studied classes of Boolean, binary CSPs:
* **Max-CUT** (a.k.a. "Maximum Cut"). As described in the previous section, the corresponding predicate is \\(f(x,y) = x \oplus y\\), so a constraint on \\(i_1,i_2)\\ is satisfied by an assignment \\(x : \\{1,\ldots,n\\} \to \\{0,1\\}\\) iff \\(x(i_1) \neq x(i_2)\\).
* **Max-DICUT** (a.k.a. "Maximum Directed Cut"). Here the predicate is \\(f(x,y) = x \wedge \neg y\\), so that a constraint \\(i_1,i_2\\) is satisfied iff \\(x(i_1) = 1 \wedge x(i_2) = 0\\).

Note that  **Max-CUT**'s predicate is symmetric under exchanging variables, while **Max-DICUT**'s predicate is not (in particular, \\((1,0)\\) satisfies it, while \\((0,1)\\) does not). 

Both these problems are essentially about *graphs* (and perhaps the graph definition of **Max-CUT** is more familiar). Given a **Max-CUT** instance on \\(n\\) variables, we can form a corresponding undirected graph on \\(n\\) vertices, and add an edge \\(i_1 \leftrightarrow i_2\\) for each constraint \\(i_1,i_2\\) in the instance (with the same weight). Now an assignment (a.k.a. "cut") assigns each vertex to either \\(0\\) or \\(1\\), and an edge is satisfied iff its endpoints are on different sides of the cut. We can interpret **Max-DICUT** similarly, except that because of the asymmetry, we have to create a *directed* graph: We add an edge \\(i_1 \to i_2\\) for each constraint \\(i_1,i_2\\), and an edge \\(i_1 \to i_2\\) is satisfied iff \\(i_1\\) is assigned to \\(1\\) and \\(i_2\\) to \\(0\\).

[MAXDICUT EXAMPLE PHOTO]

In what remains, I will have to refer to specific amounts of memory space (as a function of \\(n\\), the number of variables in the instance). To make the statements less quantitative, I will use "small", "medium", and "large" space to refer to \\(O(\log^{O(1)} n)\\), \\(O(\sqrt n \log^{O(1)} n)\\), and \\(O(n \log^{O(1)} n)\\) space, respectively.

## Results for **Max-CUT**

Several works showed that for **Max-CUT**, essentially no "nontrivial" streaming algorithms are possible. Among these works, Kapralov, Khanna, and Sudan (SODA'15) showed that algorithms using less-than-medium space cannot distinguish between instances where there exists an assignment satisfying every constraint, and instances with "no good assignments".[^value-of-kks] Later, Kapralov and Krachun, in a technical tour-de-force, extended this impossibility result to algorithms using less-than-large space. Since large-space algorithms with essentially optimal guarantees are known, these results show that there are no "interesting" streaming algorithms for **Max-CUT**.[^random-ord]

## Results for **Max-DICUT**

In contrast, a surprising result of Guruswami, Velingker, and Velusamy (APPROX'17, based out of CMU!) showed that there *are* nontrivial algorithms for **Max-DICUT**, even in small space. Chou, Golovnev, and Velusamy (FOCS'20) gave a variant of this algorithm with better approximation guarantees, which they also showed is optimal in less-than-medium space. (Specifically, Chou *et al.* showed a sharp threshold in the space needed for \\(4/9\\)-approximations. The analysis of their algorithm was subsequently simplified in a joint work of mine with Boyland, Hwang, Prasad, and Velusamy in (APPROX'21).) Whether it was possible to get even better guarantees using more space was a major open question in this work. In the next section, I present our affirmative answer to this question, but first, I will introduce a further concept we will need, which first showed up in this context in the work of Guruswami *et al.*.

### Bias of variables in **Max-DICUT**

Given an instance \\(\Psi\\) of **Max-DICUT**, and a variable \\(i\\), let \\(\deg_{out}(i)\\) denote the total weight of edges \\(i_1 \to i_2\\) in which \\(i=i_1\\), \\(\deg_{in}(i)\\) the total weight of constraints \\(i_1 \to i_2\\) in which \\(i=i_2\\), and \\(\deg(i) = \deg_{out}(i) + \deg_{in}(i)\\) the total weight of constraints \\(i_1,i_2\\) in which \\(i \in \\{i_1,i_2\\}\\). (These correspond to, respectively, the out-degree, in-degree, and total-degree of \\(i\\).) If \\(\deg(i) > 0\\), then we define a scalar quantity called the *bias* of \\(i\\):
\\[ \mathrm{bias}(i) := \frac{\deg_{out}(i) + \deg_{in}(i)}{\deg(i)}. \\] Note that \\(-1 \leq \mathrm{bias}(i) \leq +1\\); indeed, \\(\mathrm{bias}(i)\\) captures whether the edges incident to \\(i\\) are mostly outgoing (\\(\mathrm{bias}(i) \approx +1\\)), mostly mostly incoming (\\(\mathrm{bias}(i) \approx -1\\)), or mixed (\\(\mathrm{bias}(i) \approx 0\\)).

This concept of bias, which relies crucially on the asymmetry of the predicate (and therefore has no analogue for **Max-CUT**), is the key to unlocking nontrivial streaming approximation algorithms for **Max-DICUT**. Observe that if e.g. \\(\mathrm{bias}(i) = -1\\), then *all* edges incident to \\(i\\) are incoming, and therefore, the optimal assignment for \\(\Psi\\) should assign \\(i\\) to \\(0\\).[^opt-asst] Indeed, the instance is perfectly satisfiable iff all variables have bias either \\(+1\\) or \\(-1\\). What Guruswami *et al.* showed, later strengthened by Chou *et al.*, is that (1) this relationship is "robust", in that instances with "many large-bias variables" have large value and vice versa, and (2) whether an instance has "many large-bias variables" can be quantified using small-space streaming algorithms.

**Remark:** While we will not require this below, we mention that the notion of "many large-bias variables" is formalized by a quantity called the *total bias* of \\(\Psi\\), which is simply the average over \\(i\\) (weighted by \\(\deg(i)\\)) of \\(|\mathrm{bias}(i)|\\). Indeed, by the definition of bias, the total bias is (proportional to) \\(\sum_{i=1}^n |\deg_{out}(i)-\deg_{in}(i)|)\\), which is simply the \\(1\\)-norm of the "signed degree vector" of \\(\Psi\\)! So the **Max-DICUT** algorithms of Guruswami *et al.* and Chou *et al.* use the small-space \\(1\\)-norm sketching algorithm of Indyk as their key subroutine.

# Improved algorithms from snapshot

Finally, we turn to the improved streaming algorithms for **Max-DICUT** from our recent papers in (SODA'23, FOCS'23).

## The snapshot

First, we need to define a matrix, which we call the *snapshot matrix*, for any instance \\(\Psi\\). This matrix has the property that a certain linear combination of its entries gives a good approximation to the value of \\(\Psi\\) (a better approximation than is possible with a less-than-medium space streaming algorithm). The upshot is that it suffices to design streaming algorithms to estimate this snapshot.

The snapshot matrix is simply the following. Recall that the interval \\([-1,+1]\\) is the space of possible biases of a variable in a **Max-DICUT** instance. Fix a partition \\(I_1,\ldots,I_B\\) of this interval into a finite number of subintervals. Given this partition, we can partition the (positive-degree) variables in \\(\Psi\\) into "bias classes": Each vertex \\(i \in \\{1,\ldots,n\\}\\) has bias \\(\mathrm{bias}\_\Psi(i)\\) falling into a unique interval \\(I_b\\) for some \\(b \in \\{1,\ldots,B\\}\\). Edges also are partitioned into biases classes: To an edge \\(i_1 \to i_2\\) in \\(\Psi\\) we associate class \\(b_1,b_2 \in \\{1,\ldots,B\\} \times \\{1,\ldots,B\\}\\), where \\(b_1\\) and \\(b_2\\) are respectively the classes of \\(i_1\\) and \\(i_2\\). The snapshot matrix is simply the \\(B \times B\\) matrix which captures the weight of edges in each bias class: \\(\mathsf{Snap}\_\Psi \in \mathbb{R}\_{\geq 0}^{B \times B}\\) and \\(b_1,b_2\\)-th entry is the total weight of edges \\(i_1 \to i_2\\) with \\(\mathrm{bias}(i_1) \in I_{b_1}\\) and \\(\mathrm{bias}(i_2) \in I_{b_2}\\).

## Aside: Oblivious algorithms

At this point, we can "black-box" the notion of snapshot, since our algorithmic goal is now only to estimate the snapshot. However, to present a full picture of why the snapshot is important, we first take a detour into describing a simple class of "local" algorithms for **Max-DICUT**. These algorithms, called *oblivious algorithms*, were introduced by Feige and Jozeph (Algorithmica'17). Again, fix a partition of the space of possible biases \\([-1,+1]\\) into intervals \\(I_1,\ldots,I_B\\). For each interval \\(I_b\\), also fix a probability \\(p_b\\). Now an *oblivious algorithm* is one which, given an instance \\(\Psi\\), inspects each variable \\(i\\) independently and randomly sets it to \\(1\\) with probability \\(p_b\\), where \\(b\\) is the class of \\(i\\), and \\(0\\) otherwise. These algorithms are "oblivious" in the sense that they ignore everything about each variable except its bias.

As discussed in the previous section, in **Max-DICUT**, if a variable has bias \\(+1\\), we always "might as well" assign it to \\(1\\), and if it has bias \\(-1\\), we "might as well" assign it to \\(0\\). Oblivious algorithms flesh out this connection by choosing how to assign *every* variable based on its bias. For instance, if a variable has bias \\(+0.99\\), we should still want to assign it to \\(1\\) (at least with large probability).

Feige and Jozeph constructed a choice of partition \\((I_b)\\) and probabilities \\(p_b)\\) which they showed gives an approximation to the overall **Max-DICUT** value, which we realized is better than what Chou *et al.* showed was possible with a less-than-medium space streaming algorithm. (In a paper of mine at APPROX'23, I generalized this definition and the corresponding algorithmic result to **Max-\\(k\\)AND** for all \\(k \geq 2\\).) Thus, to give improved streaming algorithms it suffices to "simulate" their oblivious algorithm.

[PHOTO: The rounding function]

The key observation is then that to simulate an oblivious algorithm on an instance \\(\Psi\\), *it suffices to only know (or estimate) the snapshot of \\(\Psi\\)*. Indeed, every edge of class \\(b_1, b_2\\) is satisfied with probability \\((\pi_{b_1})(1-\pi_{b_2})\\) (the first factor is the probability that \\(i_1\\) is assigned to \\(1\\), the second the probability that \\(i_2\\) is assigned to \\(0\\), and these two events are independent). Thus, by linearity of expectation, the expected weight of the constraints satisfied by the oblivious algorithm is

\\[ \mathop{\mathbb{E}}\_{x \sim \mathcal{X}}\left[\mathsf{Obl}(\Psi) \right] = \sum_{b_1,b_2 = 1}^B (\pi_{b_1})(1-\pi_{b_2}) \cdot \mathrm{Snap}_\Psi(b_1,b_2), \\]

since an edge \\(i_1 \to i_2\\) of class \\(b_1,b_2\\) will be satisfied with probability \\((\pi_{b_1})(1-\pi_{b_2})\\)

This observation allowed Feige and Jozeph to determine the approximation ratio of any oblivious algorithm by simply minimizing the weight of constraints satisfied over all valid snapshots via an LP.[^symmetry] And the upshot of this for us is that to approximate the value of an instance \\(\Psi\\), it suffices to calculate some linear function of this snapshot matrix \\(\mathrm{Snap}_\Psi\\).

## Restricted settings: Two passes or random ordering

At this point, our goal is to use streaming algorithms to calculate, or estimate, a linear function of the entries of the snapshot \\(\Psi\\). To calculate this function up to a (normalized) \\(\pm \epsilon\\), it suffices to estimate the snapshot's entries up to a "cumulative" \\(\pm \epsilon\\) (i.e., up to \\(\epsilon\\) in the \\(1\\)-norm when the snapshot is viewed as a \\(B^2\\)-dimensional vector).

For simplicity, let's focus on the task of estimating a single entry of \\(\Psi\\)'s snapshot up to \\(\pm \epsilon\\) error --- i.e., estimating the fraction of edges in \\(\Psi\\) with some fixed bias class \\(b_1,b_2\\). To do this, we could ideally sample a random set \\(\tilde{E}\\) of \\(T = O(1)\\) edges in \\(\Psi\\), measure the biases of their endpoints, and then use the fraction of edges in the sample with bias class \\(b_1,b_2\\) as an estimate for the total fraction of edges with this bias class.

This sampling task is easier if we make slight tweaks to the streaming model we've been using. Firstly, suppose we were guaranteed that the edges showed up in the stream in a *uniformly random order*. Then since the first \\(T\\) edges in the stream are a random sample of \\(\Psi\\)'s edges, we could simply use these edges for our set \\(\tilde{E}\\), and then record the biases of their endpoints over the remainder of the stream. Alternatively, suppose we were allowed *two passes* over the stream of edges. We could then use the first pass to sample \\(T\\) random edges \\(\tilde{E}\\), and use the second pass to measure the biases of their endpoints. Both of these algorithms use small space, since we are only sampling a constant number of edges.

However, in the "plain" streaming model we originally presented, it is not clear how to use a streaming algorithm to randomly sample a set of edges and measure the biases of their endpoints simultaneously. Indeed, this should not be a surprise, since we know via Chou *et al.*'s lower bound that medium space is necessary for improved **Max-DICUT** approximations, and therefore for snapshot estimation! In the remainder of this blog post, we sketch how we are able to estimate the snapshot using medium space.

## Sublinear space and "smoothing" the snapshot

Our algorithm for the "plain" model is quite technical to describe in full detail, so in this section, we endeavor to present some of the key challenges and strategies. Again, the key goal is to estimate the snapshot in medium space.

First, suppose we were promised that in \\(\Psi\\), every vertex has degree at most \\(D\\), and \\(D = O(1)\\). A natural approach would be the following:
1. *Before the stream*, sample a (large enough) set \\(\tilde{S} \subseteq \\{1,\ldots,n\\}\\) of random vertices.
2. *During the stream*, (i) store all edges whose endpoints are both in \\(\tilde{S}\\), and (ii) measure the biases of each vertex in \\(\tilde{S}\\).

Now when the stream ends, if we take \\(\tilde{E}\\) to be the set of edges whose endpoints are both in \\(\tilde{S}\\), we do know the biases of the endpoints of all edges in \\(\tilde{E}\\). Our hope is that we can also use \\(\tilde{E}\\) as a "uniform-ish" sample of edges in order to estimate the number of edges in some class \\(b_1,b_2\\). Observe that the expected number of edges in \\(\tilde{E}\\) is roughly \\(m (|\tilde{S}|/n)^2\\) where \\(m\\) is the number of edges in \\(\Psi\\). If \\(m = O(n)\\) (which we can assume WLOG by a sparsification argument), \\(|\tilde{E}| = \Omega(1)\\) (in expectation) as long as \\(\tilde{S} = \Omega(\sqrt n)\\), which is precisely why this algorithm "kicks in" once we have medium space! Once \\(\tilde{S}\\) is this large, we can indeed show that \\(\tilde{E}\\) suffices to estimate the snapshot.
 
Of course, in the general situation, \\(\Psi\\) need not have bounded maximum degree. This is actually a serious challenge for our approach. Consider the case where \\(\Psi\\) is a "star", where each edge connects a designated center vertex \\(i^\*\\) to one of the remaining vertices. In this situation, not every vertex is created equal. Indeed, if \\(i^* \not\in \tilde{S}\\) (which happens asymptotically almost surely), \\(\tilde{E}\\) will be empty, and therefore we learn nothing about \\(\Psi\\)'s snapshot.

This issue means that we have to treat vertices with different degrees differently. In other words, we'll need to put every vertex with degree \\(\Omega(n)\\) (a.k.a. "centers of stars") in \\(\tilde{S}\\) --- this is OK since there are at most \\(O(1)\\) of these vertices --- but we can only afford to store a medium number (i.e., \\(O(\sqrt n)\\)) of vertices with degree \\(O(1)\\) in order to fit within the space bound.

To implement this, our algorithm aims to estimate a *more detailed* object than the snapshot itself, which we call the *refined snapshot* of \\(\Psi\\). To define this object, we also need to establish a partition into intervals \\(J_1,\ldots,J_D\\) of the space \\([0,O(n)]\\) of possible degrees. This lets us define a unique *degree class* in \\(\\{1,\ldots,D\\}\\) for every vertex, and a corresponding degree class in \\(\\{1,\ldots,D\\}^2\\) for every edge. Now the refined snapshot is a four-dimensional array \\(\mathrm{RefSnap}\_\Psi \in \mathbb{R}^{D^2 \times B^2}\\), whose \\(d_1,d_2,b_1,b_2)\\)-th entry is the number of edges in \\(\Psi\\) with degree class \\(d_1,d_2\\) and bias class \\(b_1,b_2\\).

Now, how do we estimate entries of this refined snapshot, i.e., estimate the number of edges in \\(\Psi\\) with degree class \\(d_1,d_2\\) and bias class \\(b_1,b_2\\)? We adopt a similar approach to the above: We first seek to just sample sets of vertices in classes \\(d_1\\) and \\(d_2\\), and then we measure biases and store edges between these sets. But when a vertex first appears in the stream, we do not know its degree --- so how do we know whether we might want to place it in the sampled set? We accomplish this by deferring the decision about whether to place it in the sampled set later in the stream. In particular, though we cannot afford to explicitly store the degree of each vertex, we can do so "implicitly" by randomly subsampling the *edges* in the graph, and then using positive-degree vertices in the subsampled graph as "proxies" for high-degree vertices in \\(\Psi\\).

However, this in turn introduces a new complication. At the point where we decide that some vertex \\(i\\) has high degree (because it is incident to one of the subsampled edges) and further decide to place it into \\(\tilde{S}\\), many incident edges to \\(i\\) may have already passed by. Thus, we might not know \\(i\\)'s bias exactly. We can use its bias over the remainder of the stream as an estimate. Unfortunately, this implies that our notion of snapshot is too demanding, because if a vertex's bias is even slightly incorrect, we may err in determining its bias class --- that is, we can shift it into an adjacent bias class, if its bias was close to the borderline between the classes to begin with. To deal with this, we pivot to trying to estimate a "smoothed" version of the snapshot, where the entries "overlap", in that each entry captures edges whose bias and degree classes fall into certain "windows". More precisely, for some window-size parameter \\(w\\), the \\(i_1,i_2,b_1,b_2\\)-th entry captures the number of edges whose degree class is in \\(\\{i_1-w,\ldots,i_1+w\\} \times \\{i_2-w,\ldots,i_2+w\\}\\) and bias class class is in \\(\\{b_1-w,\ldots,b_1+w\\} \times \\{b_2-w,\ldots,b_2+w\\}\\). Each particular vertex will fall into many (\\(\sim w^4\\)) of these windows, meaning that any errors from mistakenly shifting a vertex into an adjacent bias class are "averaged out" for sufficiently large \\(w\\). Finally, we show that estimating the "smoothed" snapshot is still sufficient to estimate the **Max-DICUT** value using a continuity argument, essentially because slightly perturbing vertices' biases cannot modify the **Max-DICUT** value too much.

# Finale {#finale}

There are several interesting open questions remaining from the above works. Firstly, it would be interesting to extend the results presented above to other CSPs besides **Max-DICUT**. For instance, we know of analogues for oblivious algorithms for **Max-\\(k\\)AND** for all \\(k \geq 2\\), but whether there are snapshot estimation algorithms which "implement" these oblivious algorithms in less-than-large space is an open question. Also, there is a yawning gap between medium and large space. Proving any approximation *impossibility* result, or constructing better approximation algorithms, in the between-medium-and-large space regime. We mention that the snapshot-based approach cannot give optimal approximations (i.e., with ratios approaching \\(1/2\\), where less-than-large space impossibility results are known) because of hard instances with matching snapshots and **Max-DICUT** value gaps discovered by Feige and Jozeph.

[^ppty-tst]: More precisely, this typically means that the object is "far from" the set of objects having \\(P\\) in some mathematical sense. For instance, if the objects are graphs and the property \\(P\\) is a graph property like bipartitness, "really not having \\(P\\)" might mean that many edges in the graph must be added or deleted in order to get \\(P\\) to hold.
[^contrast]: This is in contrast to more traditional areas of theory, such as time complexity, where many impossibility results are "conditional" on conjectures like \\(\mathbf{P} \neq \mathbf{NP}\\).
[^factor]: More precisely, for all \\(\epsilon>0\\) these algorithms output some value \\(\hat{v}\\) satisfying \\(\hat{v} \in (1\pm\epsilon) \\|\mathbf{v}\\|_p\\) with high probability, and use \\(O(\log n/\epsilon^{O(1)})\\) space.
[^max]: It is also interesting to study *minimization* versions of CSPs (i.e., trying to minimize the number of *unsatisfied* constraints), but that is out of scope for this post.
[^graph-view]: By this, I just mean to form an undirected graph on \\(n\\) vertices from the **Max-CUT** instance by putting edges between each pair of vertices with weight equal to the weight on the corresponding **Max-CUT** constraint (zero if there is no constraint).
[^rand-ord]: The result of Kapralov, Khanna, and Sudan did hold in randomly-ordered streams, while we do not yet have an impossibility result for sublinear-space algorithms in randomly-ordered streams. Also, we do not yet have strong impossibility results for algorithms which take *multiple* passes over the input list.
[^value-of-kks]: By the latter, we mean instances of value \\(\leq 1/2+\epsilon\\) for all \\(\epsilon > 0\\); specifically, these are just uniformly random instances with linearly many constraints.
[^opt-asst]: More precisely, there exists an optimal assignment with this property.
[^symmetry]: This is an oversimplification: The goal is to minimize the *approximation ratio* (i.e., the value of the oblivious assignment over the value of the optimal assignment). However, Feige and Jozeph observe that under a symmetry assumption for \\(\pi\\), it suffices to only minimize over instances where (i) the (unnormalized) value of the instance is \\(1\\) and (ii) the all-\\(1\\)'s assignment is optimal. Given (i), the algorithm's ratio on an instance is simply the (unnormalized) expected value of the assignment produced by the oblivious algorithm, and (i) and (ii) together can be implemented as an additional linear constraint in the LP.