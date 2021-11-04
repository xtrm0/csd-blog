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

# Introduction: Collaborative Apps via CRDTs

Suppose you're building a collaborative app, along the lines of Google Docs/Sheets/Slides, Figma, Notion, etc. One challenge you'll face is the actual collaboration: when one user changes the shared state, their changes need to show up for every other user. For example, if multiple users type at the same time in a text field, the result should reflect all of their changes and be consistent (identical for all users).

*Conflict-free Replicated Data Types (CRDTs)* provide a solution to this challenge. They are data structures that look like ordinary data structures (maps, sets, text strings, etc.), except that they are collaborative: when one user updates their copy of a CRDT, their changes automatically show up for everyone else. Each user sees their own changes immediately, while under the hood, the CRDT broadcasts a description of their changes to everyone else; those other users see it as soon as they receive the message.

TODO: example/diagram (from talk?)

Note that it's possible for multiple users to make changes at the same time, e.g., both typing at once. Since each user sees their own changes immediately, their views of the document will temporarily diverge. However, CRDTs guarantee that once the users receive each others' messages, they'll see identical document states again: this is the definition of **CRDT correctness**. Ideally, this state will also be "reasonable", i.e., it will incorporate both of their edits in the way that the users expect, without requiring any git-style manual merging.

> In distributed systems terms, CRDTs are Available, Partition tolerant, and have Strong Eventual Consistency.

TODO: advantages of CRDTs specifically (no server---open source, works offline, E2EE). Note possibility of long divergence times, in which case reasonable conflict resolution really matters. Show examples of failure? (E.g. Google Docs "disconnected", Dropbox failing to manually merge files like in Geoffrey Litt tweet.) Link to local-first blog post, Collabs, Collabs demos, Strange Loop talk.

## The Challenge: Designing CRDTs

Having read all that, let's say you want to build a collaborative app using CRDTs. All you need is a CRDT representing your app's state, a frontend UI, and a network of your choice (or a way for users to pick the network themselves). But where do you get a CRDT for your specific app?

If you're lucky, it's described in a [paper](TODO), or even better, implemented in a production-ready [library](TODO). But these tend to be simple or one-size-fits-all data structures: maps, text strings, unstructured JSON, etc. You can usually rearrange your app's state to make it fit in these CRDTs; and if users make changes at the same time, CRDT correctness guarantees that you'll get *some* consistent result. However, it might not be what you or your users expect. Worse, you have little leeway to customize this behavior.

TODO: figure: JSON paper weird todo-list behavior (not what you expect, will look weird to users too).

TODO: demo user Q&A asking for a change in the conflict-resolution, and you just reply "sorry".

TODO: citations to blog posts (Figma, LWW one?) mentioning need to customize conflict resolution? Seems obviously important for any serious product.

This blog post will instead teach you how to design CRDTs from the ground up. I'll present a few simple CRDTs that are obviously correct (no mathematical proofs involved), plus ways to compose them together into complicated whole-app CRDTs that are still obviously correct. I'll also present principles of CRDT design that should help guide you through the process. Ultimately, I hope that you will gain not just an understanding of some existing CRDT designs, but also the confidence to tweak them and create your own.

## Other Approaches

The approach described in this blog post is my own unique way of thinking about CRDTs. I'm not aware of existing works that explain things precisely this way, although (TODO: composition papers) describe CRDT composition techniques.

Some more traditional approaches:
1. TODO: commutativity approach. Proof is barrier to entry (hard to invent new ones or tweak, if not a math/CRDT person already); not always clear what they're doing, hence might not be what you expect (e.g. semidirect).
2. TODO: direct semantics approach (Burckhardt paper, pure op-based). Hard to do; if I gave you a causal history of spreadsheet ops, could you tell me what the answer is supposed to be? (Illustrate with DAG?)
3. TODO: derive from sequential specifications. OpSets, Riley paper, other similar paper, SECROs. Misses out on ability to make choices; not clear what it's doing (Riley = complicated, OpSets, SECROs = mysterious).

TODO: semantics vs implementation. Commutativity & sequential approaches combines the two, sometimes to the detriment of semantics comprehensibility/usability (e.g. Riak observed-resets, OpSets, semidirect). Causal history approach does just semantics, but in an abstract way (becomes hard to tell what will happen given a history of ops; only for the mathematically inclined, e.g., set and notation heavy). I advocate establishing semantics first using my approach (which doubles as a first implementation and is designed to be fully legible), then if necessary, optimize with a construction that you can prove (or experimentally verify) is equivalent to the original - good practice for optimization in general. E.g. counter-as-unique-set (here) vs as literal counter - give with collaborative app example.

# Network Model

TODO: broadcast messaging, arbitrary delays/reordering; causal order & causal order delivery; two definitions of correctness (direct SEC; commuting concurrent ops). For our designs, either verification is trivial.

# Basic Designs

## Unique Set

Our foundational CRDT is the **Unique Set**.  It is a set in which each added element is considered unique.

