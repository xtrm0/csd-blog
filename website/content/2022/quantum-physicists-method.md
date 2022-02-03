+++
# The title of your blogpost. No sub-titles are allowed, nor are line-breaks.
title = "The Quantum Physicist's Method of Resource Analysis"
# Date must be written in YYYY-MM-DD format. This should be updated right before the final PR is made.
date = 2022-01-31

[taxonomies]
# Keep any areas that apply, removing ones that don't. Do not add new areas!
areas = ["Programming Languages", "Theory"]
# Tags can be set to a collection of a few keywords specific to your blogpost.
# Consider these similar to keywords specified for a research paper.
tags = ["quantum-physicists-method", "physicists-method", "resource-analysis", 
"amortized", "AARA", "types", "type-system", "linear", "affine", "intersection"]

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
how to actually bookkeep the messy situations that occur in general program
analysis. This post explains how to fill in these gaps to
get the *quantum* physicist's method, a refinement of the physicist's method
that is robust enough for automatic program analysis, as in 
my paper [here](https://dl.acm.org/doi/abs/10.1145/3473581). (Quick disclaimer: There is
no quantum computing in here, despite the name.)

# The Classical Physicist's Method

Think back to your highschool physics class where you learned about energy. If you hold a 1 kilogram ball
1 meter above the Earth, it has \\(1\mathsf{kg} * 9.81\frac{\mathsf{m}}{\mathsf{s}^2} * 1 \mathsf{m} = 9.81 \mathsf{J}\\) 
units of gravitational potential energy stored up. When it reaches the ground, it has none.
Thus (neglecting friction), all potential energy has been
converted into the ball's speed, so solving for
\\(v\\) in the conversion between energy and speed
\\(9.81\mathsf{J} = \frac 1 2 * 1\mathsf{kg} * (v \frac{\mathsf{m}}{\mathsf{s}})^2 \\) gives
\\( 4.43\frac{\mathsf{m}}{\mathsf{s}}\\) as the speed of the ball at ground level. And it doesn't matter
whether this ball quickly dropped straight down, or slowly made its way down a long ramp - the speed at the ground will be
the same because the energy is conserved.

This simple idea of energy conservation has been central to physical reasoning since the 1700s when it was first
proposed by Émilie du Châtelet. By now, it is probably taken for ganted just how
much bookkeeping this idea cuts through. You don't need to track every transfer energy
between each little component of your system, how much time it took, or really anything that happened along the way -
all you need to know is the energy at the start and at the end. Formally, to reason about
the energy expenditure of a physical system over some time period, all you need to
do is look at the system's initial potential energy \\(\Phi(S_{\mathsf{init}}) \\) and ending potential energy  \\(\Phi(S_{\mathsf{end}})\\),
and then take the difference.
Because the total amount energy is always conserved, you know that exactly \\(\Phi(S_{\mathsf{init}}) - \Phi(S_{\mathsf{end}}) \\)
units of potential energy has been spent.

