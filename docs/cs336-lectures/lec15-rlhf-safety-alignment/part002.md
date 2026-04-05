## 监督微调中的幻觉风险
![关键帧](keyframes/part002_frame_00000000.jpg)
指令微调(Instruction Fine-Tuning)面临的一个关键挑战在于：当模型被迫生成超出其固有知识范围(Intrinsic Knowledge)的回复时。正如 John Schulman 所指出的，强迫模型回答其未知的问题会直接诱发幻觉(Hallucination)。模型可能并未真正学习事实内容，而是仅仅拟合了浅层的结构模式(Structural Patterns)——例如，形成“复杂输入必须附带引用”的刻板印象。这演变为一种词元预测(Token Prediction)的捷径(Shortcut)，而非真正的知识获取(Knowledge Acquisition)。

![关键帧](keyframes/part002_frame_00013933.jpg)
尽管掌握引用格式的回复是一种理想的结构化行为，但底层下一词元预测(Next-Token Prediction)机制可能会迫使模型为最小化损失(Loss)，而使用看似合理实则编造的信息进行“填空”。这揭示了一种根本性的失效模式(Failure Mode)：若监督微调(Supervised Fine-Tuning, SFT)数据显著超出基础模型(Base Model)的能力边界，模型可能会优化为仅模仿专业表象，而非真正掌握专业知识。因此，研究人员强调了同策略(On-Policy)强化学习(Reinforcement Learning)的重要性，该方法允许模型坦诚表达不确定性（如回答“我不知道”），从而避免因“沉默惩罚”而被迫产生幻觉。

## 安全微调与拒绝权衡
![关键帧](keyframes/part002_frame_00092600.jpg)
除能力对齐(Capability Alignment)外，语言模型的大规模部署还需依赖强有力的安全微调(Safety Fine-Tuning)。模型需配备完善的安全护栏(Safety Guardrails)，以防被滥用于传播虚假信息、实施诈骗或生成垃圾内容。早期研究表明，即便在指令微调中仅注入少量安全对齐(Safety Alignment)数据，也能显著提升模型的安全性。然而，这也在合理拒绝(Justified Refusal)与过度拒绝(Over-Refusal)之间引入了微妙的权衡(Trade-off)。

![关键帧](keyframes/part002_frame_00274766.jpg)
![关键帧](keyframes/part002_frame_00291266.jpg)
模型必须精准区分真正的恶意提示(Malicious Prompts)与仅包含敏感关键词的良性查询(Benign Queries)（例如，“如何 kill（终止）一个 Python 进程”）。纯指令微调难以捕捉此类细微差别，通常需借助精心构建(Curated)的小规模数据集来校准拒绝阈值(Refusal Threshold)。令人瞩目的是，研究表明仅需约 500 条精心编写的安全示例(Safety Examples)，即可有效构建基础安全行为，这充分印证了高质量、定向数据所具备的巨大杠杆效应。

## 指令微调出人意料的强大与简洁
![关键帧](keyframes/part002_frame_00213966.jpg)
尽管现代 AI 助手架构日益复杂，但指令微调的基础机制却出奇地简洁。仅需设置合理的超参数(Hyperparameters)，并在标准的开源指令数据集上对性能较强的基础模型进行微调，即可诱导出与商业级聊天机器人高度相似的行为模式。尽管前沿模型的研发涉及海量优化工作，但其核心启示在于：即便是规模适中、结构严谨的数据集，亦能对模型的行为对齐(Behavioral Alignment)产生深远影响。真正的复杂性并非源于算法本身，而在于对数据质量(Data Quality)的严苛打磨及其背后严密的设计逻辑。

## 界限模糊：预训练与中期训练
![关键帧](keyframes/part002_frame_00340766.jpg)
在传统学术视角中，指令微调常被视为一个独立且相对简单的微调步骤。然而，在拥有庞大算力(Compute)资源的前沿实验室中，预训练(Pre-training)与后训练(Post-Training)的边界正日益模糊。指令微调数据本质上仅为词元序列(Token Sequences)，这意味着其可直接无缝集成至预训练流水线(Pre-training Pipeline)中。

![关键帧](keyframes/part002_frame_00404533.jpg)
![关键帧](keyframes/part002_frame_00411166.jpg)
这一趋势催生了“中期训练”(Mid-Training)或连续训练(Continual Training)策略的兴起。现代训练流水线通常不再于预训练结束后硬性截断并转入独立的 SFT 阶段，而是倾向于在预训练末期（尤其是在学习率退火(Learning Rate Annealing)阶段）逐步混合高质量指令数据。

![关键帧](keyframes/part002_frame_00468666.jpg)
![关键帧](keyframes/part002_frame_00520133.jpg)
在训练后期集成指令数据优势显著：它能有效缓解灾难性遗忘(Catastrophic Forgetting)，促使模型将行为模式更深层次地内化至参数中，并最大化数据的杠杆效应。尽管后续可能仍保留一个简短、定向的微调阶段，但绝大部分对齐工作已通过这一连续过程深度融入模型权重之中。此类扩展训练范式(Extended Training Paradigm)正逐渐成为闭源实验室与先进开源社区的标准化实践。

![关键帧](keyframes/part002_frame_00597500.jpg)