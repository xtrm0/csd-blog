+++
# The title of your blogpost. No sub-titles are allowed, nor are line-breaks.
title = "Measuring and Exploiting Network Usable Information"
# Date must be written in YYYY-MM-DD format. This should be updated right before the final PR is made.
date = 2024-04-09

[taxonomies]
# Keep any areas that apply, removing ones that don't. Do not add new areas!
areas = ["Artificial Intelligence"]
# Tags can be set to a collection of a few keywords specific to your blogpost.
# Consider these similar to keywords specified for a research paper.
tags = ["graph-mining", "information-theory"]

[extra]
# For the author field, you can decide to not have a url.
# If so, simply replace the set of author fields with the name string.
# For example:
#   author = "Harry Bovik"
# However, adding a URL is strongly preferred
author = {name = "Meng-Chieh Lee", url = "https://mengchillee.github.io/" }
# The committee specification is simply a list of strings.
# However, you can also make an object with fields like in the author.
committee = [
    "Committee Member 1's Full Name",
    "Committee Member 2's Full Name",
    {name = "Harry Q. Bovik", url = "http://www.cs.cmu.edu/~bovik/"},
]
+++

Given a graph with node features, how can we tell whether a message-passing method can perform well on graph tasks or not? How can we know what information in the graph (if any) is usable to solve the tasks, namely, link prediction and node classification? 
Graph Neural Networks (GNNs) are frequently used for graph tasks by generating low-dimensional node embeddings.
However, an attributed graph, consisting of the graph structure and the node features, may have no network effects (i.e., useless graph structure), or useless node features. In these cases, training a GNN will be a waste of time and resources, especially for large cloud service providers like AWS, whose customers would like to perform the tasks with restricted budgets in a short time. That is to say, we want a measurement of how informative the graph structure and node features are for the task at hand, which we call network usable information (NUI).

In this blog post, we introduce how to measure the information in the graph, and to exploit it for solving the graph tasks. This blog post is based on our research paper, “NetInfoF Framework: Measuring and Exploiting Network Usable Information” [1], presented at ICLR 2024.

## What is an attributed graph?

<figure>
<img src="./figure1.png" alt="attributed graph" width="400"/>
<figcaption>
Figure 1. An example of an attributed social network graph, where the nodes denote the users, and the edges denote whether two users are friends.
</figcaption>
</figure>

A graph is a data structure that includes nodes, and edges, representing the connections between nodes.
An attributed graph indicates that each node in the graph has a set of features.
For example, in Figure 1, in a social network, the nodes (circles with school icons) denote the users, and the edges (black lines connecting circles) denote whether two users are friends.
The node IDs are represented by the thumbnail person images and the text names.
The node attributes/features of users (2 \\( \times \\) 2 tables) are whether they are located in the US and whether they like to bike. 
The node labels of users, classified into two categories represented by blue and red colors, signify their respective colleges, CMU or NCTU.
In fact, node labels are similar to node features, but they are the ones with missing values and we are interested in predicting them.

<figure>
<img src="./figure2.png" alt="mathematical representation of graph" width="500"/>
<figcaption>
Figure 2. The mathematical representation of the attributed graph, including an adjacency matrix, node features, and node labels. The red question mark denotes unknown.
</figcaption>
</figure>

The graph structure can be represented by an adjacency matrix, where 1 denotes the presence of an edge between two nodes, and 0 denotes no edge. 
The node features are also presented by a matrix, where each feature can be either binary or continuous. 
The node labels are presented by a matrix with one-hot encoding of the class label.

## What are the common graph tasks?

We consider the two most common graph tasks:
- **Node Classification**
    - *Goal:* Predict the classes of the unlabeled nodes, while some labeled nodes are given.
    - *Example:* Given a social network with features, can we guess which college Bob goes to, i.e., the label of the gray node in Figure 1?
- **Link Prediction**
    - *Goal:* Predict the potential additional edges in the graph.
    - *Example:* Given a social network with features, can we guess whether David and Grace could become friends, i.e., the existence of the red dash line in Figure 1? 

## What are message-passing methods?

<!-- | U<sub>[n×r]</sub> | Left singular vectors of adjacency matrix | -->
<!-- | r | Rank for matrix decomposition | -->

<figure>
<img src="./figure3.png" alt="node embedding" width="400"/>
<figcaption>
Figure 3. Illustration of how the nodes in a given graph projected into low-dimensional embedding space. The nodes that are more similar in the graph are closer in the embedding space.
</figcaption>
</figure>