It wasn't until the 80s that this same reasoning principle made its way to computer science. Robert Tarjan
and Danny Sleator introduced it to define
*amortized* algorithm costs (see [here](https://epubs.siam.org/doi/pdf/10.1137/0606031?casa_token=cR8nppnD8MQAAAAA%3AgK8XhJzUtPvkIVXTHIe299HSRuczuwiYVM74VDBjOMpHDlLcZLIVlziYWpRQMHeuN3lz84b9kIUg&)).
However, the idea of amortization itself is much older, and comes from the financial industry.
Amortization is used to express a notion of average cost where occasional
spikes of high cost are prepaid over longer periods of time, like paying off a loan
in installments instead of all at once at the due date. However, if we think about this
prepayment as storing extra potential energy for later, the reasoning becomes exactly the
same as reasoning about conservation of energy. Hence, Tarjan and Sleator suggest
calling the approach "the physicist's method".

To see how this all comes up in the analysis algorithms, consider implementing an arbitrarily sized list using
fixed-size arrays[^1]. In particular, lets look at the list's insertion function, and measure its
cost in how many array insertion it uses. The list insertion function will usually just be able to directly insert a new
element into the next unused slot in the array, for a cost of 1 insertion. But eventually, the array will be full with no unusued slots.
When this happens, our implementation will:

1. allocate a new array double the size of the old one
2. insert all the elements from the old array into the new one
3. insert the new element into the next empty space of the new array

Unlike the common case using a single array insert, readjusting the array in
this case uses an insert for each element in the old array to move it to the new one. The worst case cost
of insertion is therefore equal to the length of the list plus one, which is a far cry from the usual constant
cost.

Nonetheless, we can show that the amortized cost of insertion is still constant by prepaying for this readjustment.
To do so, we define a suitable *potential* function \\(\Phi\\) giving the amount of potential energy stored in the 
program state. Specifically, \\(\Phi(A)\\) will give twice the number of elements past the halfway point in the array \\(A\\).
You can think of this like each element past the halfway point coming with a 2-charge battery to store potential energy.
The amortized cost of an operation is then defined as the difference in potential induced by that operation plus its true cost,
\\(\Phi(A_{\mathsf{init}}) - \Phi(A_{\mathsf{end}}) + C_{\mathsf{true}}\\).
If we account for this potential energy alongside our normal costs, suddenly the cost profile becomes much smoother:

* In the common case, we still pay the true cost for the 1 insertion, but now might also need to pay 2 more to "charge the batteries"
if the element is past the halfway point in the array, accounting for any change in potential. In the worst case, the total amortized cost is therefore 3.

* In the uncommon case, our array is now full. Thus, we have stored 2 units of potential with half the elements in the array,
which works out to one unit of potential for each element. This potential can pay for each element's insertion into the new array.
The new array itself then has no potential, because it is exactly half full. This means that the true cost of the readjustment
is all paid for out of the stored potential energy, exactly exactly cancelling each other. Then after the readjustment,
list insertion behaves like its common case again, accruing a worst-case amortized cost of 3.

Thus, through mediating energy expenditure with potential, we find that
insertion into these array-backed lists takes amortized constant time. The magic
happened when we discovered that our choice of potential function \\(\Phi\\)
caused us to prepay exactly the amount necessary for our burst of cost during readjustment.

In general, the key theorem of the physicist's method is as follows:

> Given:
> * a set of operations \\(\mathsf{op} = \mathsf{state} \rightarrow \mathsf{state} \\)
> * a true cost function \\(C : \mathsf{state} \times \mathsf{op} \rightarrow \mathbb{R}\\)
>
> If you can find:
> * a potential function \\(\Phi : \mathsf{state} \rightarrow \mathbb{R}_{\geq 0}\\) 
> * amortized cost \\(a_o\\) for each operation \\(o\\)
>
> such that \\(\Phi(S) + a_i \geq \Phi(o_i(S))  + C(S, o_i)\\)
>for any state \\(S\\),
>
> Then for any sequence of \\(n\\) operations \\((o_i)\\) and the sequence of states they induce \\((S_i)\\):
>
> \\[\sum_{i=0}^{i<n} a_{o_i} + \Phi(S_{0})  - \Phi(S_{n+1}) \geq \sum_{i=0}^{i<n} C(S_i, o_i)\\]
>
> i.e., the total amortized cost plus change in potential covers the total true cost.

<p></p>

As a corrollary, if the initial potential \\(\Phi(S_0)\\) happens to be 0, then the total amortized cost by itself
always bounds the total true cost.

# The Gaps 

In the above formalization, you might notice that the form of the potential function \\(\Phi\\) is left abstract.
The function *could* be any sort of complicated, non-uniform, ugly function. But, it is no coincidence that
the \\(\Phi\\) we chose in our above example was "nice". Specifically, this "niceness" amounts to potential being
*local* - one think of the state \\(S\\) as broken up into many pieces (our array elements), each with their own local amount of potential (our "batteries"), and then \\(\Phi\\) just gives the sum of potential stored on these different pieces.
In fact, this is exactly how Tarjan suggested amortized analysis to be rationalized:

>In order to keep track of saved or borrowed credits, it is generally convenient to
store them in the data structure. ... It is important to
realize that this is only an accounting device; the programs that actually manipulate
the data structure contain no mention of credits or debits.

--[Tarjan](https://epubs.siam.org/doi/pdf/10.1137/0606031?casa_token=cR8nppnD8MQAAAAA%3AgK8XhJzUtPvkIVXTHIe299HSRuczuwiYVM74VDBjOMpHDlLcZLIVlziYWpRQMHeuN3lz84b9kIUg&)

Initially, this idea of localized potential is rather straightforward to adapt into a program analysis system. The type of a data
structure can include some annotation indicating how much potential it stores where. This eventually leads
to the type system called Automatic Amortized Resource Analysis (AARA), which automatically
infers the required potential annotations, giving cost bounds in the process. (See [here](https://dl.acm.org/doi/pdf/10.1145/640128.604148) for its origin and [here](https://www.raml.co/) for an up-to-date implementation.)

This localized-potential approach often works rather well for clean, focused algorithms. However,
it is not hard to confound when put into a greater programming context, connecting many algorithms
with control flow. Consider a setting with 2 of our array-backed lists being used to partition and store data.
When the program goes to store some data, some code (e.g. `shouldGoToList1`) decides which list the data should
be stored in, and then it gets stored there.

```python
def store(data, list1, list2):
    if shouldGoToList1(data):
        list1.insert(data)
    else:
        list2.insert(data)
```

Clearly, only one insertion occurs, so the amortized cost should still be 3. However, this is
nonlocal reasoning, since it makes no reference to which list the potential is being stored
with. And in fact, there is in general
no way to statically know which list `shouldGoToList1` selected for the data - it is *undecidable*.
This confounds our local method of accounting, since it must store potential in a specific list,
but cannot say which list will end up holding the data. At best, it might overapproximate the
worst case, and give the cost bound of 6 for inserting into *both* lists. And while this bound is loose
by only the constant factor of 2, other examples can loosen the bound to be exponentially worse
(like binary search [here](https://dl.acm.org/doi/abs/10.1145/3473581)).

But the situation is actually worse than simply not knowing which localization of potential to pick.
We can actually create an example where *no* localization suffices, even while nonlocal reasoning 
makes a solution obvious.

# The Quantum Physicist's Method


[^1]: This list would be the data structure called [`ArrayList` in Java](https://docs.oracle.com/javase/8/docs/api/java/util/ArrayList.html)
and [`vector` in C++](https://www.cplusplus.com/reference/vector/vector/), and probably underlies a lot of other list implementations too.