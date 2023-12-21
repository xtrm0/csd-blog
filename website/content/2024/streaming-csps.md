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

In contrast, a surprising result of Guruswami, Velingker, and Velusamy (APPROX'17, based out of CMU!) showed that there *are* nontrivial algorithms for **Max-DICUT**, even in small space. Chou, Golovnev, and Velusamy (FOCS'20) gave a variant of this algorithm with better approximation guarantees, which they also showed is optimal in less-than-medium space. (The analysis was subsequently simplified in a joint work of mine with Boyland, Hwang, Prasad, and Velusamy in (APPROX'21).) Whether it was possible to get even better guarantees using more space was a major open question in this work. In the next section, I present our affirmative answer to this question, but first, I will introduce a further concept we will need, which first showed up in this context in the work of Guruswami *et al.*.

### Bias of variables in **Max-DICUT**

Given an instance \\(\Psi\\) of **Max-DICUT**, and a variable \\(i\\), let \\(\deg_{out}(i)\\) denote the total weight of edges \\(i_1 \to i_2\\) in which \\(i=i_1\\), \\(\deg_{in}(i)\\) the total weight of constraints \\(i_1 \to i_2\\) in which \\(i=i_2\\), and \\(\deg(i) = \deg_{out}(i) + \deg_{in}(i)\\) the total weight of constraints \\(i_1,i_2\\) in which \\(i \in \\{i_1,i_2\\}\\). (These correspond to, respectively, the out-degree, in-degree, and total-degree of \\(i\\).) If \\(\deg(i) > 0\\), then we define a scalar quantity called the *bias* of \\(i\\):
\\[ \mathrm{bias}(i) := \frac{\deg_{out}(i) + \deg_{in}(i)}{\deg(i)}. \\] Note that \\(-1 \leq \mathrm{bias}(i) \leq +1\\); indeed, \\(\mathrm{bias}(i)\\) captures whether the edges incident to \\(i\\) are mostly outgoing (\\(\mathrm{bias}(i) \approx +1\\)), mostly mostly incoming (\\(\mathrm{bias}(i) \approx -1\\)), or mixed (\\(\mathrm{bias}(i) \approx 0\\)).

This concept of bias, which relies crucially on the asymmetry of the predicate (and therefore has no analogue for **Max-CUT**), is the key to unlocking nontrivial streaming approximation algorithms for **Max-DICUT**. Observe that if e.g. \\(\mathrm{bias}(i) = -1\\), then *all* edges incident to \\(i\\) are incoming, and therefore, the optimal assignment for \\(\Psi\\) should assign \\(i\\) to \\(0\\).[^opt-asst] Indeed, the instance is perfectly satisfiable iff all variables have bias either \\(+1\\) or \\(-1\\). What Guruswami *et al.* showed, later strengthened by Chou *et al.*, is that (1) this relationship is "robust", in that instances with "many large-bias variables" have large value and vice versa, and (2) whether an instance has "many large-bias variables" can be quantified using small-space streaming algorithms.

**Remark:** While we will not require this below, we mention that the notion of "many large-bias variables" is formalized by a quantity called the *total bias* of \\(\Psi\\), which is simply the average over \\(i\\) (weighted by \\(\deg(i)\\)) of \\(|\mathrm{bias}(i)|\\). Indeed, by the definition of bias, the total bias is (proportional to) \\(\sum_{i=1}^n |\deg_{out}(i)-\deg_{in}(i)|)\\), which is simply the \\(1\\)-norm of the "signed degree vector" of \\(\Psi\\)! So the **Max-DICUT** algorithms of Guruswami *et al.* and Chou *et al.* use the small-space \\(1\\)-norm sketching algorithm of Indyk as their key subroutine.

# Better alg

* Oblivious algorithms
* "First-order snapshot"
* How to estimate the template in different models?

## Two passes

## Random ordering

## Sublinear space

[SPACE TRADEOFFS PICTURE]

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
[^rand-ord]: The result of Kapralov, Khanna, and Sudan did hold in randomly-ordered streams, while we do not yet have an impossibility result for sublinear-space algorithms in randomly-ordered streams. Also, we do not yet have strong impossibility results for algorithms which take *multiple* passes over the input list.
[^value-of-kks]: By the latter, we mean instances of value \\(\leq 1/2+\epsilon\\) for all \\(\epsilon > 0\\); specifically, these are just uniformly random instances with linearly many constraints.
[^opt-asst]: More precisely, there exists an optimal assignment with this property.