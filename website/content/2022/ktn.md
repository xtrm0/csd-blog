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
<figcaption>Figure 1. E-commerce heterogeneous graph: Can we transfer knowledge from label-abundant node types (e.g., products) to zero-labeled node types (e.g., users) through rich relational information given in a heterogeneous graph?
</figcaption>
</figure>

Large technology companies commonly maintain large relational datasets representing a heterogeneous graph (HG) composed of multiple node and edge types. Figure 1 shows an e-commerce network presented as a heterogeneous graph with *product*, *user*, and *review* node types and *user-buy-product*, *user-write-review*, and *review-on-product* edge types. Heterogeneous graph neural networks (HGNNs) learn powerful features representing the complex multimodal structure of HGs, and thus have garnered huge attention across industries. However, many HG datasets from industrial applications suffer from label imbalance between node types. As there is no direct way to learn using labels rooted at different node types, HGNNs have been applied to only a few node types with abundant labels. In this work, we propose a zero-shot transfer learning module for HGNNs called a Knowledge Transfer Network (KTN) that transfers knowledge from label-abundant node types to zero-labeled node types through rich relational information given in the HG.
KTN improves HGNN performance on zero-labeled node types by up to 340%.

## What are heterogeneous graph neural networks?
One of the most successful deep learning models combining graph information is graph neural networks (GNNs).
GNNs complement each node embeddings with their neighboring node embeddings, assuming neighboring nodes are relevant, thus their information would help to improve a target node’s embedding.
Heterogeneous graph neural networks (HGNNs) extend how GNNs work on homogeneous graphs by providing different modules for each node/edge type.
At a high level, HGNNs learn each node's embeddings by 1) computing messages on each edge with *edge-type-specific* parameters, 2)aggregating the computed messages across different edge types, and 3) finally transforming the aggregated messages into the *node-type-specific* embedding space. Formally, for any node \\(j\\), the embedding of node \\(j\\) at the \\(l\\)-th HGNN layer is obtained with the following generic formulation:
$$
\small
h_j^{(l)} = \textbf{Transform}^{(l)}\left(\textbf{Aggregate}^{(l)}(\mathcal{E}(j))\right)~~~~~~~~~(1)
$$
where \\(\small\mathcal{E}(j)\\) denotes all the edges which connect to \\(j\\).
Here we introduce the commonly-used versions of **Aggregate** and **Transform** for HGNNs.
First, we define a linear **Message** function that computes a message on each edge with the connected nodes' information:
$$
\small
\textbf{Message}^{(l)}(i, j) = M_{\phi((i, j))}^{(l)}\cdot \left(h_i^{(l-1)} ||~~h_j^{(l-1)}\right)~~~~~~~~~(2)
$$
where \\(\small\phi((i, j))\\) denotes the type of the edge between nodes \\(i\\) and \\(j\\); and \\(\small M_{r}^{(l)}\\) are the message-passing parameters specific for each edge type \\(\small r\in\mathcal{R}\\) and each layer \\(l\\). Then defining \\(\small\mathcal{E_r}(j)\\) as the set of edges of type \\(r\\) pointing to node \\(j\\), the **Aggregate** function mean-pools messages by each edge type, then concatenates them:
$$
\small
\textbf{Aggregate}^{(l)}(\mathcal{E}(j)) = \underset{r\in\mathcal{R}}{||}\tfrac{1}{|\mathcal{E_r}(j)|}\sum_{e\in\mathcal{E_r}(j)}\textbf{Message}^{(l)}(e)~~~~~~~~~(3)
$$
Finally, **Transform** maps the message into a *node-type-specific latent space*:
$$
\small
\textbf{Transform}^{(l)}(j) = \alpha(W_{\tau(j)}^{(l)}\cdot\textbf{Aggregate}^{(l)}(\mathcal{E}(j)))~~~~~~~~~(4)
$$
where \\(\small\tau(j)\\) denotes the type of node \\(j\\); \\(\small W_{t}^{(l)}\\) are the transformation parameters specific for each node type \\(\small t\in\mathcal{T}\\) and each layer \\(l\\); and \\(\alpha\\) is a nonlinear function.
By stacking HGNN blocks for \\(L\\) layers, each node aggregates a larger proportion of nodes — with different types
and relations — in the full graph, which generates highly contextualized node representations.
The final node representations \\(h_i^{(L)}\\) are then fed into another model to perform downstream heterogeneous network tasks, such as node classification or link prediction.
Note that HGNNs involve *node/edge-type-specific parameters,* \\(\small M_{r}^{(l)}\\) and \\(\small W_{t}^{(l)}\\) to exploit the inherent multiplicity of modalities in HGs.

