+++
# The title of your blogpost. No sub-titles are allowed, nor are line-breaks.
title = "Verus: A tool for verified systems code in Rust"
# Date must be written in YYYY-MM-DD format. This should be updated right before the final PR is made.
date = 2023-08-03

[taxonomies]
# Keep any areas that apply, removing ones that don't. Do not add new areas!
areas = ["Programming Languages", "Systems"]
# Tags can be set to a collection of a few keywords specific to your blogpost.
# Consider these similar to keywords specified for a research paper.
tags = ["rust", "formal-methods", "verification"]

[extra]
# For the author field, you can decide to not have a url.
# If so, simply replace the set of author fields with the name string.
# For example:
#   author = "Harry Bovik"
# However, adding a URL is strongly preferred
author = {name = "Travis Hance", url = "https://www.andrew.cmu.edu/user/thance/" }
# The committee specification is simply a list of strings.
# However, you can also make an object with fields like in the author.
committee = [
    "Jonathan Aldrich",
    "Ruben Martins",
    "Isaac Grosof"
]
+++

Part of the challenge (and fun) of low-level systems code is in the optimizations they employ:
developers might use manual memory management, they might use bit-packing and bit-twiddling optimizations,
or they might use multi-threading to speed up their code.
When dealing with such things for critical software, though, it can be difficult to ensure their correctness.
This is why my research group is interested in the formal verification of systems software:
ensuring through computer-checked mathematical proofs that software does what it is supposed to,
and ideally not compromising on these optimizations.

