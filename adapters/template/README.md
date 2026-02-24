# Template Adapter

This directory contains a template for creating new tool adapters for GSR-Adjust.

## Files

- `manifest.yaml` - Defines adapter metadata and requirements
- `run_adapter.sh` - Main entry point (standard interface)
- `README.md` - This file

## How to Create Your Own Adapter

### Step 1: Copy the Template

```bash
cd gsradjust-nf/adapters
cp -r template my_tool
cd my_tool
```

### Step 2: Edit manifest.yaml

Update the adapter configuration:

```yaml
name: my_tool
version: 2.1.0
description: Brief description of your tool

input_format: gmt  # or json, bed, etc.

required_inputs:
  gwas_summary_stats: true
  # Add any other required files

stat_type: enrichment_score  # Describe what your statistic represents
higher_is_more_enriched: true  # CRITICAL: Is higher stat more enriched?
supports_p_value: true  # Does tool output p-values?
```

### Step 3: Modify run_adapter.sh

The script has three main sections to customize:

#### Section 1: Extract Config

```bash
# Extract tool-specific inputs from JSON
GWAS_FILE=$(jq -r '.gwas_file' $CONFIG_JSON)
EXPRESSION_FILE=$(jq -r '.expression_file' $CONFIG_JSON)
# etc.
```

#### Section 2: Run Your Tool

```bash
# Replace with your actual tool command
my_enrichment_tool \
  --gene-sets ${GMT_FILE} \
  --gwas ${GWAS_FILE} \
  --output ${RUN_ID}_raw_output.txt
```

#### Section 3: Parse to Standard Schema

Option A - Python parser:
```bash
python parse_output.py \
  ${RUN_ID}_raw_output.txt \
  --run-id ${RUN_ID} \
  --output ${OUTPUT_FILE}
```

Option B - R parser:
```bash
Rscript parse_output.R \
  ${RUN_ID}_raw_output.txt \
  ${RUN_ID} \
  ${OUTPUT_FILE}
```

Option C - Simple awk:
```bash
awk -v rid=${RUN_ID} 'NR>1 {
  print $1 "\t" $4 "\t" $3 "\t" $2 "\tmy_tool\t" rid
}' ${RUN_ID}_raw_output.txt > ${OUTPUT_FILE}
```

### Step 4: Create Config JSON

Create `config/my_tool_config.json`:

```json
{
  "gwas_file": "/path/to/gwas_summary_stats.txt",
  "background_genes": "/path/to/background.txt",
  "reference_panel": "/path/to/reference"
}
```

### Step 5: Test Your Adapter

Test on a single GMT file:

```bash
cd gsradjust-nf
bash adapters/my_tool/run_adapter.sh \
  test_data/small_pathways.gmt \
  test \
  config/my_tool_config.json \
  test_output.tsv
```

Validate the output:

```bash
Rscript scripts/validate_schema.R test_output.tsv
```

Expected output:
```
✓ VALIDATION PASSED
File: test_output.tsv
Rows: 50
Pathways: 50
Run(s): test
Tool: my_tool
```

### Step 6: Run Full Pipeline

```bash
nextflow run main.nf \
  --gmt_file data/pathways.gmt \
  --adapter my_tool \
  --adapter_config config/my_tool_config.json \
  --num_random_sets 1000 \
  --outdir results
```

## Standard Schema Reference

Your adapter MUST output a TSV file with these columns:

### Required Columns

| Column | Type | Description |
|--------|------|-------------|
| `pathway_id` | string | Unique pathway identifier (from GMT) |
| `pathway_size` | integer | Number of genes in pathway |
| `stat` | numeric | Primary test statistic (higher = more enriched) |
| `tool_name` | string | Tool identifier (matches manifest.yaml) |
| `run_id` | string | "real", "random1", "random2", etc. |

### Optional Columns

| Column | Type | Description |
|--------|------|-------------|
| `p` | numeric | Raw p-value (0-1) |
| `effect` | numeric | Effect size estimate |
| `se` | numeric | Standard error |
| `tool_version` | string | Tool version |

## Critical: The `stat` Column

The `stat` column is the PRIMARY test statistic used for empirical adjustment. It MUST be **monotonic**:

- **Higher stat = stronger enrichment**

If your tool outputs a score where **lower = stronger** (e.g., p-values), you must **invert** it:

```bash
# Good: -log10(p-value)
stat = -log10(p_value)

# Good: Negative of original
stat = -original_score

# Good: Inverse
stat = 1 / original_score
```

## Common Pitfalls

❌ **Don't**: Use p-values directly as stat (lower is better)
✓ **Do**: Use -log10(p-value) or effect size

❌ **Don't**: Forget to set `run_id` to the argument passed
✓ **Do**: Always use `run_id=${RUN_ID}` in output

❌ **Don't**: Hard-code file paths in the adapter
✓ **Do**: Read paths from CONFIG_JSON

❌ **Don't**: Skip schema validation
✓ **Do**: Run `validate_schema.R` during development

## Examples

See working examples in:
- `adapters/magma/` - MAGMA gene-set analysis
- `adapters/example_simple/` - Minimal working example

## Getting Help

- Full documentation: `docs/ADAPTER_GUIDE.md`
- Schema details: `docs/SCHEMA.md`
- Open an issue: [GitHub Issues](https://github.com/yourusername/gsradjust-nf/issues)
