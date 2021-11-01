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

You can't fix the latency the usual way - using multiple servers around the world so every user has one close by - because all users editing the same document must use the same server. And of course, this server-first solution doesn't work offline or keep user data private.

## CRDTs: Data Structures for Collaborative Apps

*Conflict-free Replicated Data Types (CRDTs)* provide an alternative solution. These are data structures that look like ordinary data structures (maps, sets, text strings, etc.), except that they are collaborative: when a user updates their copy of a CRDT, their changes automatically show up for everyone else. Unlike with the above server-first solution, a user's local copy of a CRDT updates immediately when they make a change. The CRDT then syncs up with other users' copies in the background, eventually informing them of the change.

TODO: example/diagram (from talk?)

TODO: also network-agnostic (open source-able?), works offline, E2EE - link to local-first blog post. Also mention Collabs, link to demos.

TODO: difficulty: designing. Main goal is eventual consistency (correctness), proved with commutativity or as function of operation history DAG (illustrate, show hardness be referencing e.g. spreadsheet?). But it's not always clear *how* a CRDT resolves conflicts (semantics), i.e., what happens in a given situation. Might not be what you expect; hard to modify if not an expert. E.g. semidirect - can make things we don't understand semantically.

TODO: this post goals: explain existing designs in terms of a few simple principles, can be understood without any nontrivial proofs. Give confidence to tweak or make your own. Necessary if making your own app so you can make it do what you want, respond to user requests. Illustrative pic: user asking for a fix (e.g. moving a column while editing a cell), dev responding sorry. Cite Figma blog post?

# Basic Designs

## Unique Set

Explain message passing as well (serialize).

Ex: flashcards (unordered - sort alphabetically or randomly.  Principles: views; not everything is shared).

## Lists

What the user really means is the abstract immutable position (between L & R), not an index.  Leads naturally to design (Explain in terms of principle, e.g., indie ops acting on indie state?)

## Registers

Principle: for-each.

Ex: pixel pusher colors (Lww/MVR). Also option to blend.

Also EWFlag as related idea.

## Composing CRDTs: Objects, Maps, and Sets of CRDTs

Ex object: powerpoint shape (top, left, width, height).  Can set together or separately.

Principle: independent operations should act on indie state.  Ex: movable list.

For collections/objects, explain message passing as well (name tree).

Ex set of CRDTs: rich text (using list on top of set like before).

Principle: causal+concurrent for-each. Ex: rich-text formatting. This is novel (what semidirect product is trying to be).

## Summary: Principles of CRDT Design

Unique set; causal for-each; causal+concurrent for-each; indie ops act on indie state (objects, maps, sets of CRDTs).

# A Collaborative Spreadsheet

Column objects with width, row likewise, cells as map from (row, column) to cell.  Cell has register for contents, others for formatting. Contents are array of tokens, with immutable positions for obvious reason; note not collaborative text, although this is a choice.

Causal+concurrent for-each for row, column formatting. Movable rows, columns.

Suggest further tweaks, phrased as user requests? Goal is that reader can "solve" them.

# Conclusion


TODO (put somewhere):

- Targetting semantics (what to do when stuff happens), not implementation like most works.  Implementation comes second; can sometimes optimize (especially memory, e.g. a counter).
- Resettable counter
- Recipe scaling example? Or just do spreadsheet?
- AWSet?  E.g. for set of non-archived documents (need ability to restore multiple times).
