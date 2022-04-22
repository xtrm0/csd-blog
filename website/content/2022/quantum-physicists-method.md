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
However, its high-level description leaves some practical gaps, especially concerning
how to actually bookkeep its finer details, and these details become important
when trying to build a more explicit accounting framework.
This post explains how to fill in these gaps with
the *quantum* physicist's method, a refinement of the physicist's method
that is robust enough for automatic program analysis, as in
my paper [here](https://dl.acm.org/doi/abs/10.1145/3473581). (Quick disclaimer: There is
no quantum computing in here, despite the name.) To do explain the new
bookkeeping devices of the quantum physicist's method,
this post will first explain the classical physicist's method
for algorithm analysis, then describe the difficulties it encounters when
adapted to the domain of program analysis, and finally lay out the
solution granted by bookkeeping with the quantum physicist's method.
 
# The Classical Physicist's Method

To make sense of the physicist's method (and the later refinements we'll make to it), it is
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
can offset the high cost of the uncommon case. We can see how that looks in the graph below[^graph], where the 
black spikes of cost
never exceed the red constant-per-step payment.

![a graph showing a constant-per-step bound over spiky costs](./amortizedgraph.jpeg)

To show this formally, we define a suitable *potential* function \\(\Phi\\) giving the amount of prepaid potential energy stored in the
program state. Specifically, our desired \\(\Phi(A)\\) will be equal to twice the number of
filled slots past
the halfway point in the array \\(A\\).
We can think of this like attaching a 2-charge battery to each individual array cell past the halfway point, so that
we deal with that battery's energy if and only if we access that array cell.
The amortized cost of an operation \\(o\\) is then defined as \\(\Phi(o(A)) - \Phi(A) + C(A,o)\\), which is the difference in potential induced by \\(o\\) plus \\(C(A,o)\\) its true cost on the array \\(A\\).
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
The potential in the state \\(\Phi(S)\\), and the extra energy paid \\(a_{o_i}\\) are sufficient to
cover the potential stored in the resulting state \\(\Phi(o_i(S))\\) and the energy
expenditure \\(C(S, o_i)\\) -- no new energy is created. With that condition in place, just like in physics,
we can forget about intermediate states and just focus on the initial and ending states \\(S_0\\) and \\(S_{n}\\).
Hence the conclusion of the theorem, that the potential difference between \\(\Phi(S_{0})\\) and \\(\Phi(S_{n})\\) 
plus all the total supplied extra energy can pay for the total energy expenditure.

In the above formalization, you might notice that the form of the potential function \\(\Phi\\) is left abstract.
The function *could* be any sort of complicated, non-uniform, ugly function. But it is no coincidence that
the \\(\Phi\\) we chose in our above example was "nice". Specifically, this "niceness" amounts to potential being
*local* -- one can think of the state \\(S\\) as broken up into many pieces (our array cells),
each with their own local amount of potential (our "batteries").
Then \\(\Phi\\) just gives the sum of potential stored on these different pieces,
and adjusts the potential on a piece only when that piece is directly operated on.
In fact, this appears to be exactly how Tarjan intended the
bookkeeping for the physicist's method to be conceptualized:

>In order to keep track of saved or borrowed credits [potential], it is generally convenient to
store them in the data structure. Regions of the structure containing credits are
unusually hard to access or update (the credits saved are there to pay for extra work);
regions containing "debits" are unusually easy to access or update. It is important to
realize that this is only an accounting device; the programs that actually manipulate
the data structure contain no mention of credits or debits.

