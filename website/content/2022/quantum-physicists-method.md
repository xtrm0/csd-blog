+++
# The title of your blogpost. No sub-titles are allowed, nor are line-breaks.
title = "The Quantum Physicist's Method of Resource Analysis"
# Date must be written in YYYY-MM-DD format. This should be updated right before the final PR is made.
date = 2022-01-31

[taxonomies]
# Keep any areas that apply, removing ones that don't. Do not add new areas!
areas = ["Programming Languages"]
# Tags can be set to a collection of a few keywords specific to your blogpost.
# Consider these similar to keywords specified for a research paper.
tags = ["quantum-physicists-method", "physicists-method", "resource-analysis", 
"amortized", "AARA", "resource-tunneling", "worldviews", "program-analysis"]

[extra]
# For the author field, you can decide to not have a url.
# If so, simply replace the set of author fields with the name string.
# For example:
#   author = "Harry Bovik"
# However, adding a URL is strongly preferred
author = {name = "David M Kahn", url = "https://www.cs.cmu.edu/~davidkah/" }
# The committee specification is simply a list of strings.
# However, you can also make an object with fields like in the author.
committee = [
    "Committee Member 1's Full Name",
    "Committee Member 2's Full Name",
    {name = "Harry Q. Bovik", url = "http://www.cs.cmu.edu/~bovik/"},
]
+++

The physicist's method is a powerful framework for cost analysis that
many a computer scientist will learn at some point in their undergraduate career.
However, its high-level description leaves some practical gaps, especially around
how to actually bookkeep the finer details of general program
analysis. This post explains how to fill in these gaps to
get the *quantum* physicist's method, a refinement of the physicist's method
that is robust enough for automatic program analysis, as in
my paper [here](https://dl.acm.org/doi/abs/10.1145/3473581). (Quick disclaimer: There is
no quantum computing in here, despite the name.)

# The Classical Physicist's Method

In order to make sense of the physicist's method (and the later refinements we'll make to it), it is probably
good to start by recalling the physical reasoning behind it. Think back to your highschool physics class
where you learned about energy. If you drop a 1 kilogram ball from
1 meter above the Earth, and drop an identical ball from the top of a 1 meter high ramp, how do their speeds compare
when they hit the ground?

It might seem like I haven't given you enough information, but a neat little physical
principle called *conservation of energy* tells you all you need to know. At the start, both balls
have the same amount[^grav] of (gravitational) potential energy since they are the same height, same mass, and subject to the same
gravity. And at the end, both balls have none, since their distance from the ground is 0. Because the
total energy is *conserved*, we know that all that energy must still be around, just in some other form - in this case,
as kinetic energy in the balls' speeds. So even though both
balls took different routes to the ground, the same energy goes into their speed, and thus the speeds are the same[^speed].
Let me emphasize that point: *As long as we know energy is conserved,
we can measure expenditure with the difference between starting and ending energy*.

