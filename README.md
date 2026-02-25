# GSR: Gene Set Randomization Adjustment for Pathway Enrichment

A tool-agnostic Nextflow pipeline for adjusting pathway enrichment results using Gene Set Randomization (GSR) to account for gene overlap and pathway structure.

## Overview

This pipeline implements pathway-specific null distributions to calculate empirical p-values and standardized effect sizes for pathway enrichment results. It corrects for the inflation caused by overlapping gene sets in pathway databases.

## Key Features

- **Tool-Agnostic**: Works with any pathway enrichment tool via adapters
- **BiReWire Randomization**: Preserves degree distribution while randomizing gene-pathway associations
- **Pathway-Specific Nulls**: Each pathway compared to its own 1000 randomized versions
- **Standardized Output**: All tools output to a common schema
- **Parallel Execution**: Nextflow handles 1001 enrichment runs efficiently

## Quick Start

```bash
# Clone repository
git clone https://github.com/yourusername/gsradjust-nf
cd gsradjust-nf

# Run with an existing adapter (e.g., MAGMA)
nextflow run main.nf \
  --gmt_file pathways.gmt \
  --adapter magma \
  --adapter_config config/magma_config.json \
  --num_random_sets 1000 \
  --outdir results
```

## Output

- `{tool}_real_standardized.tsv` - Real enrichment results in standard schema
- `{tool}_adjusted.tsv` - Final results with empirical p-values and z-scores
- `diagnostics/` - QQ plots and calibration reports

## Adding Your Own Tool

See [docs/ADAPTER_GUIDE.md](docs/ADAPTER_GUIDE.md) for step-by-step instructions on creating an adapter for your enrichment tool.

## Method

**BiReWire Randomization**: Preserves the number of pathways each gene belongs to and the size of each pathway, while randomizing which genes belong to which pathways.

**Empirical Adjustment**: 
- Empirical p-value: `(1 + #{null stats ≥ real stat}) / 1001`
- Z-score: `(real stat - mean(null stats)) / sd(null stats)`

## Citation

If you use this pipeline, please cite:
```
[Your paper citation here]
```

## License

MIT License

## Contact

Questions or issues? Open a GitHub issue or contact: [your email]
