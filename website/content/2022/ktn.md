+++
# The title of your blogpost. No sub-titles are allowed, nor are line-breaks.
title = "Zero-shot Transfer Learning on Heterogeneous Graphs via Knowledge Transfer Networks"
# Date must be written in YYYY-MM-DD format. This should be updated right before the final PR is made.
date = 2022-08-13

[taxonomies]
# Keep any areas that apply, removing ones that don't. Do not add new areas!
areas = ["Artificial Intelligence"]
# Tags can be set to a collection of a few keywords specific to your blogpost.
# Consider these similar to keywords specified for a research paper.
tags = ["graph neural network", "heterogeneous graph", "transfer learning"]

[extra]
# For the author field, you can decide to not have a url.
# If so, simply replace the set of author fields with the name string.
# For example:
#   author = "Harry Bovik"
# However, adding a URL is strongly preferred
author = {name = "Minji Yoon", url = "www.minjiyoon.xyz" }
# The committee specification is simply a list of strings.
# However, you can also make an object with fields like in the author.
committee = [
    "Anupam Gupta",
    "Nihar Shah",
    "Sara McAllister"
]
+++

<figure>
<img src="./e-commerce.png" alt="e-commerce heterogeneous graph" width="400"/>
<figcaption>Figure 1: Could we transfer knowledge from label-abundant node types (e.g., products) to zero-labeled node types (e.g., users) through rich relational information given in a heterogeneous graph?
</figcaption>
</figure>

**TL;DR:**
*Large technology companies commonly maintain large relational datasets representing a heterogeneous graph composed of multiple node and edge types. In many heterogeneous graphs from industrial applications, there is severe label imbalance between node types. Could we transfer knowledge from label-abundant node types to zero-labeled node types through rich relational information given in the heterogeneous graph?*

Data emitted from industrial ecosystems such as social or commerce platforms are commonly represented as heterogeneous graphs (HGs) composed of multiple node and edge types. For instance, an e-commerce network can be presented as a heterogeneous graph with *product*, *user*, and *review* node types and *user-buy-product*, *user-write-review*, and *review-on-product* edge types. Heterogeneous graph neural networks (HGNNs) learn powerful features representing the complex multimodal structure of HGs. HGNNs have shown state-of-the-art performance in various graph mining tasks such as link prediction, node classification, and clustering.

## How do HGNNs work?

HGNN is a graph encoder that uses the input HG as the basis for a neural network’s computation graph. At a high level, for any node \\(j\\), the embedding of node \\(j\\) at the \\(l\\)-th layer is obtained with the following generic formulation:
$$
\small
h_j^{(l)} = \textbf{Transform}^{(l)}\left(\textbf{Aggregate}^{(l)}(\mathcal{E}(j))\right)~~~~~~~~~(1)
$$
where \\(\small\mathcal{E}(j)\\) denotes all the edges which connect to \\(j\\). The above operations typically involve *type-specific parameters* to exploit the inherent multiplicity of modalities in HGs. We introduce the commonly-used versions of **Aggregate** and **Transform** for HGNNs below. First, we define a linear **Message** function:
$$
\small
\textbf{Message}^{(l)}(i, j) = M_{\phi((i, j))}^{(l)}\cdot \left(h_i^{(l-1)} ||~~h_j^{(l-1)}\right)~~~~~~~~~(2)
$$
Where \\(\small\phi((i, j))\\) denotes the type of the edge betwee nodes \\(i\\) and \\(j\\); and \\(\small M_{r}^{(l)}\\) are the specific message passing parameters for each edge type \\(\small r\in\mathcal{R}\\) and each layer \\(l\\). Then defining \\(\small\mathcal{E_r}(j)\\) as the set of edges of type \\(r\\) pointing to node \\(j\\), the **Aggregate** function mean-pools messages *by edge type*, and concatenates:
$$
\small
\textbf{Aggregate}^{(l)}(\mathcal{E}(j)) = \underset{r\in\mathcal{R}}{||}\tfrac{1}{|\mathcal{E_r}(j)|}\sum_{e\in\mathcal{E_r}(j)}\textbf{Message}^{(l)}(e)~~~~~~~~~(3)
$$
Finally, **Transform** maps the message into a *type-specific latent space*:
$$
\small
\textbf{Transform}^{(l)}(j) = \alpha(W_{\tau(j)}^{(l)}\cdot\textbf{Aggregate}^{(l)}(\mathcal{E}(j)))~~~~~~~~~(4)
$$
Where \\(\small\tau(j)\\) denotes the type of node \\(j\\). The final node representations can be fed into another model to perform downstream heterogeneous network tasks, such as node classification or link prediction. The above formulation of HGNNs allows for full handling of the complexities of a real-world heterogeneous graph.

