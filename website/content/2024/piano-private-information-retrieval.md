+++
# The title of your blogpost. No sub-titles are allowed, nor are line-breaks.
title = "Piano: Extremely Simple, Single-Server Private Information Retrieval"
# Date must be written in YYYY-MM-DD format. This should be updated right before the final PR is made.
date = 2024-02-29

[taxonomies]
# Keep any areas that apply, removing ones that don't. Do not add new areas!
areas = ["Security"]
# Tags can be set to a collection of a few keywords specific to your blogpost.
# Consider these similar to keywords specified for a research paper.
tags = ["Cryptography", "Security", "Privacy", "Private Information Retrieval"]

[extra]
# For the author field, you can decide to not have a url.
# If so, simply replace the set of author fields with the name string.
# For example:
#   author = "Harry Bovik"
# However, adding a URL is strongly preferred
author = {name = "Mingxun Zhou", url = "https://cs.cmu.edu/~mingxunz" }
# The committee specification is simply a list of strings.
# However, you can also make an object with fields like in the author.
committee = [
    "Committee Member 1's Full Name",
    "Committee Member 2's Full Name",
    {name = "TBD", url = "http://example.com"},
]
+++

Information retrieval is a pervasive aspect of our digital life, yet the process of retrieval consistently compromises the privacy of the users (i.e., the information requesters). For example, when you access a website, you need to first retrieve the website's IP address from a DNS (Domain Name Service) server, so that you can talk to the website provider associated with that IP address. Unfortunately, this process discloses your browsing history to the DNS server. Similarly, submitting a query to a search engine exposes your search history to the search service provider. Despite efforts to develop privacy-preserving information retrieval services, those service providers often employ the same retrieval techniques as their non-private counterparts and just promise to keep the users' records securely or delete them afterward. Nonetheless, these service providers are still susceptible to data breaches. 

Is there a way to completely eradicate the leakage of information during information retrieval?
A natural attempt is to encrypt the queries, so the server cannot read the queries in plaintext. However, without seeing the query, how can the server locate the relevant information? It seems like we are now facing a dilemma. 

# What is Private Information Retrieval (PIR)?

