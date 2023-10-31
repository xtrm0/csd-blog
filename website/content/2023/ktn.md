+++
# The title of your blogpost. No sub-titles are allowed, nor are line-breaks.
title = "Transfer Learning within a Heterogeneous Graph"
# Date must be written in YYYY-MM-DD format. This should be updated right before the final PR is made.
date = 2023-10-31

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

### Can we transfer knowledge between different data types using their connectivity information?

Ecosystems in industry are commonly composed of various data types in terms of data modalities or feature distributions. **Heterogeneous graphs** (HGs) present these multimodal data systems in a unified view by defining multiple types of nodes and edges — for instance, e-commerce networks with (*user, product, review*) nodes or video platforms with (*channel, user, video, comment*) nodes. **Heterogeneous graph neural networks** (HGNNs) learn node embeddings, which summarize each node’s heterogeneous local structure into a vector. Unfortunately, there is a **label imbalance** issue between different node types in real-world HGs. For instance, publicly available content node types such as product nodes are abundantly labeled, whereas labels for user or account nodes may not be available due to privacy restrictions. Because of this, label-scarce node types cannot exploit HGNNs, hampering the broader applicability of HGNNs.

In this blog, we introduce how to pre-train an HGNN model on label-abundant node types and then transfer the model to label-scarce node types using relational information given in HGs. You can find details of the work in our paper “*Zero-shot Transfer Learning within a Heterogeneous Graph via Knowledge Transfer Networks*” [1], presented at NeurIPS 2022.

## What is a heterogeneous graph (HG)?
<figure>
<img src="./figure1.png" alt="e-commerce heterogeneous graph" width="400"/>
<figcaption>Figure 1. E-commerce heterogeneous graph: Can we transfer knowledge from label-abundant node types (e.g., products) to zero-labeled node types (e.g., users) through relational information given in a heterogeneous graph?
</figcaption>
</figure>

An HG is composed of multiple node and edge types. Figure 1 shows an e-commerce network presented as an HG. In e-commerce, “users” purchase “products” and write “reviews”. HG presents this ecosystem using three node types (“user”, “product”, “review”) and three edge types (“user-buy-product”, “user-write-review”, review-on-product”). Individual products, users, and reviews are then presented as nodes and their relationships as edges in the HG with the corresponding node/edge types.

In addition to all relational information, HGs are commonly provided with *input node attributes* that summarize each node’s information. For instance, product nodes could have product images as input node attributes, while review nodes could have review texts as their input attributes. As in the example, input node attributes could have different modalities across different node types.  The goal is to predict *node labels* on each node, such as the category of each product or the category each user is most interested in.

In the following section, we introduce the main challenge we face while training HGNNs to predict labels using input node attributes and relational information from HGs.

## Heterogeneous graph neural networks (HGNNs) and label scarcity issues
HGNNs compute node embeddings that summarize each node’s local graph structures including the node and its neighbor’s input attribute distributions. Node embeddings are then fed into a classifier to predict each node’s label. To train an HGNN model and a classifier to predict labels for a specific node type, we require a good amount of labels for the node type.

A common issue in real-world applications of deep learning is label scarcity. With their diverse node types, HGNNs are even more likely to face this challenge. For instance, publicly available content node types are abundantly labeled, whereas labels for user nodes may not be available due to privacy restrictions. This means that in most standard training settings, HGNN models can only learn to make good inferences for a few label-abundant node types and can usually not make any inferences for the remaining node types, given the absence of any labels for them.

To solve this label scarcity issue, we will use a technique called zero-shot transfer learning that improves the performance of a model on a zero-labeled domain.

## Transfer Learning on Heterogeneous Graphs
To improve the performance on a zero-labeled “target” domain, transfer learning exploits the knowledge earned from a related “source” domain, which has adequate labeled data. For instance, transfer learning on heterogeneous graphs first trains an HGNN model on the source domain using their labels, then reuses the HGNN model on the target domain.