Formally, the operations on the set are:
- $add(x)$: Adds an element $e = (x, t)$ to the set, where $t$ is a unique new tag, used to ensure that $(x, t)$ is unique. The adding user generates $t$ (see below), then serializes $(x, t)$ and broadcasts it to the other users.  The receivers deserialize $(x, t)$ and add it to their local copy.
- $delete(e)$: Deletes the element $e = (x, t)$ from the set.  The deleting user serializes $t$ and broadcasts it to the other users.  The receivers deserialize $t$ and remove the element with tag $t$ from their local copy, if it has not been deleted already.

When viewing the set, you ignore the tags and just list out the data values $x$, keeping in mind that (1) they are not ordered (at least not consistently across different users), and (2) there may be duplicates.

> **Example.** In a flash card app, you could represent the deck of cards using a unique set, using $x$ to hold the flash card's value (e.g., its front and back strings). Users can edit the deck by adding a new card or deleting an existing one, and duplicate cards are allowed. Note that the collaborative state is just the *set* of cards; there is no ordering info. You could perhaps sort them alphabetically in editing mode (to make them consistent), and randomly in practice mode (deliberately inconsistent).

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

> **Remark.** Some papers (TODO: Riley, newer one like Riley, linearization papers like OpSets or the Splash one) attempt to derive CRDT semantics automatically from the semantics of their closest ordinary data type. Principle 2 advocates an opposite approach, in which we reconsider what operations mean to the user, potentially ignoring their ordinary (non-CRDT) meanings entirely. This makes the CRDT design process require more thought, but also gives more flexible and understandable results.

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

In general, you can define the getter using an arbitrary deterministic function of the set of values. Examples:
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

> If you want a non-lazy map, in which keys have explicit membership and can be deleted, you can use a lazy map plus an add-wins set to track which keys are present.

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

TODO: remark: more general to split into concurrent for-each and causal for-each. That's how you'd implement it usually (do for-each locally, then send concurrent for-each op). I won't change the principle unless I find a good use-case.

TODO: Remark: dual view: controller for the for-each part plus oppositely-adjusted state. E.g. for scaling, or reversible list? Perhaps contrast with that approach---ours should be easier, in comparison to e.g. rich-text CRDT using invisible formatting characters (direct construction approach).

## Summary: Principles of CRDT Design

For easy reference, here are our principles of CRDT design.

TODO: repeat principles verbatim.

# Case Study: A Collaborative Spreadsheet

Now let's get real: we're going to design a CRDT for a collaborative spreadsheet editor (think Google Sheets).

As practice, you can try sketching a design yourself before reading any further; the rest of the section describes how I would do it.

> There's no one right answer! The point of the blog post is to give you confidence to design and tweak CRDTs like this yourself, not to dictate "the one true spreadsheet CRDT".

### Design Walkthrough

To start off, consider an individual cell. Fundamentally, it consists of a text string. We could make this a text (list) CRDT, but usually, you don't edit individual cells collaboratively; instead, you type the new value of the cell, hit enter, and then its value shows up for everyone else. This suggests instead using a register, e.g., an LWW register.

Besides the text content, a cell can have properties like its font size, whether word wrap is enabled, etc. Since changing these properties are all independent operations, following Principle 4, they should have independent state. This suggests using a CRDT object to represent the cell, with a different CRDT instance field for each property. In pseudocode:
```ts
class Cell {
  content: LwwRegister<string>;
  fontSize: LwwRegister<number>;
  wordWrap: EnableWinsFlag;
  // ...
}
```

The spreadsheet itself is a grid of cells. Each cell is indexed by its location (row, column), suggesting a map from locations to cells. (A 2D list could work too, but then we'd have to put rows and columns on an unequal footing, which might cause trouble later.) Thus let's use a `Cell`-CRDT-valued lazy map.

What about the map keys? It's tempting to use conventional row-column indicators like "A1", "B3", etc. However, then we can't easily insert or delete rows/columns, since doing so renames other cells' indicators. (We could try making a "rename" operation, but that violates Principle 2, since it does not match the user's original intention: inserting/deleting a different row/column.)

Instead, let's identify cell locations using pairs (row, column), where the "row" means "the line of cells horizontally adjacent to this cell", independent of that row's literal location (1, 2, etc.), and likewise for "column". That is, we create an opaque `Row` object to represent each row, and likewise for columns, then use pairs (`Row` object, `Column` object) for our map keys.

