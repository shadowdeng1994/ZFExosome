# ZFExosome — 斑马鱼外泌体介导的细胞间 mRNA 转运研究

本仓库提供研究斑马鱼（*Danio rerio*）细胞间 mRNA 转运的分析代码和补充数据。

## 目录结构

```
ZFExosome/
├── Code/                   # 分析代码
│   ├── Preprocess/         # NGS 数据预处理流程（Bash/GATK）
│   └── R/                  # 下游分析与可视化脚本
├── ProcessedData/          # 已处理的补充数据
│   ├── Var.SCellAD.RData       # 斑马鱼信息性位点等位基因频率
│   ├── TransRate.tsv           # 斑马鱼 mRNA 转运率
│   ├── Semiquantitative.Bin20.csv  # ubi:Switch 斑马鱼 mCherry 半定量分析
│   ├── Var.SCellAD.Mouse.RData    # 小鼠信息性位点等位基因频率
│   └── TransRate.Mouse.tsv       # 小鼠 mRNA 转运率
└── README.md
```

## Code / 代码

### Preprocess — NGS 预处理流程

使用 GATK4 (HaplotypeCaller) 对斑马鱼（GRCz11）参考基因组进行变异检测：

- **`genome.callSNPs.pipeline.sh`** — 全基因组测序（WGS）变异检测流程，包括 trim_galore 质控、BWA-MEM 比对、MarkDuplicates 去重和 GATK4 变异检测。
- **`mRNA.callSNPs.pipeline.sh`** — RNA-seq（bulkRNA / Smart-seq2）变异检测流程，使用 STAR 比对，包含 SplitNCigarReads 处理剪接位点。
- **`callSNPs.sh`** — GATK4 HaplotypeCaller 调用参数，支持并行染色体分析。

### R — 下游分析与可视化

包含 R 语言编写的下游生物信息学分析及结果可视化脚本。

## ProcessedData / 补充数据

| 文件 | 描述 |
|------|------|
| `Var.SCellAD.RData` | 斑马鱼信息性 SNP 位点等位基因频率 |
| `TransRate.tsv` | 斑马鱼各样本 mRNA 转运率（Mock / Control / Chimeric） |
| `Semiquantitative.Bin20.csv` | ubi:Switch 斑马鱼 mCherry 荧光半定量分析（ImageJ） |
| `Var.SCellAD.Mouse.RData` | 小鼠信息性 SNP 位点等位基因频率 |
| `TransRate.Mouse.tsv` | 小鼠 mRNA 转运率 |

其余数据将在后续发布。