-- Tarjan in [*Amortized Computational Complexity*](https://epubs.siam.org/doi/pdf/10.1137/0606031?casa_token=cR8nppnD8MQAAAAA%3AgK8XhJzUtPvkIVXTHIe299HSRuczuwiYVM74VDBjOMpHDlLcZLIVlziYWpRQMHeuN3lz84b9kIUg&)


This local-view of potential has been time-tested, and is basically the only form of potential
you will find in the literature. As such, our goal throughout the rest of this
post will be to keep our definition of potential as local as possible.

# Building a Program Analysis

To build a program analysis based on the physicist's method, we first need to
adapt the framework above. This is because some of the assumptions made
above are simply not applicable in our programmatic setting. The differences
are mostly technical, but accounting for them does lead to a slightly
different-looking theorem.

1. The above framework assumes that operations can be executed in any order.
This makes sense when treating the collection of operations like an
interface -- you don't know what order an external user might call operations, so
your analysis needs to be prepared for anything. However this assumption
is wrong for analyzing a program (like the implementation of such an interface).
The program itself dictates specific sequences of operations, and the
analysis must take this into account to get sensible results[^timesensitive].

2. The above framework assumes that extra energy \\(a_o\\) is
paid out on a per-operation basis.
Again, this makes sense when reasoning about an interface, since an external
user pays for each operation they call. However, when a program executes an operation,
there is no external user to introduce extra energy into the system, so costs
must be paid solely out of the energy supply internal to the program, i.e., the potential
of the state[^pool].

After adapting the theorem from the previous section to account for these
differences we are left with something
like the statement below. The main changes are that we consider only certain
sequences of operations, and that we drop amortized costs.

> Given:
> * a set of operations \\(\mathsf{op} = \mathsf{state} \rightarrow \mathsf{state} \\)
> * a collection of possible sequences of such operations \\(\mathsf{seq}\\)
> * a true cost function \\(C : \mathsf{state} \times \mathsf{op} \rightarrow \mathbb{R}\\)
>
> If you can find:
> * a potential function \\(\Phi : \mathsf{state} \rightarrow \mathbb{R}_{\geq 0}\\) 
>
> such that \\(\Phi(S_i) \geq \Phi(S_{i+1}) + C(S_i, o_i)\\)
> across all state sequences induced by \\(\mathsf{seq}\\)
> from any initial state \\(S_0\\)
>
> Then for any sequence of \\(n\\) operations \\((o_i)\\) prefixing \\(\mathsf{seq}\\)
> and the sequence of states \\((S_i)\\) that they induce:
>
> \\[\Phi(S_{0}) - \Phi(S_{n}) \geq \sum_{i=0}^{i<n} C(S_i, o_i)\\]
>
> i.e., difference in energy bounds the total cost at every point[^corollary]

<p></p>

With this framework, our program analysis just needs to find a suitable \\(\Phi\\).
We are currently only considering a *local* definition of \\(\Phi\\), so our
task is really just finding way of
locally assigning potential
to the parts of each individual data structure at each point in our program.

There might be many ways to find such a local \\(\Phi\\),
but one simple option is to type the data structures. These
types can then include some annotation indicating how much potential the data structure
stores where, like "list but with 2 unit of potential per element". This tells
you exactly how much potential each piece holds, making it easy to recover a
locally-definable \\(\Phi\\).

If you run
with this idea, you might eventually get something that looks similar to
the type system called Automatic Amortized Resource Analysis (AARA).
AARA can infer a valid \\(\Phi\\) through the inference of
potential-carrying types, and is fully automatable (as its name suggests).
See [here](https://dl.acm.org/doi/pdf/10.1145/640128.604148) for AARA's origin
and [here](https://www.raml.co/) for an up-to-date implementation.


There are also a lot of different ways to approach this problem
apart from AARA. Some approaches are more manual 
(like [this](https://link.springer.com/chapter/10.1007/978-3-319-89884-1_19)
verification framework using separation logic). Some add potential to 
non-type-based techniques (like [this](https://dl.acm.org/doi/abs/10.1145/3408979) 
adaptation of recurrence solving). And some are designed for different 
programming environments (like [this](https://drops.dagstuhl.de/opus/volltexte/2020/12355/pdf/LIPIcs-FSCD-2020-33.pdf)
one for client-server interactions). I'm certain there are many more options still, 
but the reason I bring up AARA in particular is that,
while all of these approaches *could* potentially employ the quantum phyisicist's method in
the future, AARA is the one that I *did* adapt to use the quantum physicist's method.

 
# Trouble in Paradise

This localized-potential approach happens to work rather well in many cases. For instance, AARA
can analyze sorting functions and many list manipulations without issue. Nonetheless, it is not hard to confound this approach.
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

At this point, you might think the bound looseness
is just some weakness on *the analysis's* end, where
presumably *some* localization of the tightest potential exists, but the analysis just can't figure it out.
However, the situation is actually worse:
We can create an example where *no* tight localization suffices, even while nonlocal reasoning
makes a tight solution obvious[^Bell].

This problem happens especially when measuring the cost of a resource like memory,
since memory is returned after use[^neg] and can be reused. When a resource returned, it is as
if additional payment is provided midway through the computation. This *could* lessen the amount
of resources needed upfront, but only if those resources aren't needed prior to when the extra
resources are returned. In effect, the cost of resources like memory is measured with
their *peak* cost, the high water mark of the number of resources in use at one time.
These resources are therefore a bit more complicated than resources that only tick down, like
time. This makes it easy to create a situation with no tight localization of potential, like that below.

To see this problem in action, imagine we have a list of data, and two different
data processing procedures `process1` and `process2`. To compare the results of
these procedures, we might write the code below.
How should we account for the *memory* cost of the comparison, if each of `copy`[^copy],
`process1`, and `process2` temporarily
use one unit of memory per element in the list?

```python
def copy(list):
    ret = emptyList()
    for i in list:
        ret.insert(i)
    return ret

def processBoth(data):
    dataCopy = copy(data)
    return (process1(data), process2(dataCopy))
```

It seems obvious from the outset that whatever memory `copy` uses can be
reused for `process1`, and that `process1`'s memory in turn can be reused for `process2`,
since all act on lists of equal length. So, we should only need to allocate \\(|\verb"data"|\\)
memory units. However, if that is all the memory we have,
accounting for it locally is impossible.

To follow the accounting, let's step through a call to `processBoth`. We start with the only
data structure being our input `data`, so it must contain all the potential.
We proceed to copy `data` to ready it for each of the processing functions.
This copying procedure temporarily uses all the \\(|\verb"data"|\\) memory units,
leaving some amount stored on `data` and some amount stored on `dataCopy` when
the memory is returned.
Then `process1` is applied to `data`, requiring all of
the \\(|\verb"data"|\\) memory units. Now, because `process1` doesn't touch
`dataCopy`, `process1` cannot use any of the potential in `dataCopy`
 -- this means `data`
needs to have recieved all the potential, and none is stored on `dataCopy`. However,
this is followed by applying `process2` to `dataCopy`, which results in mirrored accounting for
potential: all potential should have been returned to `dataCopy`, with none stored in `data`!
While we intuitively know that this could be solved by having `process1` return
potential to `dataCopy`, there is never a time where `process1` and `dataCopy`
are local to the same operation.
Thus, no local allocation of \\(|\verb"data"|\\) potential suffices.
Just like before, the local
approach can only manage to overapproximate this example by a factor of 2, and can
be exponentially worse in other examples.


# The Quantum Physicist's Method

So far, our situation is rather unfortunate. We have this beautiful framework
from algorithm analysis, but when we naively adapt it to a program analysis we
must sacrifice either the efficacy of the result or the beauty of locality.
However, there is a solution: bookkeeping using the *quantum* physicist's method.
To keep this section intelligible to non-physicists, this section will focus on
the actual execution of the method, while any quantum
physical parallels that come up will be kept
contained in the footnotes.

The idea behind the quantum physicist's method is to introduce
the accounting device of "worldviews". Each individual worldview 
\\(\phi_j : \mathsf{state} \rightarrow \mathbb{R} \\) is
just a normal local accounting of potential like like our previous \\(\Phi\\), 
though with the added caveat that they are
allowed to locally assign *negative* amounts of potential under special
conditions[^detail].

Formally, the collection of worldviews satisfies the following
properties for all state sequences induced by \\(\mathsf{seq}\\)
from any initial state \\(S_0\\)

1.  \\(\forall j. \hspace{4pt} \phi_j(S_i) \geq \phi_j(S_{i+1}) + C(S_i, o_i)\\),
i.e., every worldview pays out the usual costs

2.  \\(\exists j. \hspace{4pt} \forall T\subseteq S_i. \hspace{4pt} \phi_j(S_i) \geq 0 \\),
i.e., some worldview is classically valid, wherein potential is non-negative
everywhere[^whole]

Given these properties, one can prove the following key theorem:

> 
> Theorem: \\(max_j\phi_j\\) is a suitable definition
> of \\(\Phi\\) for the classical physicist's method
>

Indeed, the first property meets the bulk of the requirements for a valid
potential function, and the second property ensures that the max potential
is always classically valid.

You might at this point wonder what this new way of finding a potential 
function buys us. The answer is that this simple way of combining our 
familiar local accounts of potential introduces some powerful *nonlocal* 
flexibility. By allowing different worldviews to tactically "go into debt",
this method can infer tighter cost bounds than naive local reasoning can usually 
supply.

To better understand how the mechanics of these worldviews actually work,
it might help to walk through a situation without so much technical cruft:
Suppose that
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
The "transfer" operation is actually quite nontrivial to work with. Only
highly specialized programming languages will even have constructs for *mentioning*
potential, and those that do will be burdened (or burden the programmer) with
figuring out how such constructs can be soundly used. But, by using worldviews for
bookkeeping, this whole problem can be bypassed entirely. We provide such an
account below:

|                                   | start | Alice buys | get change | Bob Buys |
|:---------------------------------:|:-----:|------------|------------|----------|
| worldview 1 Alice/Bob money split |  5/0  | 0/0        | 2/0        | 2/-2     |
| worldview 2 Alice/Bob money split | 3/2   | -2/2       | 0/2        | 0/0      |

With this worldview accounting[^qt], we pay the exact same amount out of the same place at each step.
The only difference between the two worldviews is that worldview 1 starts in the allocation of money needed
for Alice to buy her candy, and worldview 2 starts in the allocation needed for Bob to buy his. Then,
we find that the problematic "transfer" occurs where different worldviews become classically valid --
we see that happen at "get change", since worldview 1 is classically valid at "Alice buys", and
worldview 2 is classically valid at "Bob buys". This pattern will hold in general, allowing transfers
to be coded completely implicitly into our analysis.

Using worldviews like this, we can solve both of the problems from the previous section:

* To solve the first -- the data loading problem -- simply start with 2 worldviews: one where `list1` carries all potential,
and one where `list2` does. No matter which list pays, there will then be a valid witness worldview.

* To solve the second -- the data processing problem -- start with 2 worldviews assigning `data` all the potential. Then upon copying,
let the worldviews diverge -- one leaves all the potential on `data`, and one moves it all
to `dataCopy`. The former can be the witness while applying `process1`, and the latter when applying `process2`.

In either case the max amount of potential across the worldviews is exactly the tight amount of potential
we wanted assigned.

And so, with worldviews in hand, we can salvage the niceness of locality by wrapping a bunch of local accountings
together and letting them make each other more flexible. From such an accounting we can
reconstruct a potential function that satisfies the standard framework for 
amortized analysis. This
leaves us with a program analysis built off the physicist's method that can give many tighter
bounds than its predecessors.

# Wrap Up

If you are interested in seeing such an analysis in action,
I'll point you again to my work extending AARA [here](https://dl.acm.org/doi/abs/10.1145/3473581).
My paper adds the quantum physicist's method along with some special infrastructure called *remainder contexts*, and then
uses its new capabilities to be able to automatically reason about memory usage and tree depth. The work also
comes with an implementation, a description of how it was designed, and tables of experiments run with it on
the OCaml standard library `Set` module. The implementation never gave worse cost bounds than the local approach, and often
gave much better ones. You can check it out and see for yourself!

[^grav]: Specifically, they both have \\(1\mathsf{kg} * 9.81\frac{\mathsf{m}}{\mathsf{s}^2} * 1 \mathsf{m} = 9.81 \mathsf{J}\\) of energy.

[^speed]: Specifically, solving for
\\(v\\) in the conversion between energy and speed
\\(9.81\mathsf{J} = \frac 1 2 * 1\mathsf{kg} * (v \frac{\mathsf{m}}{\mathsf{s}})^2 \\) gives
\\( 4.43\frac{\mathsf{m}}{\mathsf{s}}\\) as the speed of the balls at ground level.

[^personal]: I personally found this analogy with physical reasoning very useful to my
understanding when I was learning about algorithm analysis in undergrad. I'm sure many students feel the same.

[^list]: This list would be the data structure called a [dynamic array](https://en.wikipedia.org/wiki/Dynamic_array).
It is the [`ArrayList` in Java](https://docs.oracle.com/javase/8/docs/api/java/util/ArrayList.html)
and the [`vector` in C++](https://www.cplusplus.com/reference/vector/vector/), and probably underlies a lot of other list implementations too.

[^graph]: Taken from [here](https://stackoverflow.com/questions/200384/constant-amortized-time).

[^technically]: Technically speaking, it only corresponds to the non-creation of energy, since we are interested
in an upper-bound on cost. Energy conservation means both non-creation and
non-loss of energy. Adapting the amortized analysis framework to non-loss would result in a lower-bound on cost.

[^timesensitive]: To help with this order-sensitivity, we will also from
now on consider the program state to have some notion of where it lies in
execution, like a program counter. However, this is just a technical point to
allow \\(\Phi\\) the flexibility to leverage operation order, and its exact
implementation is not important.

[^pool]: One might consider that external energy could be introduced at the
very start when a user calls on the program to execute. However, we will just
streamline this initial
payment by treating it as part of the energy assigned 
to the initial program state.

[^corollary]: As a corollary, since the amortized cost payments are gone,
we also find that the potential of the initial
state bounds the peak cost. This is more useful to measure resources like memory.

[^python]: By pseudo-code I mean python.

[^Bell]: For those with a physics background, you might consider this our version of a [Bell test](https://en.wikipedia.org/wiki/Bell_test).
In physics, this is a case proving that *local realism* is incompatible with
quantum quantum mechanics; in our setting, it is a case proving that
purely local potential is insufficient for a tight cost analysis.

[^neg]: This return of energy is modeled in our framework simply by letting \\(C\\) return negative costs.

[^copy]: Copying is only really needed in this code if `process1` or `process2` might mutate the underlying list. However,
the pertinent features of code pattern also come up in side-effect free settings during, e.g., tree traversal.
See [here](https://dl.acm.org/doi/abs/10.1145/3473581).

[^overpay]: Well, technically a worldview could choose to overpay for the cost too.

[^detail]:This sets up our worldviews to begin looking somewhat like
states in [quantum superposition](https://en.wikipedia.org/wiki/Quantum_superposition).
Both are collections of simultaneous classical-looking states, just with negative
values allowed where they usually wouldn't be. In quantum physics, those values are
probabilities; in our setting, they are potentials.

[^whole]: While only a technical point here, the consequences of
allowing the accumulation of negative potential in some parts of the
program state does
provide another quantum physical parallel. Two famous no-go theorems of 
quantum physics, [*no-cloning*](https://en.wikipedia.org/wiki/No-cloning_theorem) 
and [*no-deleting*](https://en.wikipedia.org/wiki/No-deleting_theorem), mean 
that a quantum state cannot simply duplicate or delete one of its pieces. These 
same principles are relevant to the progam states of the quantum physicist's method: We cannot 
simply duplicate potential when copying a datastructure, nor may we simply lose potential
when deleting/ignoring a datastructure. Either case could
introduce extra potential, when positive amounts are duplicated or negative amounts
are lost, which would violate conservation.

[^qt]: We call this particular way of accounting for how to get around the barrier of the vending machine
"resource tunneling", because it is analagous to 
[quantum tunneling](https://en.wikipedia.org/wiki/Quantum_tunnelling) 
around a potential barrier. In quantum physics, this occurs because a 
particle's position (or energy, depending on what you measure) is in a 
superposition of many states, a small portion of which allow being on the
other side of the potential barrier; in our setting, it is because potential 
is tracked through the collection of worldviews, at least one of which is 
sufficient to pay for the potential needed. In either case, there may be no
one state of the collection that can explain the tunneling; no state that, 
if tracked individually from the start, could pass the potential barrier.
