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

Given a graph with node features, how can we tell whether a graph neural network (GNN) can perform well on graph tasks or not? How can we know what information in the graph (if any) is usable to solve the tasks, namely, link prediction and node classification? GNNs are commonly adopted on graph tasks to generate good embeddings to perform on different graph tasks. However, an attributed graph, consisting of the graph structure and the node features, may have no network effects (i.e., useless graph structure), or useless node features. In these cases, training a GNN will be a waste of time and resources, especially for large cloud service providers like AWS, whose customers would like to perform the tasks with restricted budgets in a short time.

In this blog post, we introduce how to measure the information in the graph, and to exploit it for solving the graph tasks. This blog post is based on our research paper, “NetInfoF Framework: Measuring and Exploiting Network Usable Information” [1], presented at ICLR 2024.

## What is an attributed graph?

<figure>
<img src="./figure1.png" alt="attributed graph" width="400"/>
<figcaption>
Figure 1. An example of an attributed social network graph, where the nodes denote the users, and the edges denote whether two users are friends.
</figcaption>
</figure>

A graph is a structure that includes nodes and edges, which are the connections between nodes. An attributed graph indicates that each node in the graph has a set of features. For example, in a social network, the nodes denote the users, and the edges denote whether two users are friends. The node attributes/features of users are whether they are located in the US and whether they like to bike. The node labels of the users with two classes, shown by blue and red, indicate which college they go to.

<figure>
<img src="./figure2.png" alt="mathmatical presentation of graph" width="400"/>
<figcaption>
Figure 2. The mathmatical presentation of the attributed graph, including an adjacency matrix, node features, and node labels. The red question mark denotes that the label is unknown.
</figcaption>
</figure>

The graph structure can be mathematically presented by an adjacency matrix (without self-loop), where 1 denotes that there is an edge between two nodes, and 0 denotes no edge. The node features are also presented by a matrix, where each column of features can be either binary or continuous. The node labels are presented by a matrix with one-hot encoding of the class label.

## What are the common graph tasks?

We consider the two most common graph tasks:
- **Link Prediction**
    - *Goal:* Predict the existence of the edges in the graph.
    - *Example:* Given a social network with features, can we guess whether David and Grace could become friends, i.e., the existence of the red dash line in Figure 1? 
- **Node Classification**
    - *Goal:* Predict the classes of the unlabeled nodes, while some labeled nodes are given.
    - *Example:* Given a social network with features, can we guess which college Bob goes to, i.e., the label of the grey node in Figure 1?

## What are message-passing methods?

<figure>
<img src="./figure3.png" alt="node embedding" width="400"/>
<figcaption>
Figure 3. Illustration of how the nodes in a given graph projected into low-dimensional embedding space. The nodes that are more similar in the graph, are closer in the embedding space.
</figcaption>
</figure>

Message-passing methods utilize the graph structure to propagate the information from the neighbors of a node to itself. Known as sum-product message passing, belief propagation methods directly perform inference on the graph through several propagation iterations, requiring neither parameters nor training. To properly handle the interaction between node classes, while [2] assumes that the compatibility matrix is given by the domain expert, [3] estimates it with the given graph data. Although belief propagation methods are fast and effective, they are mainly proposed to solve node classification problems, and usually do not consider node features.

Another thread of message-passing methods, Graph Neural Networks (GNNs), are a class of deep learning models, commonly used to generate low-dimensional representations of nodes for performing graph tasks. As shown in the figure, the nodes that are better connected in the graph, are expected to have closer embeddings in the low-dimensional space. The function of a two-layer Graph Convolutional Network (GCN) [4] can be written as:
\\[ A\sigma(AXW_{1})W_{2}, \\]
where A is the normalized adjacency matrix with self-loop, X is the node features, W<sub>i</sub> is the learnable matrix for the i-th layer, and &sigma; is the non-linear activation function.
By removing &sigma; from the above equation, it reduces to:
\\[ A^{2}XW, \\]
which is a linear model with a node embedding A<sup>2</sup>X that can be pre-computed. This particular model is Simple Graph Convolution (SGC) [5], which is the first linear GNN model. One of the many advantages of linear GNNs is that their node embeddings are available prior to model training. A comprehensive study on linear GNNs can be found in [6].

