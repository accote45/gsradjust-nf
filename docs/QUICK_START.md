# Quick Start Guide

This guide will get you running GSR-Adjust in under 10 minutes.

## Prerequisites

- Nextflow >= 21.04.0
- R >= 4.0.0 with packages: BiRewire, GSA, data.table, tidyverse, slam
- An enrichment tool (MAGMA, or your own)
- Gene set database (GMT format)

## Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/gsradjust-nf
cd gsradjust-nf

# Install R dependencies
Rscript -e 'install.packages(c("BiRewire", "GSA", "data.table", "tidyverse", "slam"))'
```

## Quick Test Run

Here's a minimal example using the MAGMA adapter:

### 1. Prepare Your Files

You need:
- **GMT file**: Gene set database (e.g., `pathways.gmt`)
- **Tool-specific inputs**: See adapter documentation

For MAGMA, you need gene-level results from prior analysis:
```bash
# Example: You've already run MAGMA gene analysis
# magma --bfile reference_data --pval gwas.txt --gene-annot genes.annot --out gene_results
```

### 2. Create Config File

Create `config/my_magma_config.json`:
```json
{
  "gene_results_file": "/path/to/gene_results.genes.raw"
}
```

### 3. Run the Pipeline

```bash
nextflow run main.nf \
  --gmt_file data/pathways.gmt \
  --adapter magma \
  --adapter_config config/my_magma_config.json \
  --num_random_sets 1000 \
  --outdir results
```

### 4. Check Results

The pipeline will:
1. Generate 1000 randomized GMT files (takes 2-4 hours)
2. Run MAGMA on real + 1000 random sets (varies by dataset)
3. Calculate empirical p-values

Final output: `results/magma_adjusted.tsv`

```tsv
pathway_id              empirical_p  z_score  stat  real_p
GO:0006915_APOPTOSIS    0.001       3.5      2.4   0.02
KEGG_CELL_DEATH         0.003       3.1      2.1   0.03
...
```

## Interpreting Results

- **empirical_p**: Adjusted p-value accounting for gene overlap
- **z_score**: Standardized effect size (real vs null distribution)
- **stat**: Original test statistic from your tool
- **fdr**: False discovery rate (Benjamini-Hochberg)

## Resume on Failure

Nextflow automatically saves progress:
```bash
# If pipeline fails or is interrupted, resume with:
nextflow run main.nf -resume \
  --gmt_file ... \
  --adapter ... \
  --adapter_config ...
```

## Using Your Own Tool

See [ADAPTER_GUIDE.md](ADAPTER_GUIDE.md) for creating custom adapters.

Basic steps:
1. Copy adapter template: `cp -r adapters/template adapters/my_tool`
2. Edit `manifest.yaml` and `run_adapter.sh`
3. Test: `bash adapters/my_tool/run_adapter.sh test.gmt test config.json output.tsv`
4. Run pipeline with `--adapter my_tool`

## Test Mode (Quick Validation)

Test the pipeline with only 10 random sets:
```bash
nextflow run main.nf \
  -profile test \
  --gmt_file small_pathways.gmt \
  --adapter magma \
  --adapter_config config/test_config.json
```

## Common Issues

### BiRewire takes forever
- Expected: 2-4 hours for 10,000+ genes
- Speed up: Use smaller gene sets or run on HPC

### "Module not found: magma_gwas"
- Adapter uses environment modules (HPC)
- Modify `adapters/magma/run_adapter.sh` to use your environment

### "Missing required columns"
- Your adapter output doesn't match schema
- Run: `Rscript scripts/validate_schema.R your_output.tsv`

## Next Steps

- Read [ADAPTER_GUIDE.md](ADAPTER_GUIDE.md) for custom tools
- See [SCHEMA.md](SCHEMA.md) for output format details
- Check [examples/](../examples/) for more use cases

## Getting Help

- GitHub Issues: https://github.com/yourusername/gsradjust-nf/issues
- Email: [your.email@institution.edu]
