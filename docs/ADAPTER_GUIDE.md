# Adapter Development Guide

This guide explains how to create an adapter to use your enrichment tool with GSR-Adjust.

## Overview

An **adapter** is a small wrapper that:
1. Runs your enrichment tool on a GMT file
2. Parses the output to a standardized format
3. Enables GSR adjustment for your results

**Time to create**: 1-2 hours for most tools

## Adapter Components

Every adapter consists of:

```
adapters/my_tool/
├── manifest.yaml       # Metadata and configuration
├── run_adapter.sh      # Main entry point (required)
└── parse_output.R      # Parser (can be .py, .R, or embedded in .sh)
```

## Step-by-Step Tutorial

### Step 1: Copy the Template

```bash
cd gsradjust-nf/adapters
cp -r template my_tool
cd my_tool
```

### Step 2: Edit manifest.yaml

```yaml
name: my_tool              # Must match directory name
version: 2.1.0            # Your tool's version
description: Brief description

input_format: gmt          # What format does your tool accept?

# What files does your tool need (beyond the GMT)?
required_inputs:
  gwas_summary_stats: true
  background_genes: false
  
# Critical: Define your primary statistic
stat_type: enrichment_score
higher_is_more_enriched: true  # IMPORTANT!

# Does your tool output p-values?
supports_p_value: true

# Execution
command: bash run_adapter.sh
container: null  # Or docker://my_tool:2.1.0

# Optional constraints
pathway_size:
  min: 10
  max: 500
```

**Critical Decision**: Set `higher_is_more_enriched` correctly!
- `true`: Higher stat = stronger enrichment (e.g., effect size, enrichment score)
- `false`: Lower stat = stronger enrichment (e.g., p-value, rank position)

### Step 3: Implement run_adapter.sh

The script receives **4 standardized arguments**:

```bash
#!/bin/bash
GMT_FILE=$1      # Path to gene set file (real or randomized)
RUN_ID=$2        # "real" or "random1", "random2", ..., "random1000"
CONFIG_JSON=$3   # Tool-specific configuration
OUTPUT_FILE=$4   # Where to write standardized output
```

**Template Structure**:

```bash
#!/bin/bash
set -e  # Exit on error

# ============================================================================
# Section 1: Parse Arguments
# ============================================================================
GMT_FILE=$1
RUN_ID=$2
CONFIG_JSON=$3
OUTPUT_FILE=$4

# ============================================================================
# Section 2: Extract Config
# ============================================================================
# Use jq to parse JSON config
GWAS_FILE=$(jq -r '.gwas_file' $CONFIG_JSON)
BACKGROUND=$(jq -r '.background_genes' $CONFIG_JSON)

# Verify required files exist
if [ ! -f "${GWAS_FILE}" ]; then
    echo "ERROR: GWAS file not found: ${GWAS_FILE}"
    exit 1
fi

# ============================================================================
# Section 3: Run Your Tool
# ============================================================================
echo "Running enrichment for ${RUN_ID}..."

my_enrichment_tool \
  --pathways ${GMT_FILE} \
  --gwas ${GWAS_FILE} \
  --background ${BACKGROUND} \
  --output ${RUN_ID}_raw.txt

# ============================================================================
# Section 4: Parse to Standard Schema
# ============================================================================
# Option A: Call separate parser
Rscript parse_output.R ${RUN_ID}_raw.txt ${RUN_ID} ${OUTPUT_FILE}

# Option B: Inline awk (for simple cases)
# awk -v rid=${RUN_ID} 'NR>1 {
#   print $1 "\t" $4 "\t" $3 "\t" $2 "\tmy_tool\t" rid
# }' ${RUN_ID}_raw.txt > ${OUTPUT_FILE}
```

### Step 4: Create Parser

**Example: parse_output.R**

```r
#!/usr/bin/env Rscript
library(data.table)

args <- commandArgs(trailingOnly = TRUE)
raw_file <- args[1]
run_id <- args[2]
output_file <- args[3]

# Read your tool's output
raw <- fread(raw_file)

# Convert to standard schema
standardized <- data.table(
  pathway_id = raw$pathway_name,     # Pathway identifier
  pathway_size = raw$n_genes,        # Number of genes
  stat = raw$enrichment_score,       # PRIMARY STATISTIC
  p = raw$p_value,                   # Raw p-value (optional)
  effect = raw$effect_size,          # Effect size (optional)
  se = raw$std_error,                # Standard error (optional)
  tool_name = "my_tool",
  tool_version = "2.1.0",
  run_id = run_id
)

fwrite(standardized, output_file, sep = "\t")
```

**Example: parse_output.py**

```python
#!/usr/bin/env python3
import sys
import pandas as pd

raw_file, run_id, output_file = sys.argv[1:4]

# Read your tool's output
raw = pd.read_csv(raw_file, sep='\t')

# Convert to standard schema
standardized = pd.DataFrame({
    'pathway_id': raw['pathway_name'],
    'pathway_size': raw['n_genes'],
    'stat': raw['enrichment_score'],
    'p': raw['p_value'],
    'effect': raw['effect_size'],
    'se': raw['std_error'],
    'tool_name': 'my_tool',
    'tool_version': '2.1.0',
    'run_id': run_id
})

standardized.to_csv(output_file, sep='\t', index=False)
```

### Step 5: Create Config Template

Create `config/my_tool_config.json`:

