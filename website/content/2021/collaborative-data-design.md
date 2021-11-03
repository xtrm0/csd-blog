+++
# The title of your blogpost. No sub-titles are allowed, nor are line-breaks.
title = "Designing Data Structures for Collaborative Apps"
# Date must be written in YYYY-MM-DD format. This should be updated right before the final PR is made.
date = 2021-11-01

[taxonomies]
# Keep any areas that apply, removing ones that don't. Do not add new areas!
areas = ["Programming Languages", "Systems"]
# Tags can be set to a collection of a few keywords specific to your blogpost.
# Consider these similar to keywords specified for a research paper.
tags = ["collaborative apps", "data structures", "CRDTs", "eventual consistency"]

[extra]
# For the author field, you can decide to not have a url.
# If so, simply replace the set of author fields with the name string.
# For example:
#   author = "Harry Bovik"
# However, adding a URL is strongly preferred
author = {name = "Matthew Weidner", url = "http://mattweidner.com/" }
# The committee specification is simply a list of strings.
# However, you can also make an object with fields like in the author.  TODO
committee = [
    "Committee Member 1's Full Name",
    "Committee Member 2's Full Name",
    {name = "Harry Q. Bovik", url = "http://www.cs.cmu.edu/~bovik/"},
]
+++

# Introduction

Suppose you're building a collaborative app, along the lines of Google Docs/Sheets/Slides, Figma, Notion, etc. One challenge you'll face is the actual collaboration: when one user changes the shared state, their changes need to show up for every other user. For example, if multiple users type at the same time in a text field, the result should reflect all of their changes and be consistent (the same for all users).

An easy solution would use a server for all operations. When a user wants to make a change, like typing a letter, they send a request to the server. The server processes their request, updates its copy of the state, and sends a description of the update to all users. All users then update their view of the state to reflect this change, including the original typer.

This solution is simple, works for any kind of data, and trivially ensures that all users see a consistent state. However, it is slow: between the user performing an operation (e.g. a key press) and seeing its effect, they must wait for a round-trip to the server, which could take several 100 ms. Meanwhile, users notice latency starting at around TODO ms. Also, if you're not careful, users might see weird behavior, like their text ending up in the wrong place because someone else typed in front of them.

TODO: gif/something?: typing in ssh.  "Like typing into a sluggish ssh instance."

You can't fix the latency the usual way---using multiple servers around the world so every user has one close by---because all users editing the same document must use the same server. And of course, this server-first solution doesn't work offline or keep user data private.

## CRDTs: Data Structures for Collaborative Apps

*Conflict-free Replicated Data Types (CRDTs)* provide an alternative solution. These are data structures that look like ordinary data structures (maps, sets, text strings, etc.), except that they are collaborative: when a user updates their copy of a CRDT, their changes automatically show up for everyone else. Unlike with the above server-first solution, a user's local copy of a CRDT updates immediately when they make a change. The CRDT then syncs up with other users' copies in the background, eventually informing them of the change.

TODO: example/diagram (from talk?)

TODO: also network-agnostic (open source-able?), works offline, E2EE - link to local-first blog post. Also mention Collabs, link to demos.

TODO: difficulty: designing. Main goal is eventual consistency (correctness), proved with commutativity or as function of operation history DAG (illustrate, show hardness be referencing e.g. spreadsheet?). But it's not always clear *how* a CRDT resolves conflicts (semantics), i.e., what happens in a given situation. Might not be what you expect; hard to modify if not an expert. E.g. semidirect - can make things we don't understand semantically.

TODO: this post goals: explain existing designs in terms of a few simple principles, can be understood without any nontrivial proofs. "(Op-based) CRDTs in N minutes." Give confidence to tweak or make your own. Necessary if making your own app so you can make it do what you want, respond to user requests. Illustrative pic: user asking for a fix (e.g. moving a column while editing a cell), dev responding sorry. Cite Figma blog post?

# Basic Designs

## Unique Set

Our foundational CRDT is the **Unique Set**.  It is a set in which each added element is considered unique.

