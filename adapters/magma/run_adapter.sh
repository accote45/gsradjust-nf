#!/bin/bash

# MAGMA Adapter for GSR-Adjust
# 
# Runs MAGMA gene-set analysis and converts output to standard schema

set -e
set -u

# ============================================================================
# Parse Arguments
# ============================================================================

GMT_FILE=$1
RUN_ID=$2
CONFIG_JSON=$3
OUTPUT_FILE=$4

echo "========================================="
echo "MAGMA Adapter: ${RUN_ID}"
echo "========================================="
echo "GMT file: ${GMT_FILE}"
echo "Config: ${CONFIG_JSON}"
echo "Output: ${OUTPUT_FILE}"
echo "========================================="

# ============================================================================
# Extract MAGMA-Specific Inputs
# ============================================================================

# MAGMA requires gene-level results file from prior gene analysis
GENE_RESULTS=$(jq -r '.gene_results_file' $CONFIG_JSON)

# Optional: Background genes (if not using all genes in gene results)
# BACKGROUND_GENES=$(jq -r '.background_genes // empty' $CONFIG_JSON)

echo "Gene results: ${GENE_RESULTS}"

# Verify gene results file exists
if [ ! -f "${GENE_RESULTS}" ]; then
    echo "ERROR: Gene results file not found: ${GENE_RESULTS}"
    exit 1
fi

# ============================================================================
# Run MAGMA Gene-Set Analysis
# ============================================================================

echo ""
echo "Running MAGMA gene-set analysis..."

# Load MAGMA module (HPC-specific - adjust for your environment)
module load magma_gwas/1.10

# Run MAGMA
# NOTE: The --gene-results should point to the .genes.raw file
# NOT the .genes.out file
magma \
  --gene-results ${GENE_RESULTS} \
  --set-annot ${GMT_FILE} \
  --out ${RUN_ID}_magma

echo "MAGMA analysis complete"

# ============================================================================
# Parse MAGMA Output to Standard Schema
# ============================================================================

echo ""
echo "Parsing MAGMA output to standard schema..."

# MAGMA outputs a .gsa.out file with these columns:
# VARIABLE  TYPE  NGENES  BETA  BETA_STD  SE  P  FULL_NAME

# Call R parser to convert to standard schema
Rscript $(dirname $0)/parse_magma.R \
  ${RUN_ID}_magma.gsa.out \
  ${RUN_ID} \
  ${OUTPUT_FILE}

echo ""
echo "========================================="
echo "MAGMA adapter complete: ${OUTPUT_FILE}"
echo "========================================="
