+++
# The title of your blogpost. No sub-titles are allowed, nor are line-breaks.
title = "Time-Traveling Simulation for Security"
# Date must be written in YYYY-MM-DD format. This should be updated right before the final PR is made.
date = 2022-12-06

[taxonomies]
# Keep any areas that apply, removing ones that don't. Do not add new areas!
areas = ["Security", "Theory"]
# Tags can be set to a collection of a few keywords specific to your blogpost.
# Consider these similar to keywords specified for a research paper.
tags = ["Security Models", "Zero-Knowledge", "Blockchain"]

[extra]
# For the author field, you can decide to not have a url.
# If so, simply replace the set of author fields with the name string.
# For example:
#   author = "Harry Bovik"
# However, adding a URL is strongly preferred
author = {name = "Justin Raizes", url = "https://sites.google.com/view/justinraizes"} 
# author = {name = "Justin Raizes", url = "YOUR HOME PAGE URL HERE"}
# The committee specification is simply a list of strings.
# However, you can also make an object with fields like in the author.
committee = [
    "Anup Agarwal",
    "Aayush Jain",
    "Elaine Shi",
]

+++



Blockchains are a powerful technology which allow decentralized agreement with an immutable history. Since transactions can be added, but not removed, blockchains allow distributed banking as a trustworthy alternative to central banking.
A vast amount of cryptographic research on constructing secure blockchains has led to them being trusted to secure currency worth [hundreds of billions](https://coinmarketcap.com/currencies/bitcoin/) of US dollars.

Recently, blockchains have received attention as an enabler of cryptography rather than just a goal of it. Several works have used blockchains to build a variety of cryptographic tools, including [one-time programs](https://link.springer.com/chapter/10.1007/978-3-319-70500-2_18) and [time-lock encryption](https://link.springer.com/article/10.1007/s10623-018-0461-x). These tools are impossible to construct without special assumptions. These works model cryptographic protocols as occurring in a world where a blockchain protocol is being executed. The cryptographic protocol is therefore able to perform actions such as reading the state of the blockchain or posting transactions to it. The exact security definitions vary significantly between these approaches.

Time-traveling simulation is a new security model for protocols executed in the presence of a blockchain. Intuitively, time-traveling simulation captures the philosophy that "any extra information an adversary learns in a real execution could have been learned on their own by waiting for the natural passage of time". Since a blockchain will naturally progress no matter what the adversary does, it provides the notion of time needed to formalize this philosophy. 

Time-traveling simulation bypasses many impossibility results, while the same time yielding an arguably stronger notion of security than prior blockchain based works. For example, time-traveling simulation enables zero knowledge arguments and secure two-party computation in three messages. It is currently not known how to construct these protocols in three messages with the standard notion of security, without relying on new hardness assumptions. 


In this article, we will dive into the [definition of time-traveling simulation](#the-philosophy-of-security) and how it [compares to other security notions](#comparison-to-other-relaxed-security-notions). Additionally, we will explore how it can be used to bypass impossibility results for [three message zero knowledge arguments](#application-time-traveling-simulators-for-zero-knowledge).



# The Philosophy of Security

In modern cryptography, the central philosophy for security is "any extra information an adversary learns in a real execution could have been learned on their own". In other words, the adversary learns nothing from participating in the real execution, beyond what they were supposed to learn. For example, in a zero knowledge argument, the adversary only learns that a given NP statement is true, without learning a witness for _why_ it is true. This particular notion is actually too strong for many applications, so cryptographers usually consider weakenings of this philosophy with the same spirit. The most common weakening is "any extra information an adversary learns in a real execution could have been learned on their own using a little extra computation".

These philosophies are captured formally by a mathematical object called a simulator. A simulator's job is to reproduce whatever knowledge the adversarial verifier would have learned in a real execution of the protocol. However, it must do this without access to the real prover; it only has the adversary's code. If such a simulator exists, then the adversary could run the simulator on its own. By doing so, it learns everything it would have learned in a real interaction, without interacting with the real prover.

More formally, a simulator (for zero knowledge) takes as input the adversary's code and the statement being proven, then outputs a transcript of a protocol execution, along with the adversary’s internal state. In the real world, without loss of generality, the adversary outputs the transcript of the protocol execution along with its own internal state. This is before any post-processing. A protocol is zero knowledge if there exists a simulator whose output distribution is indistinguishable from the output distribution of the adversary in the real world. This guarantees that whatever information can be derived from the output of the adversary in the real world is indistinguishable from what can be derived from the simulator. Thus, by running the simulator, the adversary can learn whatever it would have learned in a real execution.

![In the real world, the adversary interacts with someone who knows a secret. In the ideal world, the simulator does not know the secret, and may internally interact with the adversary to produce a realistic looking view.](./simulator-paradigm.png)
<div style="margin-left: 50px; margin-right:  40px;"><b>Figure:</b> The simulator imagines an interaction between the adversarial verifier and an imaginary prover. This interaction is indistinguishable from a real interaction, from the adversary's point of view.</div>

In some sense, a simulator can be viewed as a method for the adversary to fool itself into accepting the truth of a statement without knowing a witness. It is important that the adversary can only fool itself - an adversarial prover should not be able to fool an honest verifier. This requires some asymmetry between the simulator and a real-world adversary. One of the most basic forms of asymmetry is knowledge of the adversary's code, which allows the simulator to internally run and interact with the adversary. Any adversary knows its own code, but it certainly shouldn't know anyone else's!


To relax the security philosophy, the simulator is provided with some form of additional power which represents additional asymmetry between the simulator and a real-world adversary. The more asymmetry, the easier it is to create a simulator without allowing an adversarial prover to convince an honest verifier of a false statement. In general, providing more extra power to the simulator corresponds to a weaker security notion. The adversary can learn whatever the simulator can learn, so a more powerful simulator corresponds to an adversary which can learn more information. The table below compares common relaxations to time-traveling simulation in terms of their philosophies and what extra power is given to the simulator.


| Security Notion      | Philosophy: <br/>"Any extra information an adversary learns in a real execution could have been learned on their own..."   | Simulator   |
|:---------------------    | :------------------|:---------------|
| Expected PPT (Standard)  | in expected PPT.       | Runs in expected poly time. |
| Superpolynomial Simulation | in superpolynomial time. | Runs in superpolynomial time. |
| Common Reference String (CRS) | using the CRS trapdoor. | Can choose the CRS used by both parties. This allows adding a trapdoor to it. |
| Majority Simulation | if they controlled the blockchain. | Controls the majority of blockchain participants. |
| Time-Traveling Simulation | shortly into the future. | Can look into the future. |

## Security Implications of Time-Traveling Simulation

As mentioned previously, time-traveling simulation captures the philosophy that "any extra information an adversary learns in a real execution could have been learned on their own by waiting for the natural passage of time". This is realized by allowing the simulator to see a potential future state of the blockchain, which consists of a valid extension by \\( F \\) blocks. Since such a state will become public information after a short time regardless of what the adversary does, this only reveals information that would have anyway been revealed with the natural passage of time.

Simulator access to a future state allows time-traveling simulation to bypass impossibility results for expected probabilistic polynomial time simulation, which is considered the standard notion of simulation. 
A common blockchain property is that a computationally-bounded adversary cannot compute a valid extension by \\( F \\) blocks faster than the honest parties can extend the chain by, say, \\( \sqrt{F} \\) blocks. Therefore access to a future state represents additional asymmetry between the simulator and a real adversary.
This additional asymmetry makes it possible for the simulator to "imagine" the adversary's real-world view in protocols where it otherwise would not have been able to, bypassing the impossibility results for expected PPT simulation (aka standard simulation).


![A blockchain comes equipped with a validity predicate which allows checking whether a state is a valid extension of a previous state. A future state is a valid extension of the current state.](./future-state.png)
<div style="margin-left: 50px; margin-right:  40px;"><b>Figure:</b> A blockchain comes equipped with a validity predicate which allows checking whether a state is a valid extension of a previous state. A future state is a valid extension of the current state.</div>


Time-traveling simulation is almost as meaningful as standard simulation when it comes to long-term knowledge. 
For example, imagine the task of constructing multi-party computation protocols which are secure against malicious adversaries. A malicious adversary may deviate from the protocol arbitrarily. Another kind of adversary is a semi-honest adversary, which follows the protocol, but may attempt to analyze the transcript later. It is much easier to construct multi-party computation protocols which are secure against semi-honest adversaries. A multi-party computation protocol with semi-honest security can be transformed to have malicious security by using the [GMW compiler](https://dl.acm.org/doi/pdf/10.1145/28395.28420). To do the transformation, each party proves the statement "I executed the protocol honestly using some input" in zero knowledge. This convinces the other parties that they did indeed behave honestly, but does not reveal an explanation for the honest behavior. Crucially, this means that the zero knowledge argument preserves the privacy of each party's inputs. Now consider using a zero knowledge argument with time-traveling simulation to instantiate the GMW compiler. Since honest behavior in a non-time-sensitive protocol does not depend on the passage of time, this does not reveal an explanation for the honest behavior. In particular, the inputs of each party are still private.

In contrast, time-traveling simulation may not be suitable for applications which are inherently time sensitive. For example, consider using a zero knowledge argument with time-traveling simulation to prove knowledge of a solution to a time-lock puzzle. A time-lock puzzle can be solved in some set amount of time (for example, a day), but cannot be solved faster than that. Since the simulator has access to a future state from after the time-lock puzzle can be solved, in this situation time-traveling simulation may allow the solution to be leaked today instead of tomorrow.

### Comparison to Other Relaxed Security Notions

Several of these security notions also bypass impossibility results for expected PPT simulation. One way to further compare security notions is comparing how powerful their simulators are. As mentioned previously, a security notion which allows the simulator more power may allow the adversary to learn more information. In many cases, time-traveling simulation gives the simulator less power than other simulation notions, so it corresponds to better security guarantees.

**Super-Polynomial Time Simulation.** Time-traveling simulation can be seen as a very restricted form of super-polynomial time or angel-based simulation. Angel-based simulation is similar to super-polynomial time simulation, but restricts the extra computational power to performing one specific task. For example, an angel may break the security of a particular commitment scheme. Both super-polynomial time and angel-based simulators are very powerful and can bypass many impossibility results. However, it can be challenging to argue that the simulator cannot break the security of other primitives. These primitives may only have security against polynomial-time adversaries, so they can be broken using any super-polynomial time computation. Continuing the example of commitments, if the simulator could also break a second commitment scheme, then it cannot guarantee that the second scheme is secure against the real adversary.

In the case of time-traveling simulation, the angel's task is to quickly compute a potential future state of the blockchain exactly once. It is worth emphasizing the special nature of this task: it is computing something which will be publicly available information in just a short while. As such, whatever security a time-traveling simulator breaks would have been broken soon anyway. For example, regardless of which commitment scheme the parties use, the commitment to their input can never be broken by a time-traveling simulator.

**Common Reference String.** Another good point of comparison is the common reference string model, since the blockchain state represents a pre-agreed-upon string. One important difference between a CRS and the way time-traveling simulation uses a blockchain is that the format of a common reference string often depends on the exact protocol being run (for example, a zero knowledge proof or a secure computation protocol). However, a blockchain does not adapt to auxiliary protocols. A second, and perhaps more important difference, is the notion of control. In the CRS model, the simulator has full control over the CRS. A time-traveling simulator, on the other hand, has no actual control over the blockchain, only some extra information about it. This means that a time-traveling simulator can learn less information than a simulator with full control over the blockchain. Since an adversary might be able to learn whatever a simulator can, the security notion is stronger if the simulator only has extra information, instead of full control.

**Majority Simulation.** This difference in control over versus knowledge about the blockchain is especially illustrated when comparing time-traveling simulation to majority simulation. Majority simulation is another relaxed security model for protocols executed alongside a blockchain. In majority simulation, the simulator is allowed control over all honest parties which are participating in the progression of the blockchain. Since blockchain security requires the honest parties to be in control of the blockchain, this allows a majority simulator to perform tasks such as pausing or even rewinding the blockchain. Such capabilities should even allow computation of future states of the blockchain, which is the only power given to a time-traveling simulator. 

In particular, majority simulation can introduce security vulnerabilities when running two different protocols using the same blockchain. Since the two protocols rely on the security of the blockchain, a simulator with full control over the blockchain can easily break the security of either protocol. Therefore majority simulation does not guarantee that a party which participates in one protocol cannot violate the security of the other protocol. Although it is nontrivial to see, time-traveling simulation can allow multiple protocols to use the same blockchain at the same time if they are careful. 


# Application: Time-Traveling Simulators for Zero Knowledge

Time-traveling simulators allow a particularly simple construction for zero knowledge arguments with three messages. As mentioned previously, constructing zero knowledge arguments with three messages is very difficult under the standard notion of security (expected PPT simulation). [Prior work](https://iacr.org/archive/tcc2008/49480068/49480068.pdf) shows that any security proof for a three message zero knowledge argument must make non-blackbox use of the adversary's code. However, non-blackbox techniques are notoriously difficult. The only [current construction](https://dl.acm.org/doi/10.1145/3188745.3188870) for three message zero knowledge relies on new cryptographic hardness assumptions.

A zero knowledge argument is, first and foremost, an argument. A prover attempts to convince a verifier that an NP statement \\( x\\) is in an NP language \\( L\\). The prover should not be able to convince the verifier of a false statement; this property is called soundness. The zero knowledge property requires that the argument does allow the verifier to learn anything about the witness for \\( x \in L\\). This is formalized using the simulator definition discussed [above](#the-philosophy-of-security). As a reminder, the simulator must approximate a real view of the argument, except it does not have access to the real prover. In the standard notion of simulation, the simulator is an expected PPT algorithm.

In time-traveling simulation for zero knowledge arguments, the simulator additionally receives a valid extension of the blockchain by \\(F\\) blocks. Then it must produce the adversary's view. If left alone, the blockchain will generate extensions of itself which are independent of the statement \\(x\\) or its witnesses. Therefore the future state which the simulator receives is effectively harmless and contains no information about the witness beyond what is naturally leaked with the passage of time.

![In a real zero knowledge argument execution, the prover knows the witness. A time-traveling simulator for zero knowledge receives a future state of the blockchain instead of the witness.](./timetraveling-simulator-zk.png)
<div style="margin-left: 50px; margin-right:  40px;"><b>Figure:</b> In a real zero knowledge argument execution, the prover knows the witness. A time-traveling simulator for zero knowledge receives a future state of the blockchain instead of the witness.</div>

## Zero Knowledge in Three Rounds

The construction of a three round zero knowledge argument uses a three round witness indistinguishable proof of knowledge (WIPoK). In a WIPoK, a prover convinces a verifier that they "know" a witness for some NP statement. The witness indistinguishability property guarantees that if there are two possible witnesses for the statement, then the verifier cannot tell which one the prover knows. This is a weaker security guarantee than zero knowledge, so it is possible to construct a WIPoK in just three rounds (even without assuming special setup like a CRS or a blockchain).

The construction is as follows. To prove the truth of an NP statement \\( x\\), the prover and verifier engage in a WIPoK for the statement “I know a witness for \\( x\\) or I know a blockchain state \\(F\\) blocks ahead of the current state”. Showing zero knowledge requires constructing a time-traveling simulator, which is initialized with a future state. The simulator acts as a prover in the WIPoK with the adversary, using the future state as its witness. Witness indistinguishability guarantees that an execution using the future state as a witness is indistinguishable from an execution using a witness for \\(x \\). The latter case is exactly what occurs in a real execution, so the simulator's output is indistinguishable from a real execution.

To show soundness, observe that any adversarial prover must know a witness for the statement. This is either a witness for \\( x \\) or it is a future state of the blockchain. Since a real adversary cannot possibly know a future state of the blockchain without violating the blockchain's security, it must know a witness for \\( x\\). The full argument for soundness requires some additional care in order to use the proof of knowledge property, since the WIPoK is composed in parallel with a blockchain protocol and many security properties break down during parallel composition. See the [full paper](https://eprint.iacr.org/2022/035.pdf) for details.