For this purpose, we have been developing [Verus](https://github.com/verus-lang/verus),
a verification tool for [the Rust programming language](https://doc.rust-lang.org/stable/book/).
Rust is increasingly popular as a systems programming language today,
but we didn't (just) choose it because of its popularity.
Rather, it turns out that the properties that make it attractive as a systems programming language---most notably,
that it allows manual memory management while simultaneously guaranteeing memory-safety---_also_ make it excellent
in the setting of formal verification: in some ways straightforward,
and in some ways surprising. In this blog post, I'll explain what these ways are.

# Verification, mutable memory, and Rust 

First, we're interested in proving code to be "correct". What does that mean exactly?
Let's get our feet wet in verification with some simple examples and then talk about a challenge that Rust helps us solve.

## Intro to Verus

The key idea behind Verus is to check additional properties of programs that Rust doesn't check on its own.
For example, consider the following valid Rust program, operating over an 8-bit integer.

```rust
fn double(i: u8) -> u8 {
    return i * 2;
}
```

Though it's a valid program, it (potentially) has a problem: if the argument `i` is more than 127, then the multiplication will overflow the 8-bit integer.
If you run Verus on it (which you can [try yourself at the Verus playground](https://play.verus-lang.org/?version=stable&mode=basic&edition=2021&code=use+vstd%3A%3Aprelude%3A%3A*%3B%0A%0Averus%21+%7B%0A%0A++++fn+double%28i%3A+u8%29+-%3E+u8+%7B%0A++++++++return+i+*+2%3B%0A++++%7D%0A++++%0A%7D%0A%0Afn+main%28%29+%7B%7D%0A%0A)),
Verus reports this error:

```
error: possible arithmetic underflow/overflow
 --> /playground/src/main.rs:6:16
  |
6 |         return i * 2;
  |                ^^^^^
```

To remedy this, the programmer can declare their _intent_: namely, that the `double` function should never be called with any argument greater than 127.

<pre data-lang="rust" style="background-color:#393939;color:#dedede;" class="language-rust "><code class="language-rust" data-lang="rust"><span style="color:#fffb9d;">fn </span><span style="color:#fffd87;">double</span><span>(i: </span><span style="color:#fffb9d;">u8</span><span>) -&gt; </span><span style="color:#fffb9d;">u8
</span><span>    requires i &lt;= 127
</span><span>{
</span><span>    return i </span><span style="color:#ececec;">&#x2a; </span><span style="font-weight:bold;color:#87d6d5;">2</span><span>;
</span><span>}
</span></code></pre>

The `requires` clause is not a standard Rust feature, but a feature of Verus: in general, Verus source code comprises both Rust code and extra directives for Verus, such as this
`requires` clause, also known as a _precondition_. In any case, Verus now accepts the program ([playground link](https://play.verus-lang.org/?version=stable&mode=basic&edition=2021&code=use+vstd%3A%3Aprelude%3A%3A*%3B%0A%0Averus%21+%7B%0A%0A++++fn+double%28i%3A+u8%29+-%3E+u8%0A++++++++requires+i+%3C%3D+127%0A++++%7B%0A++++++++return+i+*+2%3B%0A++++%7D%0A++++%0A%7D%0A%0Afn+main%28%29+%7B%7D%0A%0A)) because with the new assumption, Verus can determine that this arithmetic operation never overflows.

Furthermore, any time the developer calls `double` from elsewhere in the program, Verus will check that the call satisfies the precondition.
Keep in mind, also, that this is a check done statically, checked for all possible executions of the program, not a runtime check.

## Specifications and program correctness

With Verus, we are actually interested in correctness criteria that go beyond simple arithmetic bounds checks.
Usually, we are interested in proving that a program's behavior meets some _specification_, as in this function that computes the maximum of two integers:

```rust
fn max(a: u64, b: u64) -> (result: u64)
    ensures
        result == a || result == b,
        result >= a,
        result >= b,
{
    if a > b {
        return a;
    } else {
        return b;
    }
}
```

Again, let's highlight the Verus-specific parts:
first, we have the `ensures` clause (also known as a _postcondition_) serving as the function's specification, along with the name `result` on the return type,
which is referenced from said postcondition.
Once again, the body of the `max` function is the Rust code we are verifying.

The `ensures` clause denotes a predicate that should hold true at the end of the call to `max`.
This determines what it means for an implementation of `max` to be "correct": it is correct if every execution of its code
returns a result that meets its specification.

So, how does Verus actually check that this property holds?
To do this, Verus (and similar tools) encode the correctness of `max` as logical formulae called _verification conditions_:

\\[ a > b \implies result = a \implies (result = a \lor result = b) \land (result \ge a) \land (result \ge b) \\]

\\[ \lnot(a > b) \implies result = b \implies (result = a \lor result = b) \land (result \ge a) \land (result \ge b) \\]

These conditions are simplified a bit for presentation, but they are close enough for intuition.
The first of these would be read as, "if \\( a < b \\) (i.e., the first branch is taken), and if \\( result \\) is set to the return value \\( a \\), then the conditions of
the ensures clause hold". The second condition is similar, but for the `else` side of the branch.

If we prove the verification conditions are correct, this implies the correctness of the program according to its specification.
To do so, Verus uses an automated theorem prover---in this case, [Z3](https://github.com/Z3Prover/z3)---to prove the verifification conditions hold for all
values of _a_, _b_, and _result_. This example is simple enough that Z3 can validate the conditions quickly, though for more complicated examples, the developer may need to write additional proofs
to help it out. If Z3 is unable to prove the theorem, either because it is wrong, or because it needs additional help to prove, then Verus outputs an error message like the one from
the previous section.

Specification-checking is extremely useful for situations where an implementation is optimized and handles low-level details, but we would like to provide a higher-level, mathematically precise specification.
For example:

 * A program uses the bitwise operation `(x & (x - 1)) == 0` to determine if `x` is a power-of-2, but uses a more mathematically precise specification, \\( \exists b.~ 2^b = x \\).
 * A data-structure implements a hash table or a red-black tree, but has a specification stating that its operations are equivalent to those of a mathematical set.
 * A replicated data structure with a sophisticated synchronization algorithm uses a specification that it acts indistinguishably from a single copy of the data structure.

## Challenge: handling mutable memory

One such "low-level detail" we often have to reason about is _mutable heap state_.
To see why this is challenging without Rust's help, let us set aside Rust for a moment,
and imagine we designed a programming language with general pointer types, like in C.
Consider a simple function that takes two pointers and updates one of them:

```c
// Imagined C-like verification language
void compute_boolean_not(bool* x, bool* x_not)
    ensures (*x_not) == !(*x)
{
    bool tmp = *x;
    *x_not = !tmp;
}
```
This program looks straightforward at first, but it actually has a problem: what if `x` and `x_not` point to the same memory?
Then `*x` would be updated when we update `*x_not`. Therefore, a tool would never be able to prove this code matches its specification---it simply isn't true.

![Visual representation of the above example](compute_boolean_not_graphical.png)
<p align="center"><i><b>Left:</b> what the developer imagines happening. <b>Right:</b> what might actually happen.</i></p>

One solution is to specify that the pointers do not _alias_ with each other, i.e., that they don't point to the same memory location:

```c
// Imagined C-like verification language
void compute_boolean_not(bool* x, bool* x_not)
    requires x != x_not        // This line has been added
    ensures (*x_not) == !(*x)
{
    bool tmp = *x;
    *x_not = !tmp;
}
```

Recall the `requires` clause here indicates an assumption the function can make at the beginning of its execution.
By making this assumption, Verus can now check that the specification holds, although now every call to `compute_boolean_not`
will need to uphold this contract.

Unfortunately, adding these "non-aliasing conditions" gets unwieldy fast, as data structures increase both in breadth and depth.
This was our experience when we wrote the first version of [VeriBetrKV](#further-reading), a key-value store developed in [Dafny](https://dafny.org/), which has a similar aliasing situation to our C-like language.
Not only were the conditions difficult to write manually, but getting them wrong often led to error messages that were difficult to diagnose.

## Rust to the rescue

In Rust, it isn't common to use general-purpose pointer types. Instead, Rust uses more restricted [_reference_ types](https://doc.rust-lang.org/book/ch04-02-references-and-borrowing.html). In Rust, the types `&T` and `&mut T`
each denote a reference to a value of type `T`.
In the case of `&mut T`, which is specifically a _mutable_ reference, the user is able
to modify the value behind the pointer.
Thus, in Rust/Verus, our boolean-negation example would look like this, with the `x_not` parameter marked as a mutable reference.

```rust
fn compute_boolean_not(x: &bool, x_not: &mut bool)
    ensures (*x_not) == !(*x)
{
    let tmp: bool = *x;
    *x_not = !tmp;
}
```

At the machine code level, these references are just like pointers, but the Rust type system enforces additional properties: namely, a `&mut` reference to a piece of data can never coexist 
with another reference to that data. Rust enforces this property because it is crucial to Rust's guarantees about memory safety.

However, this property is also a huge boon for software verification. Because the non-aliasing property is checked by Rust's type system,
the developer no longer has to write the non-aliasing conditions
manually. Furthermore, Rust's type system is fast and often presents high-quality error messages when the property is violated.

One can think of this as if these non-aliasing conditions are 
inserted automatically, so the developer doesn't have to worry about it, but in fact, the situation is even better: the verification tool can simplify the verification conditions to not include any
notion of pointer addresses in the first place! In fact, some of my colleagues have [published a paper](#further-reading) quantifying the gains from this kind of simplification.

# Are reference types all we need?

The fact that Rust works as a language at all is evidence that reference types are sufficient
_most_ of the time. Unfortunately, most of the time isn't good enough. The non-aliasing
reference problem gets in the way for implementing any of the following:

 * Doubly-linked lists
 * Reference-counted pointers (e.g., Rust's [`Rc`](https://doc.rust-lang.org/std/rc/struct.Rc.html), similar to C++'s `shared_ptr`)
 * Any manner of concurrent algorithm: locks, message-passing queues, memory allocators, systems with domain-specific logic for avoiding data races

The reason these examples give difficulty is because Rust's type system enforces that any object have a unique "owner" (unless those owners are immutable references).
However, these examples seemingly need to violate the restriction:

![Visual representation of a doubly-linked list. Each node has two incoming pointers from its neighbors, and two outgoing pointers to its neighbors.](dlist.png)
<p align="center"><i>In a doubly-linked list, each node has two neighbors which point to it. Thus, these nodes do not have unique owners.</i></p>

![Visual representation of reference-counted smart pointer, Rc. The shared object has multiple reference objects pointing to it.](rc.png)
<p align="center"><i>When working with reference-counted smart pointers, each object may have multiple reference objects. These objects need to coordinate via the reference count to drop the given object at the appropriate time. This counter does not have a unique owner.</i></p>

![Visual representation of message-passing queue. The producer thread and the consumer thread each have a pointer to a shared queue buffer.](queue.png)
<p align="center"><i>In a message passing queue, the producer thread and the consumer thread have to share a queue buffer to store in-flight messages. This buffer does not have a unique owner.</i></p>

So how can we tackle these kinds of problems?

For such things, Rust programmers need to use Rust's notorious ["unsafe code"](https://doc.rust-lang.org/stable/book/ch19-01-unsafe-rust.html) which opts in to various Rust features that 
the type system is unable to validate are used safely. As such, the burden goes from the
type-checker to the programer to ensure they are used correctly.
Applications like the above are generally considered low-level, and they are often
relegated to time-tested libraries. It's these kinds of low-level systems, though,
that we are especially interested in verifying! So what do we do?

## Unsafe code in Verus, or: "condititionally safe code"

With Verus, we can recover the ability to implement such things while having a computer-checked guarantee of memory safety.
A Rust feature being  "unsafe" really just means that the developer has to uphold a certain contract to use it safely, which Rust cannot check.
It is for this reason that I like to call unsafe code _conditionally safe_---i.e., it is safe subject to meeting
certain conditions. Rust cannot check these conditions, but Verus _can_.

Here is a simple example: Rust's common vector indexing operation performs a bounds-check to ensure there is no memory corruption from an out-of-bounds access.
Therefore, this function is _unconditionally_ "safe" to call, no matter what index the caller provides: even if the caller provides something out-of-bounds, the program might panic and exit, but it will never corrupt memory.
However, there is a lesser-used [`get_unchecked`](https://doc.rust-lang.org/std/vec/struct.Vec.html#method.get_unchecked) operation which performs _no_ such bounds check.
Thus, `get_unchecked` is only safe to call if the index is
_already known to be in-bounds_, thus making it unsafe (conditionally safe).
This condition can be codified as a Verus `requires` clause:

```rust
unsafe fn get_unchecked<T>(vec: &Vec<T>, idx: usize) -> &T
    requires idx < vec.len()
    ...
```

Now, Verus will check that the index is in-bounds whenever `get_unchecked` is called.
Thus, we can regain assurance in code that uses this function, provided that Verus is able to validate the code.

## Handling unsafe ownership

Bounds-checking makes for an easy example, but when we consider programs like the ones
diagrammed above, the situation gets a little more complicated.
Recall that what characterizes these systems is that the objects may be pointed to
from multiple owners, which have to coordinate their access somehow.

As a result, the "conditions" of the conditionally safe operations become
substantially more involved. For example, accessing data through a pointer is only safe if there is no
_data race_, i.e., another thread trying to access it at the same time. Such a condition seems inherently "non-local" as it involved talking about all threads at once,
and therefore is much harder to check than that of a simple index being in bounds.

However, we have already discussed that Rust's type system allows us to ensure the unique ownership of data, which then rules out illegal operations such as data races.
Therefore, the kind of "condition" we need to check is already the exact kind of condition that Rust's type system is designed to ensure.
The problem here is just that these particular data structures do not use the specific types that are designed to ensure this. So how can we apply Rust's philosophy anyway?

Since the data structures we want to verify use objects that don't obey Rust's unique ownership, our trick is to add _new_ objects that _do_.
However, we don't want to bog down the program with extra data---that would defeat the point of writing optimized code---so these new objects are merely "conceptual proof objects."
In verification languages, such objects are often called _ghost_ objects, not because they are spooky, but because they have no influence on the "physical world." The real data structures in the compiled binary
would be the ones diagramed above, but Verus treats the program as if the ghost objects were really there when generating its verification conditions.

For example, for a program that uses pointers, Verus programs can use a ghost object that represents "the right to read or write memory from the given location."
Just like for ordinary ("real") data, Rust's type system ensures that ownership this object is unique. Verus in turn ensures that such an object is 
present when the program accesses the data behind the pointer. Combining both results, we can be confident that such an access really is data-race-free.
Even while multiple owners might point to the same piece of data, in the sense of physically having a pointer to it, only one owner at a time can have the _right_ to manipulate that data.

To verify a doubly-linked list, then, we would arrange nodes with pointers in the usual way, but in addition to the "real" nodes, we would have an additional collection of ghost objects
that represent the right to access those nodes. By writing additional Verus annotations, we can explain, mathematically, how these ghost objects relate to the structure of the linked list,
and as a result we can use the ghost objects to traverse the list.
For more details, you can see [our paper](#further-reading), where we present the doubly-linked list in detail.

# Further reading {#further-reading}

There is currently one paper on Verus available, which introduces Verus and works out
the doubly-linked list example in detail, among others. (If you compare to this blog post,
you may notice Verus' syntax has evolved a bit since this paper was written.)

[Andrea Lattuada, Travis Hance, Chanhee Cho, Matthias Brun, Isitha Subasinghe, Yi Zhou, Jon Howell, Bryan Parno, and Chris Hawblitzel. _Verus: Verifying Rust Programs Using Linear Ghost Types._ (OOPSLA 2023)](https://arxiv.org/abs/2303.05491)

Before Verus, we explored this space of verification techniques through a language
we developed called _Linear Dafny_, an extension of the verification langauge [Dafny](https://dafny.org/). Verus incorporates a lot of our
learnings from Linear Dafny, which there are several papers on.
We first introduced Linear Dafny in this paper on VeriBetrKV, a verified key-value store:

[Travis Hance, Andrea Lattuada, Chris Hawblitzel, Jon Howell, Rob Johnson, and Bryan Parno. _Storage Systems are Distributed Systems (So Verify Them That Way!)._ (OSDI 2020)](https://www.usenix.org/system/files/osdi20-hance.pdf)

Some of my colleagues quantified the utility of Linear Dafny's type system via direct comparison:

[Jialin Li, Andrea Lattuada, Yi Zhou, Jonathan Cameron, Jon Howell, Bryan Parno, and Chris Hawblitzel. _Linear Types for Large-Scale Systems Verification._ (OOPSLA 2022)](https://homes.cs.washington.edu/~jlli/papers/oopsla2022.pdf)

Finally, we explored the combination of ghost objects and ownership types to verify
some sophisticated concurrent systems in a Linear Dafny framework called IronSync:

[Travis Hance, Yi Zhou, Andrea Lattuada, Reto Achermann, Alex Conway, Ryan Stutsman, Gerd Zellweger, Chris Hawblitzel, Jon Howell, and Bryan Parno. _Sharding the State Machine: Automated Modular Reasoning for Complex Concurrent Systems._ (OSDI 2023)](https://www.usenix.org/system/files/osdi23-hance.pdf)

# Related work

Verus is far from the only Rust verification tool around.
[RustBelt](https://plv.mpi-sws.org/rustbelt/popl18/) is a framework for verifying unsafe code within a precise mathematical formalism of a model of the Rust langauge.
It is notable because it can prove general memory-safety theorems about Rust's type system, even in the presence of libraries that use unsafe code.
However, it does not take _advantage_ of Rust's type system for the sake of verification, and it doesn't target developers writing actual Rust code.

Other tools which, like Verus, target developers include [Prusti](https://www.pm.inf.ethz.ch/research/prusti.html),
[Kani](https://github.com/model-checking/kani),
[Aeneas](https://arxiv.org/abs/2206.07185),
and [Creusot](https://github.com/xldenis/creusot).
Of these, the one most similar to Verus is likely Creusot, which takes advantage of the Rust type system in a similar way to generate simple verification conditions.
Creusot is also notable for its "prophecy encoding" of mutable references, which is more general than Verus' current mutable reference support.
What distinguishes Verus, by contrast, is its support for these ghost objects and especially their use in concurrency.

# Conclusion

Rust's type system, and similar type systems that enforce unique ownership over data,
are enormously helpful in designing a verification language for low-level code.
Just as Rust guarantees memory safety, thus taking the burden off the developer in the common case, 
Verus takes advantage of the same to remove the burden of complex aliasing conditions for verification developers.
More surprisingly, though, we can apply Rust's type system even for code that initially seems very un-Rust-like, which is common in highly-optimized systems code.
Specifically,
by utilizing ghost objects
we recover the ability to use Rust's ownership system
(together with Verus to check conditionally safe code)
to check code where the type system would not help in ordinary Rust.