In order to apply transfer learning on heterogeneous graphs to solve the label scarcity issue we described above, it is clear the target domain should be the zero-labeled node types. The question remained of what would be the source domain. Previous works commonly set the source domain as the same type of nodes but located in an external HG, assuming those nodes are abundantly labeled (Figure 2). For instance, the source domain is user nodes in the Yelp review graph, while the target domain is user nodes in the Amazon e-commerce graph. This approach, also known as *graph-to-graph transfer learning*, pre-trains an HGNN model on the external HG and then runs the model on the original label-scarce HG [2, 3].

<center>
<figure>
<img src="./figure2.png" alt="graph-to-graph transfer learning" width="600"/>
<figcaption>Figure 2. Illustration of graph-to-graph transfer learning on heterogeneous graph.</figcaption>
</figure>
</center>

However, this approach is not applicable in many real-world scenarios for three reasons. First, any external HG that could be used in a graph-to-graph transfer learning setting would almost surely be *proprietary*, thereby, making it hard to get access to. Second, even if practitioners could obtain access to an external HG, it is unlikely that the *distribution of the external HG* would match our target HG well enough to apply transfer learning. Finally, node types suffering from *label scarcity* are likely to suffer the same issue on other HGs. For instance, user nodes on the external HG also have scarce labels with privacy constraints.

## Our approach: transfer learning between node types within a heterogeneous graph
To overcome the limitation of usage of external HGs for transfer learning, we introduce a practical source domain, *other node types with abundant labels located on the same HG*. Instead of using extra HGs, we transfer knowledge across different types of nodes within a single HG assumed to be fully owned by the practitioners. More specifically, we first pre-train an HGNN model and a classifier on a label-abundant “source” node type. Then, we reuse the models on the zero-labeled “target” node types located in the same HG without additional finetuning. The one requirement for this approach is that the source and target node types share the same label set. This requirement is frequently satisfied in real-world settings. For instance, product nodes have a label set describing product categories, and user nodes share the same label set describing their favorite shopping categories in e-commerce HGs.

## Main technical challenge
We now describe the main challenge in realizing our approach. We cannot directly reuse the pretrained HGNN and classifier on the target node type as described above because HGNN maps the source and target embeddings into the different embedding spaces.

<figure>
<img src="./figure3.png" alt="l2 norm of gradients passed to each module in the HGNN" width="450"/>
<figcaption>
Figure 3. The L2 norm of gradients passed to each module in the HGNN while pretraining on the source node type. Green and Red lines show large amounts of gradients passed to source node type-specific modules, while blue and orange lines show little or no gradients passed to target type-specific modules.
</figcaption>
</figure>

This happens because of one crucial characteristic of HGNNs — HGNNs are composed of modules specialized to each node type and use distinct sets of modules to compute embeddings for each node type. During pretraining HGNNs on the source node type, modules specialized to the source node type are well-trained, while modules specialized to the target node are untrained or under-trained. In Figure 3, we can observe the source modules (green and red lines) receive high L2 norms of gradients during pretraining. On the other hand, because of the specialization, the target modules (orange and blue lines) receive little or no gradients. With under-trained modules for the target node type, the pretrained HGNN model outputs poor node embeddings for the target node type, and, consequently, poor performance on the node prediction task.

## KTN: Trainable Cross-Type Transfer Learning for HGNNs
Now, we introduce a method to transform the under-trained poor embeddings of the target node type to follow source embeddings. This allows us to reuse the classifier that was trained on source node types. In order to derive the transformation in a principled manner, let us look into how HGNNs compute node embeddings and analyze the relationship between source and target embeddings.

<figure>
<img src="./figure4.png" alt="HGNN structure" width="600"/>
<figcaption>
Figure 4. (left) In HGNNs, the final L-layer node embeddings for both source and target types are computed using the same input, the previous (L-1)-layer’s node embeddings. (right) The L-layer node embeddings of the source type (product, blue) can be represented by the L-layer node embeddings of the target type (user, red) using (L-1)-layer node embeddings as intermediate values.
</figcaption>
</figure>

