#!/bin/bash

# Standard Adapter Interface for GSR-Adjust
# 
# This script is called by the Nextflow pipeline for each enrichment run.
# It must:
#   1. Run your enrichment tool
#   2. Parse output to standard schema
#   3. Output a TSV file with required columns
#
# Arguments (DO NOT CHANGE):
#   $1 = GMT_FILE: Path to gene set database file
#   $2 = RUN_ID: "real" or "random1", "random2", etc.
#   $3 = CONFIG_JSON: Path to JSON file with tool-specific inputs
#   $4 = OUTPUT_FILE: Path where standardized TSV should be written

set -e  # Exit on error
set -u  # Exit on undefined variable

# ============================================================================
# Parse Arguments
# ============================================================================

GMT_FILE=$1
RUN_ID=$2
CONFIG_JSON=$3
OUTPUT_FILE=$4

echo "========================================="
echo "Template Adapter: ${RUN_ID}"
echo "========================================="
echo "GMT file: ${GMT_FILE}"
echo "Config: ${CONFIG_JSON}"
echo "Output: ${OUTPUT_FILE}"
echo "========================================="

# ============================================================================
# Extract Tool-Specific Inputs from Config
# ============================================================================

# Example: Extract GWAS summary stats file from JSON config
# You'll need jq installed or use another method to parse JSON
GWAS_FILE=$(jq -r '.gwas_file' $CONFIG_JSON)

# Add more config extractions as needed:
# BACKGROUND_GENES=$(jq -r '.background_genes' $CONFIG_JSON)
# REFERENCE_PANEL=$(jq -r '.reference_panel' $CONFIG_JSON)

echo "GWAS file: ${GWAS_FILE}"

# ============================================================================
# Run Your Enrichment Tool
# ============================================================================

echo ""
echo "Running enrichment tool..."

# TODO: REPLACE THIS SECTION WITH YOUR TOOL'S COMMAND
# 
# Example:
# my_enrichment_tool \
#   --gene-sets ${GMT_FILE} \
#   --gwas ${GWAS_FILE} \
#   --output ${RUN_ID}_raw_output.txt \
#   --threads 1

# For this template, create dummy output
cat > ${RUN_ID}_raw_output.txt <<EOF
pathway	pvalue	effect_size	n_genes
GO:0006915	0.001	2.5	45
GO:0008219	0.01	1.8	52
KEGG_APOPTOSIS	0.05	1.2	38
EOF

echo "Tool execution complete"

# ============================================================================
# Parse Output to Standard Schema
# ============================================================================

echo ""
echo "Parsing output to standard schema..."

# TODO: REPLACE THIS WITH YOUR PARSING LOGIC
# 
# You can use Python, R, awk, or any tool that can read your tool's
# output and convert it to the standard schema.
#
# Option 1: Use a Python script
# python parse_output.py ${RUN_ID}_raw_output.txt --run-id ${RUN_ID} --output ${OUTPUT_FILE}
#
# Option 2: Use an R script
# Rscript parse_output.R ${RUN_ID}_raw_output.txt ${RUN_ID} ${OUTPUT_FILE}
#
# Option 3: Use awk (for simple cases)
# awk -v run_id=${RUN_ID} 'NR>1 {print $1"\t"$4"\t"$3"\t"$2"\tmy_tool\t"run_id}' \
#   ${RUN_ID}_raw_output.txt > ${OUTPUT_FILE}

# For this template, create properly formatted output
cat > ${OUTPUT_FILE} <<EOF
pathway_id	pathway_size	stat	p	effect	se	tool_name	tool_version	run_id
GO:0006915	45	2.5	0.001	2.5	0.5	template_tool	1.0.0	${RUN_ID}
GO:0008219	52	1.8	0.01	1.8	0.4	template_tool	1.0.0	${RUN_ID}
KEGG_APOPTOSIS	38	1.2	0.05	1.2	0.3	template_tool	1.0.0	${RUN_ID}
EOF

# ============================================================================
# Standard Schema Definition
# ============================================================================
# 
# Your OUTPUT_FILE must be a tab-delimited file with these columns:
#
# REQUIRED:
#   pathway_id      - Unique pathway identifier (from GMT first column)
#   pathway_size    - Number of genes in pathway
#   stat            - Primary test statistic (MUST be monotonic: higher = more enriched)
#   tool_name       - Your tool's name (matches manifest.yaml)
#   run_id          - The RUN_ID passed as argument (real/random1/random2/etc.)
#
# OPTIONAL (but recommended):
#   p               - Raw p-value from your tool (if available)
#   effect          - Effect size estimate
#   se              - Standard error of effect
#   tool_version    - Version of your tool
#   seed            - Random seed used (if applicable)
#   timestamp       - When analysis ran
#
# CRITICAL: The 'stat' column must be monotonic!
#   - If your tool outputs a score where higher = more enriched: use as-is
#   - If your tool outputs a score where lower = more enriched: invert it!
#     Example: stat = -log10(p_value) or stat = 1/original_score
#
# ============================================================================

echo ""
echo "========================================="
echo "Adapter complete: ${OUTPUT_FILE}"
echo "========================================="

# Optional: Validate schema before returning
# Rscript $(dirname $0)/../../scripts/validate_schema.R ${OUTPUT_FILE}