Eventually Robert Tarjan and Danny Sleator brought this idea to computer science.
They introduced it to define
*amortized* algorithm costs (see [here](https://epubs.siam.org/doi/pdf/10.1137/0606031?casa_token=cR8nppnD8MQAAAAA%3AgK8XhJzUtPvkIVXTHIe299HSRuczuwiYVM74VDBjOMpHDlLcZLIVlziYWpRQMHeuN3lz84b9kIUg&)).
However, the idea of amortization itself is much older, and comes from the financial industry.
Amortization is used to express a notion of average cost where occasional
spikes of high cost are prepaid over longer periods of time, like paying off a loan
in installments instead of all at once at the due date. However, if we think about this
prepayment as storing extra potential energy for later, the reasoning becomes exactly the
same as reasoning about conservation of energy. Hence, Tarjan and Sleator suggested
calling the approach "the physicist's method"[^personal].

To see how this all comes up in the analysis of algorithms, consider implementing an arbitrarily sized list using
fixed-size arrays[^list]. In particular, lets look at the list's insertion function, and measure its
cost in how many array write accesses it uses. The common case is that list insertion will just be able to directly write a new
element into the next unused slot in the array, for a cost of 1 write. But eventually, the array will be full with no unusued slots.
When this happens, our implementation will:

1. allocate a new array double the size of the old one
2. write all the elements from the old array into the new one
3. write the new element into the next empty space of the new array

If you count them, you'll find this uncommon case uses a number of array writes equal to the length of the list plus one,
which is a far cry from the common case's constant cost. Worst-case cost analysis thus makes this algorithm look much more
inefficient than it usually is.

If instead we think through a lens of amortization, we find that insertion is, morally-speaking, a constant cost operation.
Essentially, insertion is cheap enough often enough that prepaying a little extra at each common case
can offset the high cost of the uncommon case. We can see how that looks in the graph below, where the spikes of cost
don't exceed the constant-per-step payment.

![a graph showing a constant-per-step bound over spiky costs](https://i.stack.imgur.com/CPP0P.jpg)

To show this formally, we define a suitable *potential* function \\(\Phi\\) giving the amount of prepaid potential energy stored in the
program state. Specifically, our desired \\(\Phi(A)\\) will give assign 2 potential per element past
the halfway point in the array \\(A\\).
We will think of this like attaching a 2-charge battery to each individual array cell past the halfway point, so that
we deal with that battery's energy if and only if we access that array cell.
The amortized cost of an operation \\(o\\) is then defined as \\(\Phi(A) - \Phi(o(A)) + C(A,o)\\), which is the difference in potential induced by \\(o\\) plus \\(C(A,o)\\) its true cost on the array \\(A\\).
If we account for this potential energy alongside our normal costs, suddenly the cost profile becomes much smoother:

* In the common case, insertion just writes into the next unused slot of \\(A\\). We still pay the true cost of 
\\(C(A,\mathsf{insert}) = 1\\) for the that write, but now might also need to pay 2 more to "charge the battery"
if the element is past the halfway point in the array. This "battery-charging" is how we pay for the difference in
potential as given by \\(\Phi\\). In the worst case, the total amortized cost is therefore 3.

* In the uncommon case, our array \\(A\\) is now full. Thus, we have stored 2 units of potential with half the elements of \\(A\\),
which works out to one unit of potential for each element. So, potential can pay for each element's write into the new array,
with none leftover. The new array itself then has no potential, because it is exactly half full. At this point, stored
potential has exactly covered the cost of all writes and all the state's potential, accruing a running cost of 0. Finally
list insertion behaves like its common case again, giving worst-case amortized cost of 3.

Thus, through mediating energy expenditure with potential, we find that
insertion into these array-backed lists takes an amortized constant number of writes. The magic
happened when we prepaid for two extra writes in the common case to "charge the battery".
Eventually, that prepayment gets spent in the uncommon case to cover the writes into the
new array.

Now that you've seen an example, we can look at the general case:

> Given:
> * a set of operations \\(\mathsf{op} = \mathsf{state} \rightarrow \mathsf{state} \\)
> * a true cost function \\(C : \mathsf{state} \times \mathsf{op} \rightarrow \mathbb{R}\\)
>
> If you can find:
> * a potential function \\(\Phi : \mathsf{state} \rightarrow \mathbb{R}_{\geq 0}\\) 
> * amortized cost \\(a_o\\) for each operation \\(o\\)
>
> such that \\(\Phi(S) + a_{o_i} \geq \Phi(o_i(S))  + C(S, o_i)\\)
>for any state \\(S\\),
>
> Then for any sequence of \\(n\\) operations \\((o_i)\\) and the sequence of states \\((S_i)\\) that they induce :
>
> \\[\sum_{i=0}^{i<n} a_{o_i} + \Phi(S_{0})  - \Phi(S_{n}) \geq \sum_{i=0}^{i<n} C(S_i, o_i)\\]
>
> i.e., the total amortized cost plus change in potential covers the total true cost.

<p></p>

The condition placed on \\(\Phi\\) and \\(a_{o_i}\\) is what corresponds to conservation of energy[^technically].
The potential in the state \\(\Phi(S)\\), and the supplied extra energy \\(a_{o_i}\\) are sufficient to
cover the potential stored in the resulting state \\(\Phi(o_i(S))\\) and the energy
expenditure \\(C(S, o_i)\\) -- no new energy is created. With that condition in place, just like in physics,
we can forget about intermediate states and just focus on the initial and ending states \\(S_0\\) and \\(S_{n}\\).
Hence the conclusion of the theorem, that the potential difference between \\(\Phi(S_{0})\\) and \\(\Phi(S_{n})\\) 
plus all the total supplied extra energy can pay for the total energy expenditure.

In the above formalization, you might notice that the form of the potential function \\(\Phi\\) is left abstract.
The function *could* be any sort of complicated, non-uniform, ugly function. But it is no coincidence that
the \\(\Phi\\) we chose in our above example was "nice". Specifically, this "niceness" amounts to potential being
*local* - one can think of the state \\(S\\) as broken up into many pieces (our array cells), each with their own local amount of potential (our "batteries"), and then \\(\Phi\\) just gives the sum of potential stored on these different pieces.
In fact, this appears to be exactly how Tarjan intended the bookkeeping for the physicist's method to be conceptualized:

>In order to keep track of saved or borrowed credits [potential], it is generally convenient to
store them in the data structure. ... It is important to
realize that this is only an accounting device; the programs that actually manipulate
the data structure contain no mention of credits or debits [energy].

--[Tarjan](https://epubs.siam.org/doi/pdf/10.1137/0606031?casa_token=cR8nppnD8MQAAAAA%3AgK8XhJzUtPvkIVXTHIe299HSRuczuwiYVM74VDBjOMpHDlLcZLIVlziYWpRQMHeuN3lz84b9kIUg&)

This local-view of potential has been time-tested, and is basically the only form of potential
you will find in the literature.
Given this efficacy, you might wonder if it can be equally effective when placed in the setting
of program analysis. And the answer - as will be made clear in this post
of this post - is *no*. As it turns out, the reasoning we perform at the algorithm
level sometimes obscures a *non-local* definition of \\(\Phi\\). This will be explained
in the next section.

# Building a Program Analysis

To build a program analysis based on the physicist's method, we first need to refine
our view of operations and energy payments. This is because a program analysis
builds up from a finer level of detail than an algorithm analysis, starting from
the individual code operations. And it is here, in the nitty-gritty details of code-space analysis, that
we find the physicist's method to be somewhat underspecified.

To get to the code, we need to break up operations into smaller pieces.
To a caller of our program, list insertion is one macro-operation, like we had above.
But in the program itself, list insertion is the result of many micro-operations: array allocations,
write accesses, etc. A program analysis needs to be able to reason on the level of these program-space micro-operations,
and build them up to the resulting macro-operation. So our program analysis should focus on
expressing macro-operations in terms of specific sequences of micro-operations, at which point
the classical physicist's method can take us the rest of the way to recovering the full analysis.

Reasoning about these micro-operations, however, is not quite the same as reasoning
about the macro-operations. The extra energy payments \\(a_o\\) are still at the macro level -
costs are meant for the caller, since energy conservation prevents the program itself
from supplying extra energy. Thus, while the extra energy \\(a_o\\) previously came in on an
operation-by-operation basis for algorithm analysis, a program analysis should instead imagine that payment is dealt out of some
pre-existing energy store \\(p_i \geq 0\\) supplied by the caller. To explicitly connect back to the
classical framework, \\(p_0\\) for the first micro-operation of
macro-operation \\(o\\) should be equal to \\(a_o\\), since that is how
much the caller pays.

After adapting the theorem from the previous section to our new focus, we are left with something
like the statement below. The main differences from the previous theorem are that we reason about our energy pool \\(p_i\\) instead of
extra supplied energy \\(a_o\\), and that we only consider *some* sequences of operations. The energy
pool only needs to be able to pay out over the sequences of operations that our program's code could induce.

> Given:
> * a set of (micro-)operations \\(\mathsf{op} = \mathsf{state} \rightarrow \mathsf{state} \\)
> * a collection of possible sequences of such operations \\(\mathsf{seq}\\)
> * a true cost function \\(C : \mathsf{state} \times \mathsf{op} \rightarrow \mathbb{R}\\)
>
> If you can find:
> * a potential function \\(\Phi : \mathsf{state} \rightarrow \mathbb{R}_{\geq 0}\\) 
> * an initial pool of energy \\(p_0 \geq 0\\)
>
> such that \\(\Phi(S_i) + p_{i} \geq \Phi(S_{i+1}) + p_{i+1} + C(S_i, o_i)\\)
> across all non-negative energy pool sequences and state sequences and induced by \\(\mathsf{seq}\\)
> from \\(p_0\\) and any initial state \\(S_0\\), respectively
>
> Then for any sequence of \\(n\\) operations \\((o_i)\\) prefixing \\(\mathsf{seq}\\)
> and the sequence of states \\((S_i)\\) that they induce:
>
> \\[\Phi(S_{0}) + p_0  - \Phi(S_{n}) - p_n \geq \sum_{i=0}^{i<n} C(S_i, o_i)\\]
>
> i.e., difference in energy bounds the total cost at every point

<p></p>

With this framework, our program analysis really just needs to find a suitable \\(\Phi\\) and \\(p_0\\).
We already know that \\(\Phi\\) covers the potential on data structures, so \\(p_0\\) should deal with
potential independent of data structures, i.e., \\(p_0\\) should be some constant.
The interesting piece is therefore \\(\Phi\\), so lets focus there.
We have already committed to a *local* definition of \\(\Phi\\), so our task is really just finding way of
locally assigning potential
to the parts of each individual data structure that might arise in our program.
There might be many ways to do this,
but one simple option is to let the type of a data structure include some annotation indicating how much potential it
stores where, like "list but with 2 unit of potential per element". This eventually leads
to the type system called Automatic Amortized Resource Analysis (AARA), which automatically
infers the required potential annotations, giving cost bounds in the process. (See [here](https://dl.acm.org/doi/pdf/10.1145/640128.604148) for its origin and [here](https://www.raml.co/) for an up-to-date implementation.)

This localized-potential approach happens to work rather well in many cases. For instance, AARA
can analayze sorting functions and many list manipulations without issue. Nonetheless, it is not hard to confound this approach.
Consider a simple loading function that populates one of our array-backed list from one of two other lists.
When called, the load function first executes some code (e.g. `shouldComeFromList1`) to decide which list the data should
come from, and then inserts it all one element at a time. Here we see what this might look like in pseudo-code[^python].

```python
def load(target, list1, list2):
    if shouldComeFromList1():
        for i in list1:
            target.insert(i)
    else:
        for i in list2:
            target.insert(i)
```

If we assume that `shouldComeFromList1` has no array writes, then we only need consider the cost
of insertion. Clearly, only one list's-worth of insertions occurs, and each insertion has an amortized cost of 3,
so \\(\Phi\\) need only assign 3 energy-per-element to the list selected by `shouldComeFromList1`.
However, there is in general no way to statically know which list that is -- it is *undecidable*,
even if we had access to the source code for `shouldComeFromList1`.
This confounds our local method of accounting, since it must store potential in a specific list,
but cannot say which list will end up sourcing the data. We might get around this by having \\(\Phi\\) yield something
like \\(3*\mathsf{max}(|\verb"list1"|, |\verb"list2"|)\\) to cover the worst case, but this \\(\mathsf{max}\\) is not
expressible in a local way - at best, the local approach can overapproximate
\\(\mathsf{max}\\) with a sum, giving potential of \\(3*(|\verb"list1"| + |\verb"list2"|)\\), the cost for loading *both* lists.
And while this bound can only be loose by a constant factor of 2, other examples can loosen the bound to be exponentially worse
(like binary search [here](https://dl.acm.org/doi/abs/10.1145/3473581)).

At this point, you might think the bound looseness is just some weakness on *our* end, where
presumably *some* localization of the tightest potential exists, but we just can't figure it out.
However, the situation is actually worse:
We can create an example where *no* tight localization suffices, even while nonlocal reasoning
makes a tight solution obvious[^Bell]. This happens especially when measuring the cost of a resource like memory,
since memory is returned after use and can be reused[^neg].

To see how this problem arises, imagine we have a list of data, and two different data processing procedures
`f` and `g`. To compare the results of these procedures, we might write the code below.
How should we account for the memory cost of the comparison, if both `f` and `g` temporarily
use one unit of memory per element in the list, and we assume that copying is free?

```python
def copy(list):
    ret = emptyList()
    for i in list:
        ret.insert(i)
    return ret

def processBoth(data):
    dataCopy = copy(data)
    return (f(data), g(dataCopy))
```

It seems obvious from the outset that whatever memory \\(f\\) uses can be reused for \\(g\\),
since both act on lists of equal length. So, we should only need to allocate \\(|\verb"data"|\\)
memory units. However, if that is all we have, accounting for it locally is impossible.

To follow the accounting, let's step through a call to `processBoth`. We start with the only
data structure being our input `data`, so it must contain all the potential.
We proceed to copy [^copy] `data` to ready it for each of the processing functions.
This copying procedure accesses all the cells of `data`, so some amount of potential could
have been moved into `dataCopy`. Then \\(f\\) is applied to `data`, requiring all of
the \\(|\verb"data"|\\) memory units. Now, because \\(f\\) doesn't touch
`dataCopy`, \\(f\\) cannot use any of the potential in `dataCopy` -- this means `data`
needs to have kept all its potential earlier, moving none into `dataCopy`. However,
this is followed by applying \\(g\\) to `dataCopy`, which results in mirrored accounting for
potential: all potential should have been moved `dataCopy`, with none left in `data`! Thus, no
local allocation of \\(|\verb"data"|\\) potential suffices. Just like before, the local
approach can only manage to overapproximate this exampe by a factor of 2, and can
be exponentially worse in other examples.

# The Quantum Physicist's Method

So far, our situation is rather unfortunate. We have this beautiful framework for algorithm analysis,
but when we zoom in to the level of code it weakens considerably. However, there is a solution:
the *quantum* physicist's method. Given that we've zoomed down to the micro-level and found
non-local phenomena, this analogy is already quite appropriate.

The trick to making the quantum physicist's method work is to introduce "worldviews",
which are somewhat analagous to states in superposition.
Each worldview has its own separate, local allocation of potential, and we work with as many
worldviews at a time as we choose. The big twist with these worldviews is that we allow them
to allocate *negative* potential[^negative] wherever they want, so long as at least one worldview is totally non-negative --
we call this non-negative worldview the "witness".
When we consider a cost being paid, so long as *some* witness can pay normally without going negative,
every other worldview may pay and go as negative as they like. As a result, every worldview
pays the same amount[^overpay] in lock step, and only differ as to how they allocate their potential.

Then we define the amount of potential \\(\Phi\\) assigns a collection of worldviews as
the *max* across all worldviews. Since each worldview covers the cost individually, the change in max potential
also covers the cost. And since the witness is non-negative,
we know the potential is always sensically non-negative.

The mechanics of these worldviews might seem kind of weird, but when you see them in
action they aren't so mysterious. Consider the following situation:
Alice and Bob get $5 to share from their parents to spend on candy in a candy store. Alice wants a $3
pack of caramels and Bob wants a $2 chocolate bar. However, Alice's caramels are in a
vending machine that only takes $5 bills. If Alice keeps $5 to herself, then Bob can't buy his candy.
But if Bob keeps $2 to himself, then Alice can't use the vending machine for her candy.
So, what do Alice and Bob do?

The answer is quite simple: Alice buys her caramels with all the money, gets the change back,
and then gives it to Bob --
they both can then get what they want with no extra money needed.
I'm sure I have done the same with my brother plenty of times growing up.
We can bookkeep this the following way:

|                       | start | Alice buys | get change | transfer | Bob buys |
|:---------------------:|:-----:|------------|------------|----------|----------|
| Alice/Bob money split |  5/0  | 0/0        | 2/0        | 0/2      | 0/0      |

And this is exactly what we want, with one small caveat:
As mentioned in the Tarjan quote above, we don't actually have operations
that manipulate potential -- potential is entirely ephemeral[^alter].
Thus, the "transfer" from this
bookkeeping is not something we can adapt to our analysis. This is why we need to use worldviews.
So, we give the following accounting for the exact same circumstance, now using the mechanics of worldviews:

|                                   | start | Alice buys | get change | Bob Buys |
|:---------------------------------:|:-----:|------------|------------|----------|
| worldview 1 Alice/Bob money split |  5/0  | 0/0        | 2/0        | 2/-2     |
| worldview 2 Alice/Bob money split | 3/2   | -2/2       | 0/2        | 0/0      |

With this worldview accounting[^qt], we pay the exact same amount out of the same place at each step.
The only difference between the two worldviews is that worldview 1 starts in the allocation of money needed
for Alice to buy her candy, and worldview 2 starts in the allocation needed for Bob to buy his. Then,
we find that the problematic "transfer" occurs where the witness switches between worldviews --
we see that happen at "get change", since worldview 1 is the witness at "Alice buys", and
worldview 2 is the witness at "Bob buys". This pattern will hold in general, allowing transfers
to be coded completely implicitly into our analysis.

Using worldviews like this, we can solve both of the problems from the previous section:

* To solve the first -- the data loading problem -- simply start with 2 worldviews: one where `list1` carries all potential,
and one where `list2` does. No matter which list pays, there will then be a valid witness worldview.

* To solve the second -- the data processing problem -- start with 2 worldviews assigning `data` all the potential. Then upon copying,
let the worldviews diverge -- one leaves all the potential on `data`, and one moves it all
to `dataCopy`. The former can be the witness while applying `f`, and the latter when applying `g`.

In either case the max amount of potential across the worldviews is exactly the tight amount of potential
we wanted assigned.

And so, with worldviews in hand, we can more accurately build up a cost analysis from the micro- to macro-level
of operations. This gives us the results we expect for macro-operations, so we can then rely on
classical physicist's method reasoning to stitch together any macro-operations.
That gives us our full picture of program analysis.

# Conclusion

Now you've seen how the quantum physicist's method fills in the gaps at the micro-level left by the
classical physicist's method. Worldviews salvage the niceness of locality by wrapping a bunch of local accountings
together and letting them make each other more flexible. Then we can slot the results of analyzing each
macro-operation directly into our classical physicist's method framework. This
leaves us with a program analysis built off the physicist's method that can give many tighter
bounds than its predecessors. Finally, for those interested in seeing such an analysis in action,
I'll leave you with a link to my work extending AARA [here](https://dl.acm.org/doi/abs/10.1145/3473581).

[^grav]: Specifically, they both have \\(1\mathsf{kg} * 9.81\frac{\mathsf{m}}{\mathsf{s}^2} * 1 \mathsf{m} = 9.81 \mathsf{J}\\) of energy.

[^speed]: Specifically, solving for
\\(v\\) in the conversion between energy and speed
\\(9.81\mathsf{J} = \frac 1 2 * 1\mathsf{kg} * (v \frac{\mathsf{m}}{\mathsf{s}})^2 \\) gives
\\( 4.43\frac{\mathsf{m}}{\mathsf{s}}\\) as the speed of the balls at ground level.

[^personal]: I personally found this analogy with physical reasoning very useful to my
understanding when I was learning about algorithm analysis in undergrad. I'm sure many students feel the same.

[^list]: This list would be the data structure called [`ArrayList` in Java](https://docs.oracle.com/javase/8/docs/api/java/util/ArrayList.html)
and [`vector` in C++](https://www.cplusplus.com/reference/vector/vector/), and probably underlies a lot of other list implementations too.

[^technically]: Technically speaking, it only corresponds to the non-creation of energy, since we are interested
in an upper-bound on cost. Energy conservation means both non-creation and
non-loss of energy. Adapting the amortized analysis framework to non-loss would result in a lower-bound on cost.

[^python]: By pseudo-code I mean python.

[^Bell]: For those with a physics background, you might consider this our version of a [Bell test](https://en.wikipedia.org/wiki/Bell_test).

[^neg]: This return of energy is modeled in our framework simply by letting \\(C\\) return negative costs.

[^copy]: Copying is only really needed in this code if `f` or `g` might mutate the underlying list. However,
the pertinent features of code pattern also come up in side-effect free settings during, e.g., tree traversal.
See [here](https://dl.acm.org/doi/abs/10.1145/3473581).

[^negative]: A hallmark of quantum mechanics is the inclusion of negative quantities that classically
can't be negative -- specifically, negative probabilities.

[^overpay]: Well, technically a worldview could choose to overpay for the cost too.

[^alter]: This is still the right idea for program analysis. Programmers write code to solve their own
problems, and analysis comes after the fact. We wouldn't want to burden programmers with *also* writing
to solve our analyses' problems. Thus, since potential is entirely a construct of the analysis,
we won't see any "transfer" functions written in the code to move potential.

[^qt]: We call this particular way of accounting for how to get around the barrier of the vending machine
"resource tunneling", because it is analgous to quantum tunneling around a potential barrier.
