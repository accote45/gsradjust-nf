# Standard Schema Documentation

This document defines the standardized output schema that all adapters must produce.

## Overview

GSR-Adjust uses a **standardized tabular format** (TSV) to enable tool-agnostic empirical adjustment. Every adapter must convert its tool's output to this schema.

## File Format

- **Format**: Tab-separated values (TSV)
- **Header**: Required (first line contains column names)
- **Encoding**: UTF-8
- **Extension**: `.tsv`

## Column Definitions

### Required Columns

#### `pathway_id` (string)
- **Description**: Unique identifier for the pathway
- **Format**: Typically from GMT file first column (e.g., "GO:0006915", "KEGG_APOPTOSIS")
- **Constraints**: Must be unique within each `run_id`
- **Example**: `"GO:0006915"`

#### `pathway_size` (integer)
- **Description**: Number of genes in the pathway for this analysis
- **Constraints**: Must be ≥ 1
- **Note**: May differ from GMT if tool applies filtering (e.g., background genes)
- **Example**: `45`

#### `stat` (numeric)
- **Description**: Primary test statistic from enrichment analysis
- **Constraints**: 
  - Must be numeric (not NA for analyzed pathways)
  - **CRITICAL**: Must be monotonic - higher values = stronger enrichment
- **Usage**: This column is compared across real vs random runs
- **Examples**:
  - MAGMA: `BETA` column (effect size)
  - Effect size: Direct use
  - P-value: Use `-log10(p)` instead
  - Rank: Use `max_rank - rank` or `-rank`
- **Example**: `2.34`

#### `tool_name` (string)
- **Description**: Identifier for the enrichment tool
- **Format**: Lowercase, no spaces (use underscore)
- **Constraints**: Should match adapter directory name
- **Examples**: `"magma"`, `"gsea"`, `"my_tool"`

#### `run_id` (string)
- **Description**: Identifier for this enrichment run
- **Format**: 
  - Real data: `"real"`
  - Random data: `"random1"`, `"random2"`, ..., `"random1000"`
- **Constraints**: Must match the RUN_ID argument passed to adapter
- **Example**: `"real"`

### Optional Columns

These columns are not required but enhance interpretability:

#### `p` (numeric)
- **Description**: Raw p-value from the tool
- **Constraints**: Must be between 0 and 1 (inclusive)
- **Note**: Not used for empirical calculation, but useful for comparison
- **Example**: `0.021`