Private information retrieval (PIR), first introduced by [Chor et al.](https://www.computer.org/csdl/proceedings-article/focs/1995/71830041/12OmNzYNNfi) back in 1995, is exactly the formal abstraction of "retrieving public information privately". It is defined as follows.

> **Definition (Private Information Retrieval Protocol):** For simplicity, let's assume there is only one server storing a database consisting of \\(n\\) integers, denoted by \\(X_1,\dots, X_n\\). Now assume the client wants to learn \\(X_i\\). The client and the server then engage in an interactive algorithm, formally referred as a Private Information Retrieval protocol. At the end of the protocol, the client should learn the correct value of \\(X_i\\). Also, the protocol should provide query privacy: the server should learn nothing about the query index \\(i\\).
<p></p>

At first glance, it might seem impossible to design such a protocol. Don't worry -- there is at least a naive protocol satisfying the definition: given any query index \\(i\\), the client just downloads the whole database and reads \\(X_i\\) locally. This protocol is perfectly private: the server only knows that the client downloads the database and that is independent of the actual query. Nonetheless, this protocol is not practical -- the computation and communication costs per query are both linear in the size of the database.

Previously, cryptographers focused on improving the *communication cost* of PIR. Most proposed PIR schemes rely on *Homomorphic Encryption (HE)*, a special type of encryption scheme that allows *computation on the ciphertexts*. HE essentially avoids the dilemma we saw before -- the server can perform some form of computation on the encrypted query and somehow locate the necessary information for the client. Existing schemes already achieved \\(O(\log n)\\) communication per query based on HE (e.g., [OnionPIR](https://dl.acm.org/doi/abs/10.1145/3460120.3485381) and [Spiral](https://ieeexplore.ieee.org/abstract/document/9833700/)).

<!---
A typical scheme is as follows. The server represents the database as a $\sqrt{n}\times \sqrt{n}$ matrix, denoted as $M$. Suppose the client is interested in a database value located the $j$-th column of the matrix. The client can homomorphically encrypts an one-hot vector $e_j=(0,\dots,0,1,0\dots,0)^T\in \{0,1\}^{\sqrt{n}}$ where only the $j$-th location is 1. The clients sends the homomorphically encrypted vector $[e_j]$ to the server, and the server computes the matrix-vector multiplication $M[e_j]$ and return the results to the client. The client decrypts the result, which contains exactly the $j$-th column of the matrix, and they gets the desired value. This protocol saves the communication to $O(\sqrt{n})$. 
-->

An unsolved issue is the *computation cost*. Even with the help of HE, the computation cost is still linear in \\(n\\). Such linear-computation-cost PIRs are not suitable for larger databases. For example, a typical DNS server contains several hundreds of gigabytes of records and it is over-costly if the server has to scan all the records for each query. Unfortunately, [Beimel, Ishai and Malkin](https://citeseerx.ist.psu.edu/document?repid=rep1&type=pdf&doi=c3404368a32ab694c862f88cd1b5a3e6208f1bff) showed that in the classical PIR model, linear computation is inevitable. The intuition behind their lower bound is actually pretty straightforward -- if the server does not touch any particular database entry during the query, the server knows the client's query cannot be this entry. This at least leaks one bit of information. 

To get around this lower bound and achieve sublinear computation cost PIR, we can resort to a powerful idea in computer science -- **preprocessing**. Preprocessing PIR allows the client or the server to run some (possibly interactive) protocols before the query phase begins, and store some necessary hints in the client space or the server space. The client or the server then uses those hints to help with the online queries.
[Beimel, Ishai and Malkin](https://citeseerx.ist.psu.edu/document?repid=rep1&type=pdf&doi=c3404368a32ab694c862f88cd1b5a3e6208f1bff) first showed that preprocessing PIR can indeed achieve \\(O(\frac{n}{\log n})\\) computation cost per query. [Corrigan-Gibbs and Kogan](https://eprint.iacr.org/2019/1075.pdf) (and [their follow-up work](https://eprint.iacr.org/2022/081.pdf) with Henzinger) further showed the computation cost can be improved to \\(O(\sqrt{n})\\) per query. Nonetheless, these schemes are relatively complicated and remain in theory. Then, a natural question is:

>Is there a practical, and sublinear computation cost PIR protocol?
<p></p>


# Piano: Extremely Simple PIR with Preprocessing

We now introduce our work Piano ([Zhou et al., IEEE S&P 2024](https://eprint.iacr.org/2023/452)), an extremely simple and practical PIR scheme with preprocessing. It is easy to implement -- the core idea can be implemented within 150 lines of Go code, and it is blazingly fast. Piano only takes 12ms to finish a query on a 100GB database, which is nearly 1000x faster than the previous best solution ([Henzinger et al. 2022](https://eprint.iacr.org/2022/949))!

Piano starts with the following idea: 
> Downloading the whole database for every query seems bad, but what if the client can just download the database once and prepare for many queries?
<p></p>

That is, the client downloads the database during the preprocessing (importantly, without knowing the following queries), computes and stores some sublinear size hints, and then deletes the database. The client then utilizes those hints to help with online queries.

This idea cannot scale to Internet-size databases (like Google search), for sure. However, for many medium-size databases, the idea is practical if we can build a **streaming preprocessing**. Streaming means that instead of downloading the database at once, the client can download a small portion of the database each time, locally update the hints, and delete that portion of the database from the local storage. One can imagine that this process is similar to watching a Youtube video -- you do not need to download the whole video at once, but rather just dynamically fetch a piece of the video 30 seconds ahead. We indeed designed a streaming preprocessing algorithm, and given a database of size around 100 gigabytes, the cost will be similar to watching Youtube videos for several hours. 

## Preprocessing

![Preprocessing](preprocessing.png)
*Figure 1: Illustration of the preprocessing for a database with 16 entries.*

We now get to introduce some details about the preprocessing. 
We split the \\(n\\) indices into \\(\sqrt{n}\\) chunks of size \\(\sqrt{n}\\) (see Figure 1 above).
During the preprocessing, the client will store roughly \\(\tilde{O}(\sqrt{n})\\) "random linear equations", where the variables are the entries from the database. To generate one linear equation, the client samples one entry from each database chunk, resulting in \\(\sqrt{n}\\) variables for one equation. The client computes the sum of those variables during the preprocessing. In the end, the client only stores the sum values and the random seeds used to generate the equations. In addition, the client stores around \\(\log n\\) random entries for each chunk. Those random entries will be called the *replacement entries*.
Finally, the equations and the replacement entries comprise the client's hint, which takes \\(O(\sqrt{n}\log n)\\) storage space. The server does not store any hints.
Since the client does all the preprocessing computation locally, the server cannot observe the preprocessing result. Moreover, as we mentioned before, the preprocessing is done in a streaming manner, so the temporal storage requirement is small: the client only needs to initialize the equations to zeros, download the chunks one by one, and accumulatively compute the sum values.



## Handling a Single Query

Now let's see how the preprocessing helps with the online query. We use the example in Figure 1. Assume the client is querying for \\(X_7\\). The client will first scan the local equations and look for the first equation that contains \\(X_7\\). Because of the structure of those equations, during the scanning process, the client only needs to regenerate the second index in each equation using the stored random seeds, and match the generated index against "7".  The client will find the equation \\(X_1 + X_7 + X_{10} + X_{12}=Y_1\\) in the example. Since the client already stores \\(Y_1\\), which is the sum of these four elements, if the client can further learn the sum of \\(X_1 + X_{10} + X_{12}\\), it will learn the value of \\(X_7\\) by a basic subtraction. Unfortunately, the client cannot directly send the indices "\\(1, 10, 12\\)" to the server and ask the server to return the sum of \\(X_1 + X_{10} + X_{12}\\), because the server will immediately see that there are no indices from the second chunk and learn that the query must belong to the second chunk. This is an information leakage.

Luckily, we can mitigate this information leakage easily -- remember that the client additionally stores some replacement entries in each chunk. So instead of directly removing the query index from the equation, the client **replaces** the query index with a known replacement entry index in the same chunk as the query. In our example, the client can simply replace \\(X_7\\) with \\(X_6\\), and send the four indices "\\(1, 6, 10, 12\\)" to the server. The server should return the sum of \\(X_1 + X_6 + X_{10} + X_{12}\\) to the client, upon receiving the indices. The client can then compute \\(X_7\\) as in Figure 2.
Note that this query **leaks no information about the actual query**: the server just sees four random indices and each one of them is just an independently random index within one chunk, given the fact that the server cannot see the preprocessing results. This query is also **efficient**: the client takes \\(O(\sqrt{n})\\) time to find the equation, the server takes \\(O(\sqrt{n})\\) time to compute the sum, and the communication cost is just \\(O(\sqrt{n})\\) (sending the edited equation to the server).

![Query](query.png)
*Figure 2: Illustration of the online query.*



## Multiple Queries

To amortize the cost of the preprocessing, we want to support as many queries as possible. Let's first assume we need to support \\(\sqrt{n}\\) random queries, which amortize the preprocessing costs to the same as the query costs, i.e., \\(O(\sqrt{n})\\) computation and communication cost per query.

The main issue is that we cannot reuse the same preprocessed equation or the same replacement entry to handle two queries. Otherwise, it will cause privacy leakage. We also don't want to deplete our equations and replacement entries. What should we do?

It is easy to handle the replacements: recall that we have \\(\sqrt{n}\\) random queries and \\(\sqrt{n}\\) chunks. With a classical balls-into-bins argument, there will be at most \\(O(\log n)\\) queries in each chunk with high probability. So preparing \\(O(\log n)\\) replacements per chunk is enough. 

It is trickier to handle the equations. A not-so-oblivious observation is that we cannot just remove the consumed equation or replace it with a random backup equation, because it will skew the joint distribution of the remaining equations -- doing so makes the current query less likely to appear in the remaining equations! The correct strategy is to replace the consumed equation with a random equation conditioned on the current query being included. We modify our preprocessing algorithm and add additional structural backup equations to facilitate this refresh strategy. We omit the details here due to space constraints and refer the interested readers to [our original paper](https://eprint.iacr.org/2023/452) for the full description.

<!---

To facilitate this refresh strategy, we prepare some special backup equations, as shown in Figure 3. Specifically, we prepare \\(O(\log n)\\) backup equations per chunk, and those backups prepared for the \\(i\\)-th chunk will ignore the entries in the \\(i\\)-th chunk. The reason behind it will be clear if we see the refresh algorithm: after each query \\(X\\) located in the \\(j\\)-th chunk, we will pick a backup equation prepared for chunk \\(j\\), and just complete that backup equation by adding \\(X\\) to it. We then replace the consumed equation with this completed backup. See an example in Figure 4.

![Backup](backup2.png)
*Figure 4: Illustration of the backup strategy. We prepare \\(\sqrt{n}\\) groups of backups, each contains \\(\log n\\) equations. The  \\(i\\)-th group ignores the entries in the \\(i\\)-th chunk. Assume the client just queried for \\(X_7\\). So the client picks a backup from the second group, completes it with \\(X_7\\), and replaces the consumed equation with this completed equation.*
--->

Our ultimate goal is to support many adaptive queries and remove the "\\(\sqrt{n}\\) random queries" restriction. First, to make the queries look random, we can require the server to randomly permute the database upfront and share the permutation seed with the client. As long as the client is not making queries that depend on the permutation, the queries can be viewed as randomly distributed. An experienced reader may notice that a malicious server may not necessarily permute the database correctly. In our paper, we proposed extra steps to ensure that a malicious server only hurts the correctness but not the privacy of the scheme.

Moreover, to support more queries, the simplest way is to redo the preprocessing per \\(\sqrt{n}\\) queries. We can do better by utilizing a pipelining trick, shown in Figure 5. During the online query phase for the first \\(\sqrt{n}\\) queries, we simultaneously run the preprocessing for the next batch of \\(\sqrt{n}\\) queries. So when we finish the first batch of queries, we have already finished the preprocessing for the next batch of queries, and we can immediately start the next query.

![Pipeline](pipeline.png)
*Figure 5: Illustration of the pipelining trick. We run the preprocessing for the next batch simultaneously with the online queries. Then, the whole protocol can have a one-time preprocessing and a continuous online phase.*

## Asymptotic Metrics of Piano

Piano's asymptotic behaviors can be summarized as follows. 

> **Simplified Theorem.** Piano is a PIR protocol with one-time preprocessing, and it supports a polynomially bounded number of queries, while having the following asymptotic behaviors:
> 1. One-time Preprocessing:
>    * \\(O(n)\\) communication;
>    * \\(\tilde{O}(n)\\) client computation.
> 2. Online Query (per query):
>    * \\(O(\sqrt{n})\\) communication.
>    * \\(\tilde{O}(\sqrt{n})\\) client computation;
>    * \\(O(\sqrt{n})\\) server computation; 
> 3. Storge: 
>    * \\(\tilde{O}(\sqrt{n})\\)  client storage;
>    * No additional server storage.
> 
> Here, \\(\tilde{O}()\\) hides the polylogarithmic terms.
<p></p>

Notably, Piano achieves nearly optimal time-space tradeoff: [Corrigan-Gibbs, Henzinger and Kogan](https://eprint.iacr.org/2022/081.pdf) showed that in any preprocessing PIR scheme, if the client stores \\(S\\) bits after preprocessing and the online query time cost is \\(T\\), then \\(S \times T \ge \Omega(n)\\). Piano achieves \\(\tilde{O}(\sqrt{n})\\) client storage and \\(\tilde{O}(\sqrt{n})\\) online time, which matches the bound except for a polylogarithmic factor!

<!---

**Client Computation.** The client takes \\(n \log n\\) time to do preprocessing for \\(\sqrt{n}\\) queries. Each online query requires the client to take \\(O(\sqrt{n})\\) expected time to find the equation. So the amortized client cost per query is \\({O}(\sqrt{n}\log n)\\).

**Server Computation.** The server just takes linear time to stream the database for the client during the preprocessing phase and take \\(O(\sqrt{n})\\) time to compute the equation sum for each online query. So the amortized server cost per query is \\({O}(\sqrt{n})\\). 

**Communication.** The client streams \\(n\\) integers for \\(\sqrt{n}\\) queries. The client also sends a \\(\sqrt{n}\\)-size equation to the server. The server's response is just a single integer. So the amortized communication cost per query is \\({O}(\sqrt{n})\\). 

**Storage.** The client stores no more than \\({O}(\sqrt{n}\log n)\\) equations and \\({O}(\sqrt{n}\log n)\\) replacements. The client only stores the random seeds and the sum value for the equations. So the total client storage requirement is \\({O}(\sqrt{n}\log n)\\). Note that the server has no per-client storage.

--->

## Empirical Results

We tested Piano on a 100GB database containing 1.6 billion 64-byte records. We compared it to the previous state-of-the-art scheme SimplePIR ([Henzinger et al. 2022](https://eprint.iacr.org/2022/949)). As shown in the following table, our scheme has a nearly 1000x improvement in terms of pure computation, and a 120x improvement in the end-to-end latency, while having advantages in communication and storage. Note that the streaming preprocessing only takes 45 minutes (8-thread parallelization).

|            |       Piano           | SimplePIR             |
|:---------- | :--------------------:|:---------------------:|
| End-to-end Latency  | 12ms (computation) + 60ms (network)       | ~11s |
| End-to-end Communication       | 220KB | 2.3MB             |
| Storage |   0.8GB               | 1.2GB                |

# Applications, Limitations and Open Problems

We are now actively exploring potential applications of Piano. As we mentioned earlier, a private search engine is one of the most attractive applications of PIR,
and we are indeed building such an engine based on the combination of an optimized version of Piano and graph-based search algorithms. Our preliminary results show 
that this private search engine can handle a static database nearly the size of English Wikipedia.
It achieves search quality comparable to those non-private search algorithms and provides orders of magnitude of efficiency improvement over previous best 
solutions, including [Tiptoe](https://eprint.iacr.org/2023/1438) and [Coeus](https://eprint.iacr.org/2022/154).

Some other applications, such as private DNS query, remain more challenging. One of the main technical difficulties is that the database (e.g., the DNS records) is 
being updated frequently, which contradicts the assumption of Piano. Two recent works proposed possible solutions for updatable databases ([Lazzaretti and Papamanthou](https://eprint.iacr.org/2024/303.pdf), [Hoover et al.](https://eprint.iacr.org/2024/318.pdf)), but it remains an open problem as how to design a truly practical updatable PIR scheme.

Another limitation of Piano is the lack of appropriate permission control since the preprocessing of Piano reveals the whole database to the client. Imagine we are designing a PIR protocol for a personal credit score lookup service. It is not acceptable for one individual to learn all others' credit scores. It remains an interesting open problem to design a PIR scheme with proper permission control, which is required by many real-world applications. 