## Label scarcity issue on HGNNs

A common issue in industrial applications of deep learning is label scarcity, and with their diverse node types, HGNNs are even more likely to face the challenge.
For instance, publicly available content node types — such as those representing video, text, and image content — are abundantly labeled, whereas labels for other types — such as user or account nodes — may be not available due to privacy restrictions.
This means that in most standard training settings, HGNN models can only learn to make good inferences for a few label-abundant node types and can usually not make any inferences for the remaining node types, given the absence of any labels for them.

The field of *transfer learning* targets this setting, seeking to transfer knowledge from a source domain with
abundant labels to a target domain that lacks them.
In this case, the target domain is the zero-labeled node type on a heterogeneous graph.
Then what would be the source domain?

## Limitation of previous graph-to-graph transfer learning approach

Previous works commonly set the source domain for nodes of a zero-labeled type as *nodes of the same type from a different HG (i.e., graph-to-graph transfer learning)*, assuming nodes of the same type on another HG have abundant labels.
However, these approaches are not applicable in many real-world scenarios for three reasons.
*First,* any external HG that could be used in a graph-to-graph transfer learning setting would almost surely be proprietary, thus hard to get access.
*Second,* even if practitioners could obtain access to an external HG, it is unlikely the distribution of that source HG would match their target HG well enough to apply transfer learning;
for instance, purchasing patterns of *user* nodes in e-commerce networks would less likely follow similar distributions with following patterns of *user* nodes in social networks.
*Finally,* node types suffering label scarcity are likely to suffer the same issue on other HGs (e.g., privacy issues on user nodes).

## Zero-shot cross-type transfer learning on a heterogeneous graph

Here, we shed light on a more practical source domain, *other node types with abundant labels on the same HG*, and define a novel transfer learning problem on HGNNs as follows:

**Problem Definition.**
Given a heterogeneous graph with node types \\(\{\mathbf{s}, \mathbf{t}, \cdots \}\\) with abundant labels for source type \\(\mathbf{s}\\) but no labels for target type \\(\mathbf{t}\\), can we train HGNNs using type \\(\mathbf{s}\\)'s labels to infer the type \\(\mathbf{t}\\)'s labels?

Instead of using additional HGs, we transfer knowledge within a single HG (assumed to be fully owned by the practitioners) across different types of nodes (possibly with different modalities).
This new problem definition utilizes the shared context between source and target node types hidden in the HG.
For instance, in the e-commerce network, labels of *user* nodes can be strongly correlated with *purchasing/reviewing* patterns that are encoded in the cross-edges between *user* nodes and *product/review* nodes.

## Why is this problem hard to solve?

This problem seems very trivial at first glance: just re-use an HGNN model pre-trained on the source nodes for target node inference, given that both source and target nodes exist in the same HG.
However, HGNNs have distinct parameter sets for each node and edge types (\\(\small W_{t}^{(l)}\\) and \\(\small M_{r}^{(l)}\\) in Equations 2, 3, 4).
These facts cause HGNNs to learn entirely *different feature extractors for different node types*.

<figure>
<img src="./toy-hg.png" alt="toy heterogeneous graph" width="800"/>
<figcaption>Figure 2. Illustration of a toy heterogeneous graph and the gradient paths for feature extractors of node types s and t: Colored arrows in figures (b) and (c) show that the same HGNN nonetheless produces different gradient paths for each feature extractor. The color density of each box in (b) and (c) is proportional to the degree of participation of the corresponding parameter in each feature extractor.
</figcaption>
</figure>