In each layer, HGNNs aggregate connected nodes’ embeddings from the previous layer to update each target node’s embeddings. Node embeddings for both source and target node types are updated using the same input: the previous layer’s node embeddings of any connected node types (Figure 4, left). This means that they can be represented by each other using the previous layer embeddings as intermediate values (Figure 4, right).

We prove there is a mapping matrix from the target domain to the source domain, which is defined by HGNN parameters (Theorem 1 in [1]). Based on this theorem, we introduce an auxiliary network, named Knowledge Transfer Networks (KTN), that learns the mapping matrix from scratch during pretraining HGNN on the source domain. At test time, we first compute target embeddings using the pretrained HGNN, then map the target embeddings to the source domain using our trained KTN. Finally, we can reuse the classifier with transformed target embeddings.

## Experimental results

<figure>
<img src="./figure5.png" alt="zero-shot transfer learning results on OAG and Pubmed" width="600"/>
<figcaption>
Figure 5. Zero-shot transfer learning performance measured in NDCG on Open Academic Graph (OAG) and Pubmed datasets. Higher is better. Our proposed method KTN (red bar) shows the highest accuracy among all baselines.
</figcaption>
</figure>

To examine the effectiveness of our proposed KTN, we ran 18 different zero-shot transfer learning tasks on two public heterogeneous graphs, Open Academic Graph [4] and Pubmed [5]. We compare KTN with 8 state-of-the-art transfer learning methods. We show our results in Figure 5. Our proposed method KTN consistently outperforms all baselines on all tasks by up to 73.3%. The naive approach we discussed earlier — reuse the pretrained models directly on the target domain without any transfer learning — is presented as blue bar. We see our method KTN provides relative gains of up to 340% higher than the naive approach without using any labels from the target domain.

<figure>
<img src="./figure6.png" alt="KTN with 6 different HGNN models" width="450"/>
<figcaption>
Figure 6. KTN can be applied to 6 different HGNN models and improve their zero-shot performance on target domains. Performance is measured in NDCG. Higher is better.
</figcaption>
</figure>

KTN can be applied to almost all HGNN models that have node/edge type-specific modules and improve their zero-shot performance on target domains. In Figure 6, KTN improves accuracy on zero-labeled node types across 6 different HGNN models by up to 960%.

## Takeaway:
Various real-world applications can be presented as heterogeneous graphs. Heterogeneous graph neural networks (HGNNs) are an effective technique for summarizing heterogeneous graphs into concise embeddings. However, label scarcity issues on certain types of nodes have prevented the broader application of HGNNs. In this post, we introduced KTN, the first cross-type transfer learning method designed for HGNNs. With KTN, we can fully exploit the rich relational information of heterogeneous graphs with HGNNs on any nodes regardless of their label scarcity.

For more details about KTN, check out our paper [1].


[1] Minji Yoon, John Palowitch, Dustin Zelle, Ziniu Hu, Ruslan Salakhutdinov, Bryan Perozzi. *Zero-shot Transfer Learning within a Heterogeneous Graph via Knowledge Transfer Networks*, Neural Information Processing Systems (NeurIPS) 2022.

[2] Tiancheng Huang, Ke Xu, and Donglin Wang. *Da-hgt: Domain adaptive heterogeneous graph transformer.* arXiv preprint arXiv:2012.05688, 2020.

[3] Shuwen Yang, Guojie Song, Yilun Jin, and Lun Du. *Domain adaptive classification on heterogeneous information networks.* International Joint Conferences on Artificial Intelligence (IJCAI) 2021.

[4] Fanjin Zhang, Xiao Liu, Jie Tang, Yuxiao Dong, Peiran Yao, Jie Zhang, Xiaotao Gu, Yan Wang, Bin Shao, Rui Li, et al. *Oag: Toward linking large-scale heterogeneous entity graphs.* In Proceedings of the 25th ACM SIGKDD International Conference on Knowledge Discovery & Data Mining 2019.

[5] Carl Yang, Yuxin Xiao, Yu Zhang, Yizhou Sun, and Jiawei Han. *Heterogeneous network representation learning: A unified framework with survey and benchmark.* IEEE Transactions on Knowledge and Data Engineering, 2020.