Formally, the operations on the set are:
- $add(x)$: Adds an element $e = (x, t)$ to the set, where $t$ is a unique new tag, used to ensure that $(x, t)$ is unique. The adding user generates $t$ (see below), then serializes $(x, t)$ and broadcasts it to the other users.  The receivers deserialize $(x, t)$ and add it to their local copy.
- $delete(e)$: Deletes the element $e = (x, t)$ from the set.  The deleting user serializes $t$ and broadcasts it to the other users.  The receivers deserialize $t$ and remove the element with tag $t$ from their local copy, if it has not been deleted already.

When viewing the set, you ignore the tags and just list out the data values $x$, keeping in mind that (1) they are not ordered (at least not consistently across different users), and (2) there may be duplicates.

> **Example.** In a flash card app, you could represent the deck of cards using a unique set, using $x$ to hold the flash card's value (e.g., its front and back strings). Users can edit the deck by adding a new card or deleting an existing one, and duplicate cards are allowed. Note that we have no info about the order of cards; you could perhaps sort them alphabetically in editing mode, and randomly (independently for each player) in practice mode.

It is obvious that the state of the set, as seen by a specific user, is always the set of elements for which they have received an $add$ message but no $delete$ messages. This holds regardless of the order in which they receive concurrent messages. Thus the unique set is a CRDT.

> Note that causally ordered delivery is important---delete operations only work if they are received after their add operations.

We now have our first principle of CRDT design:

**Principle 1.** Use the unique set CRDT for operations that "add" or "create" a unique new thing.

Although it is simple, the unique set forms the basis for the rest of our CRDT designs.

> **Remark.** There is a sense in which the unique set is "CRDT-complete", i.e., it can be used to implement any CRDT semantics. TODO.  Formally causal+ consistency.

### Generating Unique Tags

As part of the unique set algorithm, we need a way to generate a unique tag $t$ for each added element. Users cannot coordinate in generating the tag, so a simple counter won't work.  Instead, we use a pair $(id, k)$, where:
- $id$ is a unique id for the user generating the tag. This is assigned randomly when the user is created, with enough random bits that collisions between different users are unlikely. TODO: user vs replica (perhaps just use replica throughout?).
- $k$ is a counter value specific to the user.

TODO: name (Lamport id?).

## Lists

Our next CRDT is a **list CRDT**. It represents a list of elements, with "insert" and "delete" operations. For example, you can use a list CRDT of characters to store the text in a collaborative text editor, using "insert" to type a new character and "delete" for backspace.

Formally, the operations on a list CRDT are:
- $insert(x, i)$: TODO
- $delete(i)$: TODO

We now need to decide on the semantics, i.e., what is the result of various insert and delete operations, possibly concurrent. The fact that insertions are unique suggests using a unique set. However, we also have to account for indices and the list order.

One approach would use indices directly: when a user calls $insert(x, i)$, they send $x$ and $i$ to the other users, who use $i$ to insert $x$ at the appropriate location.  TODO: challenge: moving around.  Leads to OT, used by Google Docs; hard to do without server (when was first successful server-free OT algorithm?), and complicated regardless.

List CRDTs use a different perspective.  When you type a character in a text document, you probably don't think of its position as index 723 or whatever; instead, its position is at a certain place within the existing text.

TODO: figure illustrating position intuition (insert between two words).

"A certain place within the existing text" is vague, but at a minimum, it should be between the characters left and right of your insertion point (here TODO and TODO).  Also, unlike an index, this intuitive position doesn't change if other users concurrently type earlier in the document; your cursor is still between the same words as before. In other words, it is immutable.

This leads to the following algorithm.
- The list's state is a unique set whose values are pairs $(x, p)$, where $x$ is the actual value (e.g., a character), and $p$ is a *unique immutable position* drawn from some totally ordered set. The user-visible state of the list is the list of values $x$ ordered by their positions $p$.
- $insert(x, i)$: The inserting user looks up the positions $p_L, p_R$ of the values to the left and right (indices $i$ and $i+1$), generates a unique new position $p$ such that $p_L < p < p_R$, and calls $add((x, p))$ on the unique set. 
- $delete(i)$: The deleting user finds the element $e$ of the unique set at index $i$, then calls $delete(e)$ on the unique set.