## *Main Question:* Would a message-passing method work in a given setting?

<figure>
<img src="./figure4.png" alt="scenarios" width="400"/>
<figcaption>
Figure 4. Scenarios that the message-passing method may not work well. Left: The graph structure exhibits no network effects. Right: The node features are not correlated with the node labels.
</figcaption>
</figure>

Given an attributed graph, the message-passing method may not work well in the following scenarios:
1. **No network effects:** means that the graph structure is not useful to solve the graph task. In Figure 4 left, since every node connects to one blue and one red node, it is hard to figure out the preference of the color to which a node will connect.
2. **Useless node features:** means that the node features are not useful to solve the graph task. In Figure 4 right, we can see that whether a user likes to bike is not correlated with the user's university.
3. Scenario 1 and 2 occur at the same time.

In these cases, a message-passing method is likely to fail to infer the unknown node label, i.e., Bob’s college.

<figure>
<img src="./figure5.png" alt="structural and propagation embedding" width="800"/>
<figcaption>
Figure 5. Illustration of structural embedding (left) and propagation embedding (right). Left: SVD is conducted on the adjacency matrix to extract structural embedding. Right: Messages passed from a node's neighbors are aggregated to generate its node embedding.
</figcaption>
</figure>

We focus on analyzing whether a given GNN will perform well in a given setting. A straightforward way is to analyze its node embeddings, but they are only available after training, which is expensive and time-consuming. For this reason, we propose to analyze the derived node embeddings in linear GNNs. 

More specifically, we derive three types of node embeddings that can comprehensively represent the information of the given graph, namely:
1. **Structural embedding:** for the information of the graph structure. As shown in Figure 5 left, It is extracted by decomposing the adjacency matrix with singular value decomposition (SVD). This is useful when the node features are not useful to solve the graph task.
2. **Feature embedding:** for the information of the node features. It is the original node feature after dimensional reduction. This is useful when there are no network effects, i.e. the graph structure is not useful to solve the graph task.
3. **Propagation embedding:** for the information of the features aggregated from the neighbors. As shown in Figure 5 right, the messages are passed and aggregated from the neighbors for two steps. It leads to better performance by leveraging the information from the neighbors. This is useful when both the graph structure and the node features are useful to solve the graph task.

Once we have the embeddings that can represent the information of the graphs, we propose NetInfoF_Score, and link the metrics of graph information and task performance with the following proposed theorem:

<figure>
<img src="./eqn1.png" alt="Definition and theorem" width="800"/>
</figure>

This theorem provides an advantage to NetInfoF_Score by giving it an intuitive interpretation, which is the lower-bound of the accuracy. When there is little usable information to the task, the value of NetInfoF_Score is close to random guessing.

<figure>
<img src="./figure6.png" alt="Emperical study" width="300"/>
<figcaption>
Figure 6. Our theorem holds, where NetInfoF_Score is always less than or equal to validation accuracy.
</figcaption>
</figure>

In Figure 6, each point represents the accuracy and NetInfoF_Score by solving a task with one type of node embedding. We find that NetInfoF_Score lower-bounds the accuracy of the given graph task, as expected. If an embedding has no usable information to solve the given task, NetInfoF_Score gives a score close to random guessing (see lower left corner in Figure 6).

## How to solve graph tasks?

In this blog, we focus on explaining how to solve node classification. How to solve link prediction is more complicated, and the details can be found in [1].

To solve node classification, we concatenate different types of embedding, and the input of the classifier is as follows:
\\[ U || F || S , \\]
where U is the structural embedding, F is the feature embedding, and S is the propagation embedding. Among all the choices, we use Logistic Regression as both the link predictor and the node classifier, as it is fast and interpretable.

## How well does our proposed method perform?

<figure>
<img src="./table1.png" alt="Node classification" width="800"/>
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