Figure 2(a) shows a toy heterogeneous graph with 2 node types \\(\small(s, t)\\) and 4 edge types \\(\small(ss, st, ts, tt)\\). Consider nodes \\(v_1\\) and \\(v_2\\) of two different node types. Using HGNN’s equations (2)-(4), we have
$$
\small
h_1^{(l)} = W_s^{(l)}\left[M_{ss}^{(l)}\left(h_3^{(l-1)}|| h_1^{(l-1)}\right)|| M_{ts}^{(l)}\left(h_2^{(l-1)}|| h_1^{(l-1)}\right)\right]~~~~~~~~~(5)
$$
$$
\small
h_2^{(l)} = W_t^{(l)}\left[M_{st}^{(l)}\left(h_1^{(l-1)}|| h_2^{(l-1)}\right)|| M_{tt}^{(l)}\left(h_4^{(l-1)}|| h_2^{(l-1)}\right)\right]~~~~~~~~~(6)
$$
We see that \\(h_1^{(l)}\\) and \\(h_2^{(l)}\\), which are features of different node types, are extracted using disjoint sets of model parameters at \\(l\\)-th layer: \\(\small\{W_s^{(l)}, M_{ss}^{(l)}, M_{ts}^{(l)}\}\\) are used for \\(h_1^{(l)}\\), while \\(\small\{W_t^{(l)}, M_{st}^{(l)}, M_{tt}^{(l)}\}\\) are used for \\(h_2^{(l)}\\).
In a 2-layer HGNN, this creates unique gradient backpropagation paths between the two node types, as illustrated in Figures 2(b) and (c). In other words, *even though the same HGNN is applied to node types \\(s\\) and \\(t\\), the final embeddings of each node type are computed by different sets of parameters in the HGNN*.

HGNNs have different update equations for each node type during training and project each type's node features into different latent spaces.
Therefore HGNNs pre-trained on source node types will fail to perform well on inference tasks for target node types.

<!--
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
-->


## Motivation: Relationship between feature extractors

We show that an HGNN model provides different feature extractors for each node type.
However, still, those feature extractors are built inside one HGNN model and interchange intermediate feature embeddings with each other (see \\(\small h_{1}^{(l)}\\) of node type \\(s\\) is computed using \\(\small h_{2}^{(l-1)}\\) of node type \\(t\\) in Equation 5).
What is the relationship between those intertwining feature extractors?

<figure>
<img src="./motivation.png" alt="motivation" width="250"/>
<figcaption>
Figure 3. HGNN's computation graph: Output of each feature extractor (i.e., last layer embeddings) can be mathematically presented by each other using the previous layer embeddings as connecting points.
</figcaption>
</figure>

Defining \\(\small H_t^{(l)}\\) as the hidden embedding matrix of \\(t\\)-type nodes at the \\(l\\)-th layer, Figure 4 shows how three node types \\((s, t, x)\\) interchange intermediate feature embeddings in the last three hidden layers in HGNNs.
Both \\(\small H_s^{(L)}\\) and \\(\small H_t^{(L)}\\) are computed using the previous layer’s embeddings \\(\small H_s^{(L−1)} , H_t^{(L−1)}, H_x^{(L−1)}\\) at the \\(\small L\\)-th HGNN layer.
In other words, \\(\small H_s^{(L)}\\) and \\(\small H_t^{(L)}\\), outputs of each feature extractors can be mathematically presented by each other using the \\(\small(L−1)\\)-th layer embeddings as connecting points.
Based on this observation, we derive a strict transformation between feature extractors of node type \\(s\\) and \\(t\\) as follows:

<figure>
<img src="./theorem.png" alt="motivation" width="600"/>
</figure>