Of course, to implement this, we need a totally ordered set with the ability to create a unique new position in between any two existing positions. This is the hard part (the hardest part of CRDTs overall, in my opinion), and we don't have space to go into it here.  Generally, they involve a tree, sorted by the tree walk on nodes; you create a unique new position in between $p_L$ and $p_R$ by adding a new leaf somewhere between $p_L$ and $p_R$, e.g., as a right child of $p_L$.

The important lesson here is that we had to translate indices (the *lingua franca* of normal, non-CRDT lists) into immutable positions (what the user actually means when they say "insert here").  This leads to our second principle of CRDT design:

**Principle 2.** Express operations in terms of user intention---what the operation means to the user, intuitively. This might differ from the closest ordinary data type operation.

This works because users often have some idea what one operation should do in the face of concurrent operations. E.g., typing after a word should insert the new characters at that word, independently of other users' typing at the beginning of the document. If you can capture this intuition, the resulting operations won't conflict.

> **Remark.** Some papers (TODO) attempt to derive CRDT semantics automatically from the semantics of their closest ordinary data type. Principle 2 advocates an opposite approach, in which we reconsider what operations mean to the user, potentially ignoring their ordinary (non-CRDT) meanings entirely. This makes the CRDT design process require more thought, but also gives more legible and flexible results.

## Registers

Our last basic CRDT is the **register**. This is a variable that holds an arbitrary value that can be set and get. If multiple users set the value at the same time, you pick a value arbitrarily, or perhaps average them together.

Example uses for registers:
- The top, left, width, and height of an image in a collaborative slide editor (each as their own register). If multiple users drag an image concurrently (setting the top and left registers), one of their positions is picked arbitrarily.
- The font size of a character in a collaborative rich-text editor.
- The name of a document.
- The color of a specific pixel in a collaborative whiteboard.
- Basically, anything where you're fine with users overwriting each others' concurrent changes and you don't want to use a more complicated CRDT.

As you can see, registers are very useful and suffice for many tasks (e.g., TODO uses them almost exclusively).

### Setting the Value

The only operation on a register is $set(x)$, which sets the value to $x$ (in the absence of concurrent operations). We can't perform these operations literally, since if two users receive concurrent $set$ operations in different orders, they'll end up with different values.

However, we notice that $set(x)$ is doing something "new"---setting a new value $x$.  So following Principle 1, we should use a unique set CRDT. I.e., the state of our register is a unique set, and when a user calls $set(x)$, we call $add(x)$ on the unique set. The state is now a set of values instead of a single value, but we'll just have to live with this (see below).

Of course, we don't have to keep around a set of all values that have ever been set; we can delete the old ones each time $set(x)$ is called. Indeed, for an ordinary (non-CRDT) register, we can think of $set(x)$ as having two steps: first, delete the old value; then set the new value $x$. In CRDT-land, using a unique set, this becomes: first, for each old value, delete it; then add the new value $x$.

In summary, the implementation of $set(x)$ is: for each element $e$ in the unique set, call $delete(e)$ on the unique set; then call $add(x)$. The result is that at any time, the register's state is the set of all the most recent concurrently-set values, i.e., the maximal values with respect to the causal order.

Loops of the form "for each element of a collection, do something" are common in programming. We just saw a way to extend them to CRDTs: "for each element of a unique set, do some CRDT operation". We call this a **causal for-each** because it affects elements that were added to the unique set causally prior to the for-each operation. It's useful enough that we make it our next principle of CRDT design:

**Principle 3a.** For operations that do something "for each" element of a collection, one option is to use a *causal for-each operation* on a unique set (or list CRDT).

TODO: resettable counter? Only if can find good use case.

### Getting the Value

We still need to handle the fact that our state is a set of values, instead of a specific value.

