#!/usr/bin/env Rscript

# Parse MAGMA .gsa.out file to standard schema
# Usage: Rscript parse_magma.R <magma_gsa_file> <run_id> <output_file>

library(data.table)

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 3) {
  stop("Usage: Rscript parse_magma.R <magma_gsa_file> <run_id> <output_file>")
}

magma_file <- args[1]
run_id <- args[2]
output_file <- args[3]

# Read MAGMA output
# Expected columns: VARIABLE TYPE NGENES BETA BETA_STD SE P FULL_NAME
raw <- fread(magma_file)

# Verify required columns exist
required_cols <- c("FULL_NAME", "NGENES", "BETA", "P", "BETA_STD", "SE")
missing <- setdiff(required_cols, colnames(raw))
if (length(missing) > 0) {
  stop("Missing columns in MAGMA output: ", paste(missing, collapse = ", "))
}

# Convert to standard schema
standardized <- data.table(
  pathway_id = raw$FULL_NAME,
  pathway_size = raw$NGENES,
  stat = raw$BETA,              # MAGMA beta is our primary statistic
  p = raw$P,                    # Raw p-value from MAGMA
  effect = raw$BETA,            # Effect size
  se = raw$SE,                  # Standard error
  tool_name = "magma",
  tool_version = "1.10",
  run_id = run_id
)

# Write to output
fwrite(standardized, output_file, sep = "\t")

cat("Converted", nrow(standardized), "pathways from MAGMA output\n")
cat("Output written to:", output_file, "\n")