The proof can be found in the [original paper](https://arxiv.org/pdf/2203.02018.pdf).
In Equation 8, \\(Q_{ts}^{\ast}\\) acts as a mapping matrix that maps \\(H_{t}^{(l)}\\) into the source domain, then \\(A_{ts}^{\ast}\\) aggregates the mapped embeddings into \\(s\\)-type nodes.
EUREKA! We now can re-use an HGNN model pre-trained on the source domain by projecting the target embeddings into the source domain using \\(Q_{ts}^{\ast}\\).
Unfortunately, \\(Q_{ts}^{\ast}\\) is too complicated to hand-compute every time new HGs and HGNNs arrive.
Instead, can we learn it automatically?

<!--
To examine the implications, we run the same experiment as described in Figure 3, while this time mapping the target features \\(H_{t}^{(L)}\\) into the source domain by multiplying with \\(Q_{ts}^{\ast}\\) in Equation 8 before passing over to a task classifier. We see via the red line in Figure 3(a) that, with this mapping, the accuracy in the target domain becomes much closer to the accuracy in the source domain (∼70%). Thus, we use this theoretical transformation as a foundation for our trainable HGNN transfer learning module.
-->


## **KTN**: Trainable Cross-Type Transfer Learning for HGNNs

Note that Equation 8 in Theorem 1 has a similar form to a *single-layer graph convolutional network* with a deterministic transformation matrix (\\(Q_{ts}^{\ast}\\)) and a combination of adjacency matrices directing from target node type \\(t\\) to source node type \\(s\\) (\\(A_{ts}^\ast\\)).
We learn the mapping function \\(Q_{ts}^{\ast}\\) by modeling Equation 8 as a trainable graph convolutional network, named the Knowledge Transfer Network, \\(\small t_{KTN}(\cdot)\\).
KTN replaces \\(Q_{ts}^{\ast}\\) and \\(A_{ts}^\ast\\) in Equation 8 as follows:
$$
\small
t_{KTN}(H_{t}^{(L)}) = A_{ts} H_{t}^{(L)} T_{ts}~~~~~~~~~(9)
$$
$$
\small
\mathcal{L_{KTN}} = || H_{s}^{(L)} - t_{KTN}(H_{t}^{(L)}) ||~~~~~~~~~(10)
$$
where \\(A_{ts}\\) is an adjacency matrix from node type \\(t\\) to \\(s\\), and \\(T_{ts}\\) is a trainable transformation matrix.
By minimizing a transfer loss \\(\small\mathcal{L_{KTN}}\\), \\(T_{ts}\\) is optimized to a mapping function \\(Q_{ts}^{\ast}\\) of the target domain into the source domain.

During the training phase on the source domain, we minimize the transfer loss jointly with the HGNN performance loss, which is computed only using source labels.
During the test phase on the target domain, after we get target node embeddings \\(\small H_{t}^{(L)}\\) from the pretrained HGNN model, we map \\(\small H_{t}^{(L)}\\) into the source domain using the trained transformation matrix \\(T_{ts}\\).
Finally, we pass the transformed target embeddings \\(\small H_{t}^{(L)}\circ T_{ts}\\) into a classifier that was trained on the source domain.

## Experimental results

<figure>
<img src="./oag-experiment.png" alt="experiment on oag" width="800"/>
<figcaption>
Table 1. Zero-shot transfer learning on Open Academic Graph: *gain* column shows the relative gain of our method over using no transfer learning (*Base* column). o.o.m denotes out-of-memory errors.
</figcaption>
</figure>

To examine the effectiveness of our proposed KTN, we run 8 different zero-shot transfer learning tasks on a public heterogeneous graph, Open Academic Graph, composed of five node types and ten edge types.
We compare KTN with two MMD-based domain adaptation methods (DAN, JAN), three adversarial domain adaptation methods (DANN, CDAN, CDAN-E), one optimal transport-based method (WDGRL), and two traditional graph mining methods (LP and EP).
In Table 1, our proposed method KTN consistently outperforms all baselines on all tasks by up to 73.3% higher in MRR. When we compare with the base accuracy using the model pretrained on the source domain without any transfer learning (3rd column, *Base*), the results are even more impressive. We see our method KTN provides relative gains of up to 340% higher MRR without using any labels from the target domain. These results show the clear effectiveness of KTN on zero-shot transfer learning tasks on a heterogeneous graph.

## Conclusion

In this post, we introduced a novel and practical transfer learning method for heterogeneous graphs.
To the best of our knowledge, KTN is the first cross-type transfer learning method designed for HGNNs.
KTN is a principled approach analytically induced from the architecture of HGNNs, thus applicable to any HGNN models.

For more details about KTN, check out [our paper](https://arxiv.org/pdf/2203.02018.pdf).