One option is to accept this as the state, and present all conflicting values to the user.  This gives the **Multi-Value Register (MVR)**.

Another option is to pick a value arbitrarily but deterministically.  E.g., the **Last-Writer Wins (LWW) Register** tags each value with a wall-clock timestamp when it is set, then picks the value with the latest timestamp (breaking ties by user id).

TODO: figure: Pushpin LWW + MVR.

In general, you can use an arbitrary deterministic function of the set. Examples:
- If the values are colors, you can average their RGB coordinates. That seems like fine behavior for pixels in a collaborative whiteboard. TODO: illustration
- The **Enable-Wins Flag** CRDT is a boolean-valued register where the external value is $true$ if the state contains at least one $true$. This means that we give a preference to $set(true)$ over concurrent $set(false)$ operations ("true-wins semantics"). The **Disable-Wins Flag** is the opposite.

## Composing CRDTs: Objects, Maps, and Collections of CRDTs

We now have enough basic CRDTs to start making more complicated data structures. All we need are ways to compose them together. I'll describe three techniques: CRDT objects, CRDT-valued maps, and unique sets of CRDTs.

### CRDT Objects

The simplest composition technique is to use multiple CRDTs side-by-side. By making them be instance fields in a class, you obtain a **CRDT Object**, which is itself a CRDT (trivially). Of course, CRDT objects can use standard OOP techniques, e.g., implementation hiding.