## Label imbalance on heterogeneous graphs

A common issue in industrial applications of HGNNs is the label imbalance among different node types. For instance, publicly available content nodes — such as those representing video, text, and image content — are abundantly labeled, whereas labels for other types — such as user or account nodes — may be much more expensive to collect or even not available (e.g., due to privacy restrictions). This means that in most standard training settings, *HGNN models can only learn to make good inferences for a few label-abundant node types and can usually not make any inferences for the remaining node types*, given the absence of any labels for them. This problem reminds us of transfer learning which seeks to transfer knowledge from a source domain with abundant labels to a target domain which lacks them. In this case, what would be the source domain for zero-labeled node types?

## Limitation of previous graph-to-graph transfer learning approach

One body of work has focused on transferring knowledge between nodes of the same type from two different HGs (i.e., graph-to-graph transfer learning). However, these approaches are not applicable in many real-world scenarios for three reasons. *First,* any external HG that could be used in a graph-to-graph transfer learning setting would almost surely be proprietary. *Second,* even if practitioners could obtain access to an external industrial HG, it is unlikely the distribution of that source HG would match their target HG well enough to apply transfer learning. *Finally,* node types suffering label scarcity are likely to suffer the same issue on other HGs (e.g., privacy issues on user nodes).

## Zero-shot transfer learning for cross-type inference on a heterogeneous graph

In this work, we introduce a zero-shot transfer learning approach for a single HG (assumed to be fully owned by the practitioners), transferring knowledge from labeled to unlabelled node types. This setting is distinct from any graph-to-graph transfer learning scenario since the source and target domains exist in the same HG dataset and are assumed to have different node types. We utilize the shared context between source and target node types; for instance, in the e-commerce network, the (unknown) labels of *user* nodes can be strongly correlated with *buying/reviewing* patterns that are encoded in the cross-edges between *user* nodes and *product/review* nodes. We propose a novel zero-shot transfer learning problem for this HG learning setting as follows:

**Problem Definition 1. Zero-shot transfer learning for cross-type inference on an HG:**
Given a heterogeneous graph with node types \\(\{\mathbf{s}, \mathbf{t}, \cdots \}\\) with abundant labels for source type \\(\mathbf{s}\\) but no labels for target type \\(\mathbf{t}\\), can we train HGNNs to infer the labels of target-type nodes?

## Why is this problem hard to be solved?

A naïve solution to this problem would be to re-use an HGNN pre-trained on the source nodes for target node inference, given that both source and target nodes exist in the same HG. However, HGNNs have distinct parameter sets for each node type, edge type, or each meta-path type (see Equations 2, 3, 4). These facts cause HGNNs to learn entirely *different feature extractors for nodes of different types* — in other words, the final embeddings for source and target nodes are computed by different sets of parameters in HGNNs. Thus, a classifier pre-trained on source nodes will fail to perform well on inference tasks for target nodes. Let’s examine this argument on a toy heterogeneous graph.


### Different feature extractors for each node types in HGNNs