The word "create" suggests using unique sets (Principle 1), although since the rows and columns are ordered, we actually want CRDTs. Hence our app state looks like:
```ts
rows: ListCrdt<Row>;
columns: ListCrdt<Column>;
cells: LazyCrdtValueMap<[row: Row, column: Column], Cell>;
```
Now you can insert or delete rows and columns by calling the appropriate operations on `columns` and `rows`, without affecting the `cells` map at all. (Due to the lazy nature of the map, we don't have to explicitly create cells to fill a new row or column; they implicitly already exist.)

Speaking of rows and columns, there's more we can do here. For example, rows have editable properties like their height, whether they are hidden, etc. These properties are independent, so they should have independent states (Principle 4). This suggests making `Row` into a CRDT object class:
```ts
class Row {
  height: LwwRegister<number>;
  isHidden: EnableWinsFlag;
  // ...
}
```

Likewise, we should be able to edit the position of a row/column, i.e., move it around. Such movements are intuitively independent of any other changes: if I edit a cell while you move its row around, my edits should show up normally, in the new destination row. This again suggest an independent state for the position of a row. So instead of using a literal list CRDT, we should use the movable list design described [above](TODO): a set of pairs (position, value), where "position" is an LWW register storing a CRDT-list-style immutable position.
```ts
class MovableList<T> {
  state: UniqueSet<[position: LwwRegister<ListCrdtPosition>, value: T];
}

rows: MovableList<Row>;
columns: MovableList<Column>;
```

We can also perform operations on every cell in a row, like changing the font size of every cell. For each such operation, we have three options:
1. Use a causal for-each operation (Principle 3a). This will affect all current cells in the row, but not any cells that are created concurrently (because a new column is inserted). E.g., causal for-each is the safe choice for a "clear" operation that sets every cell's content to "", since that way, you don't lose data entered into a concurrently-created cell.
2. Use a concurrent+causal for-each operation (Principle 3b). This will affect all current cells in the row *and* any those created concurrently. E.g., I'd recommend this for changing the font size or other formatting properties of a whole row, so that concurrently-created cells don't become mismatched.
3. Use an independent state that affects the row itself, not the cells (Principle 4). E.g., we're already using `Row.height` for the height of a row, instead of using a separate height CRDT for each cell.

> **Remark.** Note that the for-each loops loop over every cell in the row, even blank cells that have never been used. This has the downside of making all those cells explicitly exist in the lazy map, increasing memory usage. We tolerate this since our focus is to pin down the semantics, not give an efficient implementation. Once the semantics are pinned down, though, you are free to optimize the implementation.  So long as you can prove that the app's behavior is unchanged, it's still a CRDT with your desired semantics.  This approach is probably easier and more user-friendly than trying to construct an efficient CRDT from scratch and prove commutativity directly, without a solid semantics to guide you.

Lastly, let's take another look at cell contents. Before we said it was just a string, but it's more interesting than that: cells can reference other cells in formulas, e.g., "A2 + B3". If a column is inserted before column A, these references should update to "B2 + C3", since they intuitively describe a *cell*, not the indicators themselves. So, we should store them using a pair `[row: Row, column: Column]`, like the map keys. The content then becomes an array of tokens, which can be literal strings or cell references:
```ts
class Cell {
  content: LwwRegister<string | [row: Row, column: Column]>;
  fontSize: LwwRegister<number>;
  wordWrap: EnableWinsFlag;
  // ...
}
```

### Finished Design

In summary, the state of our spreadsheet is as follows.
```ts
// ---- CRDT Objects ----
class Row {
  height: LwwRegister<number>;
  isHidden: EnableWinsFlag;
  // ...
}

class Column {
  width: LwwRegister<number>;
  isHidden: EnableWinsFlag;
  // ...
}

class Cell {
  content: LwwRegister<string | [row: Row, column: Column]>;
  fontSize: LwwRegister<number>;
  wordWrap: EnableWinsFlag;
  // ...
}

class MovableList<T> {
  state: UniqueSet<[position: LwwRegister<ListCrdtPosition>, value: T];
}

// ---- App state ----
rows: MovableList<Row>;
columns: MovableList<Column>;
cells: LazyCrdtValueMap<[row: Row, column: Column], Cell>;
```

Note that I never mentioned correctness (eventual consistency) or commutativity of concurrent operations. Because we assembled the design from trivially-correct pieces, it is also trivially correct. Plus, it should be straightforward to reason out what would happen in various concurrency scenarios.

As exercises, here are some further tweaks you can make to this design, phrased as user requests:
1. "I'd like to have multiple sheets in the same document, accessible by tabs at the bottom of the screen, like in Excel." Hint: >! Use a list of CRDT objects.
2. "I've noticed that if I change the font size of a cell, while at the same time someone else changes the font size for the whole row, sometimes their change overwrites mine. I'd rather keep my change, since it's more specific." Hint: >! Use a register with a custom getter.

# Conclusion

In this blog post, TODO

TODO: CRDTs covered, not covered (e.g. optimizations, including weird semantics that arise from optimizations only (picture from Automerge paper), or tree (tricky, haven't decided what this is about myself yet)).

TODO (put somewhere):

- Clarify existing CRDTs vs novel ones (spreadsheet, concurrent for-each).
- links for principles
- Counter somewhere? E.g. in considering user intention (contrast with register)?
- we -> I
- more figures
- Principle 2 for states as well?  (What does a value mean to the user. E.g. A2 in a spreadsheet means the cell, even if it moves around.)