Examples:
- As mentioned earlier, you can represent the position and size of an image in a collaborative slide editor by using separate registers for the top, left, width, and height. To get a complete image object, you might also add registers for border color/size/style, a text CRDT for the caption, a register for the image source (unless it's immutable, in which case you can use an ordinary, non-CRDT instance field), etc.
- In a flash card app, to make individual cards editable, you could represent each card as an object with two text CRDT instance fields, one for the front and one for the back.
- Recall that we defined lists and registers in terms of the unique set. We can consider these as CRDT objects as well, even though they just have one instance field (the set). The object lets us delegate operations and reads to the inner set while exposing the API of a list/register.

### CRDT-Valued Map

A CRDT-valued map is like a CRDT object but with potentially infinite instance fields, one for each allowed map key. The simplest version is a "lazy map", like [Apache Commons' LazyMap](https://commons.apache.org/proper/commons-collections/apidocs/org/apache/commons/collections4/map/LazyMap.html): every key/value pair is implicitly always present in the map, although values are only explicitly constructed in memory as needed, using a predefined factory method.

Examples:
- TODO: Add-wins set. Ex for archiving documents.
- TODO: LwwMap. Rich text / Quill ex?
- TODO: file system example?

### Collections of CRDTs

Our above definition of a unique set assumed that the data values $x$ were immutable and serializable (capable of being sent over the network). However, we can also make a **unique set of CRDTs**, whose values are dynamically-created CRDTs.

A unique set of CRDTs has operations:
- $add(a)$: Adds an element $e = (C, t)$ to the set, where $t$ is a unique new tag, and $C$ is a new CRDT created with argument $a$ using a predefined factory. The adding user generates $t$, then serializes $(a, t)$ and broadcasts it to the other users.  The receivers deserialize $(a, t)$, input $a$ to the factory to get $C$, then add $(C, t)$ to their local copy. All users' copies of $C$ stay in sync, i.e., they broadcast operations to each other as you'd expect.
- $delete(e)$: Deletes the element $e = (C, t)$ from the set. $C$ can then no longer be used.

We likewise can make a **list of CRDTs**.

Examples:
- TODO: documents in a shared folder (set).
- TODO: todo-list (list of text).
- TODO: rich text (list of rich objects).

### Using Composition

You can use the above composition techniques and core CRDTs to design CRDTs for many collaborative apps. Choosing the exact structure, and how operations and user-visible state map onto that structure, is the main challenge.

A good starting point is to design an ordinary (non-CRDT) data model, using objects, collections, etc., then convert it to a CRDT version. So variables become registers, objects become CRDT objects, lists become list CRDts, sets become unique sets or add-wins sets, etc. You can then tweak the design as needed to accommodate extra operations or fix weird concurrent behaviors.

To accommodate as many operations as possible while preserving user intention, we recommend:

**Principle 4.** Independent operations (in the user's mind) should act on independent state.

Examples:
- TODO: movable list. Give motivating ex. Ref paper.
- TODO: image shape (right: all separate; wrong: all one register, unless that's what you want; wrong: bottom and right instead of width and height, by this principle and Principle 2.)
- TODO: document names (set of pairs (name, doc), not implicit map, so that you can change names. Also needed to dynamically init documents, ref Yjs issue?.)

## New: Concurrent+Causal For-Each Operations

There's one more trick I want to show you. Sometimes, when performing a for-each operation on a unique set or list CRDT, you don't just want to affect existing (casually prior) elements. You also want to affect *elements that are added/inserted concurrently*.

For example:
- TODO: rich-text formatting. Illustrate.
- TODO: recipe scaling. Illustrate, silly example from talk.

I call such an operation a **concurrent+causal for-each operation**. Formally, TODO (sending op, recipients act on concurrently added ops received both before and after).

To accomodate the above examples, I propose:

**Principle 3b.** For operations that do something "for each" element of a collection, another option is to use a *concurrent+causal for-each operation* on a unique set (or list CRDT).

Concurrent+causal for-each operations are novel as far as I'm aware. They are based on a paper I, Heather Miller, and Christopher Meiklejohn wrote last year, on a composition technique we call the *semidirect product*. Unfortunately, the paper is rather obtuse, and it doesn't make clear what the semidirect product is doing intuitively (since we didn't understand this ourselves!). My current opinion is that it is an optimized way of implementing concurrent+causal for-each operations. Unless you're making an optimized CRDT implementation, you don't need to know any more.

> If you do want to use the semidirect product to optimize, be aware that it is not as general as it could be. E.g., the recipe example can be optimized, but not using the semidirect product. I'll write up a tech report about a more general approach at some point.

TODO: Remark: dual view: controller for the for-each part plus oppositely-adjusted state. E.g. for scaling, or reversible list? Perhaps contrast with that approach---ours should be easier, in comparison to e.g. rich-text CRDT using invisible formatting characters (direct construction approach).

## Summary: Principles of CRDT Design

For easy reference, here are our principles of CRDT design.

TODO: repeat principles verbatim.

# Case Study: A Collaborative Spreadsheet

Now let's get real: we're going to design a CRDT for a collaborative spreadsheet editor (think Google Sheets).

As practice, you can try sketching a design yourself before reading any further; the rest of the section describes how I would do it.

> There's no one right answer, so don't worry if your ideas differ from mine! The point of this blog post is to give you confidence to design and tweak CRDTs like this yourself, not to dictate "the one true spreadsheet CRDT (TM)".

TODO

Column objects with width, row likewise, cells as map from (row, column) to cell.  Cell has register for contents, others for formatting. Contents are array of tokens, with immutable positions for obvious reason; note not collaborative text, although this is a choice.

Causal+concurrent for-each for row, column formatting. Movable rows, columns. Also mention deletes.

Suggest further tweaks, phrased as user requests? Goal is that reader can "solve" them.

# Conclusion


TODO (put somewhere):

- CRDT-as-data-model (not just basic data structures). In composition? Or is it obvious enough? (Perhaps in intro as contrast to prior work. Without the prior bias, it's obvious to do things this way.)
- Targetting semantics (what to do when stuff happens), not implementation like most works.  Implementation comes second; can sometimes optimize (especially memory, e.g. a counter). We describe our semantics in terms of operation implementation because that's often simplest, but you might end up using a different implementation.  That's also a bit different from the abstract semantics (define as function of causal history), although we give those too where easy (e.g. unique set).
- Principles: views; not everything is shared).  Used in flash card, but seems too early to introduce.
- Clarify existing CRDTs vs novel ones (spreadsheet, concurrent for-each).
- links for principles
- Counter somewhere? E.g. in considering user intention (contrast with register)?
- we -> I