Message-passing methods utilize the graph structure to propagate the information from the neighbors of a node to itself. Known as sum-product message-passing, belief propagation methods directly perform inference on the graph through several propagation iterations, requiring neither parameters nor training. To properly handle the interaction between node classes, [2] assumes that a c×c compatibility matrix is given by the domain expert, while [3] estimates it with the given graph data. Although belief propagation methods are fast and effective, they are mainly proposed to solve node classification problems, and usually do not consider node features.

Another thread of message-passing methods, Graph Neural Networks (GNNs), are a class of deep learning models. They are commonly used to generate low-dimensional representations of nodes for performing graph tasks. As shown in Figure 3, the nodes that are better connected in the graph, are expected to have closer embeddings in the low-dimensional space. The function of a two-layer Graph Convolutional Network (GCN) [4] can be written as:
\\[ \hat{Y} = A\sigma(AXW_{1})W_{2}, \\]
where *A* is the normalized adjacency matrix with self-loop, *X* is the node features, *W<sub>i</sub>* is the learnable matrix for the i-th layer, and *&sigma;* is the non-linear activation function, typically a sigmoid or a ReLU.
By removing &sigma; from the above equation, it reduces to:
\\[ \hat{Y} = A^{2}XW, \\]
which is a linear model with a node embedding *A<sup>2</sup>X* that can be precomputed. This particular model is Simple Graph Convolution (SGC) [5], which is the first linear GNN model. One of the many advantages of linear GNNs is that their node embeddings are available prior to model training. A comprehensive study on linear GNNs can be found in [6].

| Symbol | Definition |
| -------- | -------- |
| A<sub>[n×n]</sub> | Adjacency matrix |
| X<sub>[n×f]</sub> | Node feature matrix |
| W<sub>[f×c]</sub> | Learnable parameter matrix |
| Y<sub>[n×c]</sub> | Node label matrix |
| n | Number of nodes |
| f | Number of features |
| c | Number of classes |

## *Measuring NUI:* Would a message-passing method work in a given setting?

<figure>
<img src="./figure4.png" alt="scenarios" width="400"/>
<figcaption>
Figure 4. Scenarios in which the message-passing method may not work well. (a): The graph structure exhibits no network effects. (b): Node features are not correlated with node labels.
</figcaption>
</figure>

Given an attributed graph, how can we measure the network usable information (NUI)? The message-passing method may not work well in the following scenarios:
1. **No network effects:** means that the graph structure is not useful to solve the graph task. In Figure 4(a), since every node uniformly connects to one blue and one red node, it is hard to figure out the preference of the color to which a node will connect.
2. **Useless node features:** means that the node features are not useful to solve the graph task. In Figure 4(b), we can see that whether a user likes to bike is not correlated with the user's university.
3. Scenarios 1 and 2 occur at the same time.

In these cases, a message-passing method is likely to fail to infer the unknown node label, i.e., Bob’s college.

<figure>
<img src="./figure5.png" alt="structural and neighbors' feature embedding" width="800"/>
<figcaption>
Figure 5. Illustration of structural embedding (left) and neighbors' feature embedding (right). (a): SVD is conducted on the adjacency matrix to extract structural embedding. (b): Messages passed from a node's neighbors are aggregated to generate its node embedding.
</figcaption>
</figure>

We focus on analyzing whether a given GNN will perform well in a given setting. A straightforward way is to analyze its node embedding, but they are only available after training, which is expensive and time-consuming. For this reason, we propose to analyze the derived node embedding in linear GNNs. 

More specifically, we derive three types of node embedding that can comprehensively represent the information of the given graph, namely:
1. **Structural embedding (U):** for the information of the graph structure. It is extracted by decomposing the adjacency matrix with singular value decomposition (SVD). Intuitively, the left singular vectors U give the information of the node community. For example, in Figure 5(a), U identifies that the first three users belong to the blue community, while the last four belong to the red community. This is useful when the node features are not useful to solve the graph task.
2. **Feature embedding (F):** for the information of the node features. It consists of the original node features after dimensional reduction. This is useful when there are no network effects, i.e. the graph structure is not useful to solve the graph task.
3. **Neighbors' feature embedding (S):** for the information of the features aggregated from the neighbors. As shown in Figure 5(b), the messages are passed and aggregated from the neighbors for two steps. The intuition is that, in addition to the information from the user, the user's neighbors also provide useful information to the task. Leveraging their information leads to better performance on the graph task. This is useful when both the graph structure and the node features are useful to solve the graph task.