```json
{
  "gwas_file": "/path/to/gwas_summary_statistics.txt",
  "background_genes": "/path/to/background_gene_list.txt",
  "expression_matrix": "/path/to/expression_data.csv"
}
```

### Step 6: Test the Adapter

#### A. Test on Single File

```bash
# Create minimal test data
echo -e "GO:0001\tDESC\tGENE1\tGENE2\tGENE3" > test.gmt
echo -e "GO:0002\tDESC\tGENE2\tGENE3\tGENE4" >> test.gmt

# Run adapter
bash adapters/my_tool/run_adapter.sh \
  test.gmt \
  test \
  config/my_tool_config.json \
  test_output.tsv

# Check output
cat test_output.tsv
```

Expected format:
```tsv
pathway_id	pathway_size	stat	p	effect	tool_name	run_id
GO:0001	3	2.5	0.01	1.8	my_tool	test
GO:0002	3	1.2	0.05	0.9	my_tool	test
```

#### B. Validate Schema

```bash
Rscript scripts/validate_schema.R test_output.tsv
```

Expected output:
```
✓ VALIDATION PASSED
File: test_output.tsv
Rows: 2
Pathways: 2
Run(s): test
Tool: my_tool
```

#### C. Test Full Pipeline (Small Scale)

```bash
nextflow run main.nf \
  -profile test \
  --gmt_file test.gmt \
  --adapter my_tool \
  --adapter_config config/my_tool_config.json \
  --num_random_sets 10 \
  --outdir test_results
```

### Step 7: Production Run

```bash
nextflow run main.nf \
  --gmt_file data/full_pathways.gmt \
  --adapter my_tool \
  --adapter_config config/my_tool_config.json \
  --num_random_sets 1000 \
  --outdir results
```

## Standard Schema Reference

### Required Columns

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `pathway_id` | string | Unique pathway ID | "GO:0006915" |
| `pathway_size` | integer | Number of genes | 45 |
| `stat` | numeric | Test statistic (monotonic) | 2.34 |
| `tool_name` | string | Tool identifier | "magma" |
| `run_id` | string | Run identifier | "real", "random1" |

### Optional Columns

| Column | Type | Description |
|--------|------|-------------|
| `p` | numeric | Raw p-value (0-1) |
| `effect` | numeric | Effect size |
| `se` | numeric | Standard error |
| `tool_version` | string | Tool version |

## Critical: The `stat` Column

The `stat` column is used for empirical comparison. It **MUST** be monotonic:

✅ **Higher = Stronger Enrichment**

### If Your Tool Outputs p-values

Don't use p-values directly as stat! Transform them:

```r
# Good: -log10 transformation
stat = -log10(p_value)

# Good: Convert to Z-score
stat = qnorm(1 - p_value/2)
```

### If Your Tool Outputs "Lower is Better" Scores

Invert them:

```r
# Good: Negate
stat = -original_score

# Good: Inverse
stat = 1 / original_score

# Good: Max minus value
stat = max(scores) - original_score
```

## Common Patterns

### Pattern 1: Tool Needs File Format Conversion

```bash
# Convert GMT to tool-specific format
python convert_gmt_to_my_format.py ${GMT_FILE} my_format.txt

# Run tool
my_tool --input my_format.txt --output ${RUN_ID}_raw.txt
```

### Pattern 2: Tool Requires Gene Background

```bash
# Extract gene background from GMT
awk -F'\t' '{for(i=3;i<=NF;i++) print $i}' ${GMT_FILE} | sort -u > genes.txt

# Use in tool
my_tool --pathways ${GMT_FILE} --background genes.txt
```

### Pattern 3: Tool Outputs Multiple Files

```bash
# Run tool (creates multiple outputs)
my_tool --input ${GMT_FILE} --outdir ${RUN_ID}_out/

# Parse specific output file
parse_output.R ${RUN_ID}_out/enrichment_results.txt ${RUN_ID} ${OUTPUT_FILE}
```

### Pattern 4: Tool Doesn't Output P-values

```yaml
# In manifest.yaml
supports_p_value: false
```

```r
# In parser - omit p column
standardized <- data.table(
  pathway_id = raw$pathway,
  pathway_size = raw$n_genes,
  stat = raw$score,           # Only stat is required
  tool_name = "my_tool",
  run_id = run_id
)
```

## Troubleshooting

### "Missing required columns"

Check your parser output column names:
```bash
head -1 test_output.tsv
# Should show: pathway_id	pathway_size	stat	tool_name	run_id
```

### "Duplicate pathway_id"

Each pathway should appear once per run:
```bash
# Check for duplicates
awk -F'\t' 'NR>1 {print $1}' test_output.tsv | sort | uniq -d
```

### "stat must be numeric"

Ensure stat column has numbers, not strings:
```r
# In R parser
standardized$stat <- as.numeric(raw$score)
```

### "p-values must be between 0 and 1"

If tool outputs something else (e.g., -log10(p)):
```r
# Convert back
p_original <- 10^(-log10_p)
```

## Examples

See working adapters:
- **Simple**: `adapters/magma/` - Basic gene-set test
- **Complex**: (to be added) - Multi-step processing

## Sharing Your Adapter

Once working, consider contributing:
1. Add to `adapters/community/your_tool/`
2. Include documentation
3. Submit pull request

## Getting Help

- Template: `adapters/template/README.md`
- Schema: `docs/SCHEMA.md`
- Issues: https://github.com/yourusername/gsradjust-nf/issues