<figure>
<img src="./toy-hg.png" alt="toy heterogeneous graph" width="1000"/>
<figcaption>Figure 2: Illustration of a toy heterogeneous graph and the gradient paths for feature extractors of node types s and t. Colored arrows in figures (b) and (c) show that the same HGNN nonetheless produces different gradient paths for each feature extractor. The color density of each box in (b) and (c) is proportional to the degree of participation of the corresponding parameter in each feature extractor.
</figcaption>
</figure>

Figure 2(a) shows a toy heterogeneous graph with 2 node types \\(\small(s, t)\\) and 4 edge types \\(\small(ss, st, ts, tt)\\). Consider nodes \\(v_1\\) and \\(v_2\\). Using HGNN’s equations (2)-(4), for any \\(\small l\in\{0, \ldots, L-1\}\\), we have
$$
\small
h_1^{(l)} = W_s^{(l)}\left[M_{ss}^{(l)}\left(h_3^{(l-1)}|| h_1^{(l-1)}\right)|| M_{ts}^{(l)}\left(h_2^{(l-1)}|| h_1^{(l-1)}\right)\right]~~~~~~~~~(5)
$$
$$
\small
h_2^{(l)} = W_t^{(l)}\left[M_{st}^{(l)}\left(h_1^{(l-1)}|| h_2^{(l-1)}\right)|| M_{tt}^{(l)}\left(h_4^{(l-1)}|| h_2^{(l-1)}\right)\right]~~~~~~~~~(6)
$$
We see that \\(h_1^{(l)}\\) and \\(h_2^{(l)}\\), which are features of different node types, are extracted using disjoint sets of model parameters at \\(l\\)-th layer. In a 2-layer HGNN, this creates unique gradient backpropagation paths between the two node types, as illustrated in Figures 2(b) and (c). In other words, *even though the same HGNN is applied to node types \\(s\\) and \\(t\\), the final embeddings for source and target node types are computed by different sets of parameters in HGNNs*.



### Consequences of different feature extractors for each node type in HGNNs
<figure>
<img src="./toy-hg-experiment.png" alt="experiment on toy heterogeneous graph" width="1300"/>
<figcaption>
Figure 3: An HGNN trained on a source domain underfits a target domain even on a “nice" heterogeneous graph. (a) Performance on the simulated heterogeneous graph for 4 kinds of feature extractors (source: source extractor on source domain, target-src-path: source extractor on target domain, target-org-path: target extractor on target domain, and theoretical-KTN: target extractor on target domain using KTN). (b-c) L2 norms of gradients of parameters in the HGNN.
</figcaption>
</figure>

To study the experimental consequences, we construct a synthetic graph extending the toy graph in Figure 2(a) to have multiple nodes per type and multiple classes. To maximize the effects of having different feature extractors, we sample source and target nodes from the same input attribute distributions, and each class is well-separated in both the graph and attribute space.

On such a well-aligned HG, there may seem to be no need for transfer learning from node types \\(s\\) to \\(t\\). However, when we train the HGNN model solely on \\(s\\)-type nodes, as shown in Figure 3(a), we find the accuracy for \\(s\\)-type nodes to be high (90%, blue line) and the accuracy for \\(t\\)-type nodes to be quite low (25%, green line). Now, if instead, we make the \\(t\\)-type nodes use the source feature extractor — which is possible because the source and target nodes are sampled from the same input attribute space in this synthetic HG —, much more transfer learning is possible (∼65%, orange line). This shows that *the different feature extractors present in the HGNN model result in a significant performance drop*, and simply matching input data distributions can not solve the problem.

Figures 3(b-c) show the magnitude of gradients passed to parameters of each node type.
We find that the final-layer parameters for type-\\(t\\) nodes (\\(W_t^{(2)}\\) \\(M_{st}^{(2)}\\) and \\(M_{tt}^{(2)}\\)) have zero gradients, and the first-layer parameters for \\(t\\)-type nodes (\\(W_{t}^{(1)}, M_{st}^{(1)}\\) and \\(M_{tt}^{(1)}\\)) have much smaller gradients than their \\(s\\)-type counterparts (\\(W_{s}^{(1)}, M_{ts}^{(1)}\\) and \\(M^{(1)}_{ss}\\)). This is because they contribute to node type \\(s\\)’s feature extractor less than \\(t\\)’s feature extractor.