Once we have the embedding that can represent the information of the nodes of the graph, we propose NetInfoF_Score, and link the metrics of graph information and task performance with the following proposed theorem:

<figure>
<img src="./eqn1.png" alt="Definition and theorem" width="800"/>
</figure>

The intuition behind this theorem is that the conditional entropy of Y (e.g. labels) given X (e.g. “like biking”), is a strong indicator of how good of a predictor X is, to guess the target Y.
It also provides an advantage to NetInfoF_Score by giving it an intuitive interpretation, which is the lower-bound of the accuracy. When there is little usable information for the task, the value of NetInfoF_Score is close to random guessing.

<figure>
<img src="./figure6.png" alt="Emperical study" width="300"/>
<figcaption>
Figure 6. Our theorem holds, where NetInfoF_Score is always less than or equal to validation accuracy.
</figcaption>
</figure>

In Figure 6, each point represents the accuracy and NetInfoF_Score by solving a task with one type of node embedding. We find that NetInfoF_Score lower-bounds the accuracy of the given graph task, as expected. If an embedding has no usable information to solve the given task, NetInfoF_Score gives a score close to random guessing (see lower left corner in Figure 6).

## *Exploiting NUI:* How to solve graph tasks?

In this blog, we focus on explaining how to solve node classification. How to solve link prediction is more complicated, and the details can be found in [1].

To solve node classification, we concatenate different types of embedding, and the input of the classifier is as follows:
\\[ U || F || S , \\]
where || is concatenation, U is the structural embedding, F is the feature embedding, and S is the neighbors' feature embedding. Among all the choices, we use Logistic Regression as both the link predictor and the node classifier, as it is fast and interpretable.

## How well does our proposed method perform?

<figure>
<img src="./table1.png" alt="Node classification" width="1000"/>
</figure>

As shown in Table 1, applied on 12 real-world graphs, NetInfoF outperforms GNN baselines in 7 out of 12 datasets on node classification.

<figure>
<img src="./figure7.png" alt="NetInfoF_Score on real-world datasets" width="300"/>
<figcaption>
Figure 7. NetInfoF_Score highly correlates to test performance in real-world datasets. Each point denotes the result of one type of embedding in each dataset.
</figcaption>
</figure>

In Figure 7, NetInfoF_Score is highly correlated with test performance, on both link prediction and node classification. This indicates that NetInfoF_Score is a reliable measure for deciding whether to use a GNN on the given graph or not in a short time, without any model training.

## Conclusion

In this blog post, we investigate the problem of whether a message-passing method would work on a given graph. To solve this problem, we introduce NetInfoF, to measure and exploit the network usable information (NUI). Applied on real-world graphs, NetInfoF not only correctly mesures NUI with NetInfoF_Score, but also wins 7 out of 12 times on node classification.

Please find more details in our paper [1].

## References

[1] Lee, M. C., Yu, H., Zhang, J., Ioannidis, V. N., Song, X., Adeshina, S., ... & Faloutsos, C. NetInfoF Framework: Measuring and Exploiting Network Usable Information. International Conference on Learning Representations (ICLR), 2024.

[2] Günnemann, W. G. S., Koutra, D., & Faloutsos, C. (2015). Linearized and Single-Pass Belief Propagation. Proceedings of the VLDB Endowment, 8(5).

[3] Lee, M. C., Shekhar, S., Yoo, J., & Faloutsos, C. (2024, May). NetEffect: Discovery and Exploitation of Generalized Network Effects. Pacific-Asia Conference on Knowledge Discovery and Data Mining, 2024.

[4] Kipf, T. N., & Welling, M. (2016). Semi-Supervised Classification with Graph Convolutional Networks. International Conference on Learning Representations (ICLR), 2017.

[5] Wu, F., Souza, A., Zhang, T., Fifty, C., Yu, T., & Weinberger, K. Simplifying Graph Convolutional Networks. PMLR International Conference on Machine Learning (ICML), 2019.

[6] Yoo, J., Lee, M. C., Shekhar, S., & Faloutsos, C. Less is More: SlimG for Accurate, Robust, and Interpretable Graph Mining. ACM SIGKDD Conference on Knowledge Discovery and Data Mining (KDD), 2023.