#### `effect` (numeric)
- **Description**: Effect size estimate
- **Note**: May be same as `stat` or different (e.g., Cohen's d vs t-statistic)
- **Example**: `0.45`

#### `se` (numeric)
- **Description**: Standard error of the effect size
- **Example**: `0.12`

#### `tool_version` (string)
- **Description**: Version of the enrichment tool used
- **Example**: `"1.10"`

#### `seed` (integer)
- **Description**: Random seed used (if applicable)
- **Example**: `12345`

#### `timestamp` (string)
- **Description**: When the analysis was run
- **Format**: ISO 8601 recommended
- **Example**: `"2026-02-24T14:30:00Z"`

## Example Output

### Minimal Valid Output

```tsv
pathway_id	pathway_size	stat	tool_name	run_id
GO:0006915	45	2.34	magma	real
GO:0008219	52	1.89	magma	real
KEGG_APOPTOSIS	38	3.12	magma	real
```

### Full Output with Optional Columns

```tsv
pathway_id	pathway_size	stat	p	effect	se	tool_name	tool_version	run_id
GO:0006915	45	2.34	0.021	0.45	0.12	magma	1.10	real
GO:0008219	52	1.89	0.054	0.31	0.11	magma	1.10	real
KEGG_APOPTOSIS	38	3.12	0.002	0.61	0.14	magma	1.10	real
```

### Real vs Random Runs

**Real run** (`run_id = "real"`):
```tsv
pathway_id	pathway_size	stat	tool_name	run_id
GO:0006915	45	2.34	magma	real
```

**Random run 1** (`run_id = "random1"`):
```tsv
pathway_id	pathway_size	stat	tool_name	run_id
GO:0006915	45	1.89	magma	random1
```

**Random run 2** (`run_id = "random2"`):
```tsv
pathway_id	pathway_size	stat	tool_name	run_id
GO:0006915	45	2.67	magma	random2
```

## Validation

The standardized output can be validated using:

```bash
Rscript scripts/validate_schema.R output.tsv
```

The validator checks:
- ✓ All required columns present
- ✓ Column types correct (numeric, string)
- ✓ No duplicate pathway_id within run_id
- ✓ pathway_size ≥ 1
- ✓ stat is numeric and not all NA
- ✓ p-values between 0-1 (if present)
- ✓ tool_name and run_id not empty

## Common Mistakes

### ❌ Using p-value as stat directly

```tsv
pathway_id	stat	...
GO:123	0.001	...    # Lower p = stronger, violates monotonic requirement
```

### ✅ Correct: Transform p-value

```tsv
pathway_id	stat	p	...
GO:123	6.90	0.001	...    # stat = -log10(0.001) = 6.90
```

### ❌ Duplicate pathway IDs in same run

```tsv
pathway_id	run_id	...
GO:123	real	...
GO:123	real	...    # Duplicate!
```

### ✅ Correct: Unique pathways per run

```tsv
pathway_id	run_id	...
GO:123	real	...
GO:456	real	...
```

### ❌ Wrong run_id

```bash
# Adapter receives: RUN_ID="random42"
# But outputs:
pathway_id	run_id	...
GO:123	real	...    # Should be "random42"!
```

### ✅ Correct: Use passed RUN_ID

```bash
# Adapter receives: RUN_ID="random42"
# Outputs:
pathway_id	run_id	...
GO:123	random42	...
```

## Integration with GSR-Adjust

### How `stat` is Used

1. **Real run**: Tool analyzes real pathway database
   ```
   GO:0006915 → stat = 2.34
   ```

2. **Random runs**: Tool analyzes 1000 randomized databases
   ```
   GO:0006915 → random1: stat = 1.89
   GO:0006915 → random2: stat = 2.67
   GO:0006915 → random3: stat = 1.45
   ...
   ```

3. **Empirical p-value**: Compare real to null distribution
   ```
   empirical_p = (1 + #{random stats ≥ 2.34}) / 1001
   ```

4. **Z-score**: Standardize effect
   ```
   z_score = (2.34 - mean(random stats)) / sd(random stats)
   ```

### Final Output

GSR-Adjust produces `{tool}_adjusted.tsv`:

```tsv
pathway_id	pathway_size	stat	empirical_p	fdr	z_score	null_mean	null_sd	...
GO:0006915	45	2.34	0.001	0.003	3.5	1.85	0.14	...
```

## Tool-Specific Examples

### MAGMA

MAGMA outputs `.gsa.out` with columns:
```
FULL_NAME  NGENES  BETA  P  BETA_STD  SE
```

Convert to:
```tsv
pathway_id←FULL_NAME	pathway_size←NGENES	stat←BETA	p←P	effect←BETA	se←SE
```

### GSEA

GSEA outputs with columns:
```
NAME  SIZE  ES  NES  NOM p-val  FDR q-val
```

Convert to:
```tsv
pathway_id←NAME	pathway_size←SIZE	stat←NES	p←NOM p-val	effect←ES
```

Note: Use NES (normalized enrichment score) not p-value as stat!

### Custom Tool (p-value only)

If your tool only outputs p-values:

```r
# Transform p-value for stat column
stat = -log10(p_value)

# Keep original p-value in 'p' column
standardized <- data.table(
  pathway_id = ...,
  pathway_size = ...,
  stat = -log10(raw$pvalue),
  p = raw$pvalue,
  tool_name = "my_tool",
  run_id = run_id
)
```

## Best Practices

1. **Always validate**: Run `validate_schema.R` during development
2. **Document stat**: In your adapter docs, explain what `stat` represents
3. **Preserve precision**: Don't round statistical values
4. **Handle missing data**: If pathway not analyzed, omit row (don't include NA stat)
5. **Consistent tool_name**: Use same string across all runs
6. **Match run_id**: Always use the RUN_ID argument passed to adapter

## See Also

- [ADAPTER_GUIDE.md](ADAPTER_GUIDE.md) - How to create adapters
- [QUICK_START.md](QUICK_START.md) - Using the pipeline
- `scripts/validate_schema.R` - Schema validation script