This case study shows that even when an HGNN is trained on a relatively simple, balanced, and class-separated heterogeneous graph, *a model trained only on the source node type cannot transfer to the target node type*.



## Motivation: Relationship between feature extractors

<figure>
<img src="./motivation.png" alt="motivation" width="300"/>
<figcaption>
Figure 4: Outputs of each feature extractors can be mathematically presented by each other using the previous layer embeddings as connecting points.
</figcaption>
</figure>

We show that an HGNN model provides different feature extractors for each node type. However,
still, those feature extractors are built inside one HGNN model and interchange intermediate feature embeddings with each other. As shown in Figure 4, Both \\(H^{(L)}_s\\) and \\(H^{(L)}_t\\) (outputs of each feature extractors) are computed using the previous layer’s intermediate embeddings \\(H^{(L−1)}_s , H^{(L−1)}_t\\), and any other connected node type embeddings \\(H^{(L−1)}_x\\) at the \\(L\\)-th HGNN layer. Therefore \\(H^{(L)}_s\\) and \\(H^{(L)}_t\\) can be mathematically presented by each other using the \\((L−1)\\)-th layer embeddings as connecting points. Based on this intuition, we derive a strict transformation between feature extractors of node type \\(s\\) and \\(t\\) as follows:

<figure>
<img src="./theorem.png" alt="motivation" width="800"/>
</figure>

