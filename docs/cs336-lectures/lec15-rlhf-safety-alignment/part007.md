## TRPO 与约束的必要性
![关键帧](keyframes/part007_frame_00000000.jpg)
在单次轨迹采样(rollout)后执行多次梯度更新时，原始样本会迅速失效，导致训练过程偏离同策略(on-policy)假设。为弥补这一缺陷，必须引入重要性权重(importance weighting)修正以应对数据分布的偏移。这一思路构成了信任区域策略优化(Trust Region Policy Optimization, TRPO)的基础。TRPO 在应用这些修正的同时，显式地约束更新后的策略，使其与原始策略分布保持接近。

## PPO：以截断替代约束
![关键帧](keyframes/part007_frame_00053066.jpg)
近端策略优化(Proximal Policy Optimization, PPO)通过引入截断概率比率(clipped probability ratio)来替代显式的 KL 散度(KL divergence)约束，从而简化了 TRPO 的方法流程。该截断机制能够自然地促使模型更新幅度保持在原始策略附近，无需进行复杂的约束优化计算。然而，鉴于 PPO 实现细节的固有复杂性，本讲将不以其作为核心算法进行详细展开。

## 探索更简单的替代方案
![关键帧](keyframes/part007_frame_00116233.jpg)
在学术界与开源社区中，鉴于 PPO 的实现难度较高，研究人员一直积极探索更简便的替代方案。期间曾测试多种路径，例如：在偏好数据对(preference pairs)上附加显式的“优/劣”标签进行监督微调(Supervised Fine-Tuning, SFT)、仅利用偏好输出样本进行训练，以及借助奖励模型(Reward Model, RM)采样并筛选最优候选输出。然而，这些方法均未能持续取得稳定优异的效果。直到直接偏好优化(Direct Preference Optimization, DPO)算法的提出，才成功在模型架构的简洁性与训练性能的可靠性之间取得了理想平衡。

## DPO：剔除不必要的复杂性
![关键帧](keyframes/part007_frame_00154299.jpg)
DPO 之所以得以广泛应用，正是因为它成功剔除了 PPO 中繁琐的冗余组件。该算法完全移除了用于计算优势值(advantage values)的独立奖励模型，并摒弃了基于重要性采样比率(importance sampling ratio)的同策略(on-policy)更新限制。取而代之的是回归基础的优化范式：通过梯度上升最大化期望输出的对数似然(log-likelihood)，同时通过梯度下降最小化非期望输出的对数似然。

## DPO 目标函数的推导
![关键帧](keyframes/part007_frame_00216933.jpg)
DPO 的数学推导始于一个融合了奖励函数与 KL 散度(KL divergence)正则化项的目标函数，其中 KL 散度项用于约束新策略，使其不偏离参考模型(reference model)过远。通过引入策略的非参数化(non-parametric)假设（即将策略视为任意可微函数而非特定结构的神经网络），可推导出最优策略的解析解为参考策略分布与奖励函数指数形式的乘积。通过逆向求解隐式奖励(implicit reward)，可得出一个核心结论：在该非参数假设下，策略模型与奖励模型在数学表达上具有等价性。

## 从强化学习到监督最大似然估计
![关键帧](keyframes/part007_frame_00291333.jpg)
将上述隐式奖励代入用于成对偏好排序的 Bradley-Terry 模型(Bradley-Terry model)后，原始的强化学习问题被巧妙地转化为标准的最大似然估计(Maximum Likelihood Estimation, MLE)任务。这一数学转换将复杂的强化学习训练流程简化为纯粹的监督学习目标，模型仅需最大化正确预测偏好对相对顺序的概率即可。该推导过程的关键步骤涵盖：引入非参数化(non-parametric)假设、利用策略网络对奖励函数进行隐式参数化，以及采用标准监督损失函数进行优化。至此，DPO 的核心推导已全部完成，关于基于人类反馈的强化学习(Reinforcement Learning from Human Feedback, RLHF)的其余概念将在下一讲中继续展开。