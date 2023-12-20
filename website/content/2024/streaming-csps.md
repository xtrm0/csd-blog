+++
# The title of your blogpost. No sub-titles are allowed, nor are line-breaks.
title = "Streaming algorithms for Maximum Directed Cut"
# Date must be written in YYYY-MM-DD format. This should be updated right before the final PR is made.
date = 2023-12-20

[taxonomies]
# Keep any areas that apply, removing ones that don't. Do not add new areas!
areas = ["Theory"]
# Tags can be set to a collection of a few keywords specific to your blogpost.
# Consider these similar to keywords specified for a research paper.
tags = ["streaming-algorithms", "local-algorithms", "constraint-satisfaction-problems"]

[extra]
# For the author field, you can decide to not have a url.
# If so, simply replace the set of author fields with the name string.
# For example:
#   author = "Harry Bovik"
# However, adding a URL is strongly preferred
author = {name = "Noah G. Singer", url = "https://noahsinger.org" }
# The committee specification is simply a list of strings.
# However, you can also make an object with fields like in the author.
committee = [
    {name = "David P. Woodruff", url = "http://www.cs.cmu.edu/~dwoodruf/"},
    {name = "Magdalene Dobson", url = "https://magdalendobson.github.io"}
]
+++

Target audience: The post should be written at a level so that any interested advanced computer science student finding the blog can get something useful out of it. A good yardstick might be your fellow CSD doctoral students who are not necessarily in your own research area.
Suggested length: Around 2500 words (it can be shorter; the length should really just be whatever is necessary to get the main ideas across in a concise, clear, and understandable way). The post should not be longer than 5000 words.
Content: The blog post must present a self-contained, cogent, and en- gaging narrative on some recent research, including a blend of scientific (high-level) and technical exposition.

# Outline (TEMPORARY)

* We're doing streaming algorithms for constraint satisfaction problems
* Introduction to streaming algorithms
   * Requests "streaming" in online - typically these are "updates" to some underlying objects. This object is too big to describe completely but we are just interested in computing some queries of it.
   * There are various differences in terms of what kind of "API" we want to support, e.g., queries at all points
   * The exact models can differ --- e.g. adding info or also deleting? When describing graph, adding vtcs or adding edges?
   * Famous streaming algorithms: (Take a look at David's course notes)
   * Space usage is the resource ("information theoretic" since we just care about whether small space can store enough info to answer a problem)
* Introduction to constraint satisfaction problems
   * These are a broad and heavily studied class of problems
   * Typically, $n$ variables, each is assigned to an element of some *alphabet* \\(\Sigma\\)
   * Local constraints, kind of "requests" like "I will be happy if $(x_1,...,x_2)$ have any of the following values"
      * For instance, "Max-CUT": Alphabet is binary, i.e., \\(0,1\\), and each constraint is of the form "I will be happy if \\(x_{i_1} \neq x_{i_2}\\)"
   * Includes e.g. 3SAT which everyone studies in their intro theory class
      * "I will be happy if \\(x_3 \vee \wedge x_6 \vee \wedge x_8\\)".
   * We're interested in maximization problems: General goal is to satisfy as many constraints as possible
   * Distinguishing problems. (Related to approximation problems.)
* Our specific setup
   * We're interested in a specific type of problem, namely, \\(Max-2AND\\), where 
   * Sparsification: Typically assume linear constraints. (Formally, )
* An \\(O(\log n)\\)-space algorithm (from CGV20 but from my joint work BHPSV)
* Our contribution: better algorithms in slightly relaxed models
   * Notion of "template"
   * How to estimate template in different models?
      * Random ordering
      * Two passes
      * Sublinear space (the tricky one)
* Lots of interesting open questions
   * Lower bounds for space?
   * Better approximations?
   * Extending to other CSPs?

# Finale {#finale}