The full proof of Theorem 1 can be found in the [original paper](https://arxiv.org/pdf/2203.02018.pdf). Notice that in Equation 8, \\(Q_{ts}^{\ast}\\) acts as a mapping matrix that maps \\(H_{t}^{(L)}\\) into the source domain, then \\(A_{ts}^{\ast}\\) aggregates the mapped embeddings into \\(s\\)-type nodes. To examine the implications, we run the same experiment as described in Figure 3, while this time mapping the target features \\(H_{t}^{(L)}\\) into the source domain by multiplying with \\(Q_{ts}^{\ast}\\) in Equation 8 before passing over to a task classifier. We see via the red line in Figure 3(a) that, with this mapping, the accuracy in the target domain becomes much closer to the accuracy in the source domain (∼70%). Thus, we use this theoretical transformation as a foundation for our trainable HGNN transfer learning module.

## **KTN**: Trainable Cross-Type Transfer Learning for HGNNs

Inspired by these derivations, we introduce our primary contribution, **Knowledge Transfer Networks**. We begin by noting Equation 8 in Theorem 1 has a similar form to a *single-layer graph convolutional network* with a deterministic transformation matrix (\\(Q_{ts}^{\ast}\\)) and a combination of adjacency matrices directing from target node type \\(t\\) to source node type \\(s\\) (\\(A_{ts}^\ast\\)). Instead of hand-computing the mapping function \\(Q_{ts}^{\ast}\\) for arbitrary HGs and HGNNs (which would be intractable), we learn the mapping function by modelling Equation 8 as a trainable graph convolutional network, named the Knowledge Transfer Network, \\(\small t_{KTN}(\cdot)\\). KTN replaces \\(Q_{ts}^{\ast}\\) and \\(A_{ts}^\ast\\) in Equation 8 as follows:
$$
\small
t_{KTN}(H_{t}^{(L)}) = A_{ts} H_{t}^{(L)} T_{ts}~~~~~~~~~(9)
$$
$$
\small
\mathcal{L_{KTN}} = || H_{s}^{(L)} - t_{KTN}(H_{t}^{(L)}) ||~~~~~~~~~(10)
$$
where \\(A_{ts}\\) is an adjacency matrix from node type \\(t\\) to \\(s\\), and \\(T_{ts}\\) is a trainable transformation matrix. By minimizing \\(\small\mathcal{L_{KTN}}\\), \\(T_{ts}\\) is optimized to a mapping function of the target domain into the source domain. We minimize a classification loss \\(\small\mathcal{L_{CL}}\\) and a transfer loss \\(\small\mathcal{L_{KTN}}\\) jointly with regard to a HGNN model \\(f\\), a classifier \\(g\\), and a knowledge transfer network \\(t_{KTN}\\) as follows:

$$
\small
\underset{f,~g,~t_{KTN}}{min}\mathcal{L_{CL}}(g(f(X_{s})), Y_{s}) + \lambda || f(X_{s}) - t_{KTN}(f(X_{t})) ||~~~~~~~~~(11)
$$
where \\(\lambda\\) is a hyperparameter regulating the effect of \\(\small\mathcal{L_{KTN}}\\). During a training step on the source domain, after computing the node embeddings \\(H_{s}^{(L)}\\) and \\(H_{t}^{(L)}\\), we map \\(H_{t}^{(L)}\\) to the source domain using \\(t_{KTN}\\) and compute \\(\small\mathcal{L_{KTN}}\\). Then, we update the models using gradients of \\(\small\mathcal{L_{CL}}\\) (computed using only source labels) and \\(\small\mathcal{L_{KTN}}\\). During the test phase on the target domain, after we get node embeddings \\(H_{t}^{(L)}\\) from the trained HGNN model, we map \\(H_{t}^{(L)}\\) into the source domain using the trained transformation matrix \\(T_{ts}\\). Finally, we pass the transformed target embeddings \\(H_{t}^{(L)}T_{ts}\\) into the classifier \\(g\\), which was trained on the source domain.

## Experiments

<figure>
<img src="./oag-experiment.png" alt="experiment on oag" width="1000"/>
<figcaption>
Table 1: Open Academic Graph on Computer Science field. The gain column shows the relative gain of our method over using no transfer learning (Base column). o.o.m denotes out-of-memory errors.
</figcaption>
</figure>

To examine the effectiveness of our proposed KTN, we run 8 different zero-shot transfer learning tasks on a public heterogeneous graph.

**Dataset:** Open Academic Graph (OAG) is composed of five types of nodes: *papers, authors, institutions, venues, fields* and their corresponding relationships. *Paper* and *author* nodes have text-based attributes, while *institution, venue,* and *field* nodes have text- and graph structure-based attributes. *Paper, author,* and *venue* nodes are labeled with research fields in two hierarchical levels, L1 and L2.

**Baseline:** We compare KTN with two MMD-based domain adaptation methods (DAN, JAN), three adversarial domain adaptation methods (DANN, CDAN, CDAN-E), one optimal transport-based method (WDGRL), and two traditional graph mining methods (LP and EP).

**Experimental setting:** Each heterogeneous graph has node classification tasks for both source and target node types. Only source node types have labels, while target node types have none during training. The performance is evaluated by NDCG and MRR.

In Table 1, our proposed method KTN consistently outperforms all baselines on all tasks and graphs by up to 73.3% higher in MRR. When we compare with the base accuracy using the model pretrained on the source domain without any transfer learning (3rd column, Base), the results are even more impressive. We see our method KTN provides relative gains of up to 340% higher MRR without using any labels from the target domain. These results show the clear effectiveness of KTN on zero-shot transfer learning tasks on a heterogeneous graph

## Conclusion

In this work, we proposed a novel and practical transfer learning method for heterogeneous graphs. To the best of our knowledge, KTN is the first cross-type transfer learning method designed for heterogeneous graphs. KTN is a principled approach analytically induced from the architecture of HGNNs, thus applicable to any HGNN models.

For more details about KTN, check out [our paper](https://arxiv.org/pdf/2203.02018.pdf).


