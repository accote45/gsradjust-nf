#!/usr/bin/env Rscript

# Calculate empirical p-values and standardized effects using pathway-specific nulls
# 
# For each pathway:
#   - Empirical p-value: (1 + #{null stats >= real stat}) / (K + 1)
#   - Z-score: (real stat - mean(null stats)) / sd(null stats)
#
# Usage: Rscript calc_empirical.R <real_results> <random_dir> <output_file>

library(tidyverse)
library(data.table)

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 3) {
  stop("Usage: Rscript calc_empirical.R <real_results> <random_dir> <output_file>")
}

real_file <- args[1]
random_dir <- args[2]
output_file <- args[3]

cat("========================================\n")
cat("GSR Empirical Adjustment\n")
cat("========================================\n")
cat("Real results:", real_file, "\n")
cat("Random results dir:", random_dir, "\n")
cat("Output file:", output_file, "\n")
cat("========================================\n\n")

# Required columns in standardized schema
REQUIRED_COLS <- c("pathway_id", "pathway_size", "stat", "tool_name", "run_id")

# ============================================================================
# Read Real Results
# ============================================================================

cat("Reading real results...\n")
real_data <- fread(real_file)

# Validate schema
missing_cols <- setdiff(REQUIRED_COLS, colnames(real_data))
if (length(missing_cols) > 0) {
  stop("Real results missing required columns: ", paste(missing_cols, collapse = ", "),
       "\n\nRequired columns: ", paste(REQUIRED_COLS, collapse = ", "),
       "\n\nExpected schema:",
       "\n  pathway_id: Pathway identifier",
       "\n  pathway_size: Number of genes in pathway",
       "\n  stat: Primary test statistic (higher = more enriched)",
       "\n  tool_name: Tool identifier",
       "\n  run_id: Must be 'real' for real results")
}

# Verify run_id is "real"
if (!all(real_data$run_id == "real")) {
  warning("Expected run_id='real' for all rows in real results file")
}

cat("Loaded", nrow(real_data), "pathways from real results\n\n")

# ============================================================================
# Read Random Results
# ============================================================================

cat("Reading random results from directory...\n")
random_files <- list.files(random_dir, pattern = "*_standardized.tsv$", 
                          full.names = TRUE, recursive = TRUE)

if (length(random_files) == 0) {
  stop("No random result files found in: ", random_dir,
       "\nExpected files matching pattern: *_standardized.tsv")
}

cat("Found", length(random_files), "random result files\n")

# Read all random results
random_data <- rbindlist(lapply(random_files, function(f) {
  tryCatch({
    fread(f)
  }, error = function(e) {
    warning("Error reading file ", f, ": ", e$message)
    return(NULL)
  })
}), fill = TRUE)

# Validate random data schema
missing_cols <- setdiff(REQUIRED_COLS, colnames(random_data))
if (length(missing_cols) > 0) {
  stop("Random results missing required columns: ", paste(missing_cols, collapse = ", "))
}

# Filter to only random runs (not "real")
random_data <- random_data[run_id != "real"]

cat("Loaded", nrow(random_data), "pathway results from random runs\n")
cat("Number of random runs:", length(unique(random_data$run_id)), "\n\n")

# Verify we have enough random results
n_random_runs <- length(unique(random_data$run_id))
if (n_random_runs < 100) {
  warning("Only ", n_random_runs, " random runs found. ",
          "Recommend at least 1000 for stable empirical p-values.")
}

# ============================================================================
# Calculate Empirical P-values and Z-scores
# ============================================================================

cat("Calculating pathway-specific empirical statistics...\n\n")

# For each pathway in real results, compare to its own randomized versions
adjusted_results <- lapply(1:nrow(real_data), function(i) {
  pathway <- real_data$pathway_id[i]
  real_stat <- real_data$stat[i]
  
  # Get null distribution for THIS pathway
  null_stats <- random_data[pathway_id == pathway, stat]
  
  if (length(null_stats) == 0) {
    warning("No random results found for pathway: ", pathway)
    return(NULL)
  }
  
  if (length(null_stats) < 10) {
    warning("Only ", length(null_stats), " random results for pathway: ", pathway)
  }
  
  # Calculate empirical p-value: (1 + #{nulls >= real}) / (K + 1)
  n_greater_equal <- sum(null_stats >= real_stat, na.rm = TRUE)
  K <- length(null_stats)
  empirical_p <- (1 + n_greater_equal) / (K + 1)
  
  # Calculate standardized effect (z-score): (real - mean(null)) / sd(null)
  null_mean <- mean(null_stats, na.rm = TRUE)
  null_sd <- sd(null_stats, na.rm = TRUE)
  z_score <- if (null_sd > 0) {
    (real_stat - null_mean) / null_sd
  } else {
    NA_real_
  }
  
  # Combine with original data
  result <- as.list(real_data[i, ])
  result$empirical_p <- empirical_p
  result$z_score <- z_score
  result$null_mean <- null_mean
  result$null_sd <- null_sd
  result$n_random_obs <- K
  
  return(result)
})

# Convert to data.table
adjusted_dt <- rbindlist(adjusted_results, fill = TRUE)

# Remove rows where calculation failed
adjusted_dt <- adjusted_dt[!is.na(empirical_p)]

# Sort by empirical p-value
adjusted_dt <- adjusted_dt[order(empirical_p)]

cat("Successfully calculated empirical statistics for", nrow(adjusted_dt), "pathways\n")

# Add FDR correction
adjusted_dt[, fdr := p.adjust(empirical_p, method = "BH")]

# ============================================================================
# Summary Statistics
# ============================================================================

cat("\n========================================\n")
cat("Summary Statistics\n")
cat("========================================\n")
cat("Total pathways analyzed:", nrow(adjusted_dt), "\n")
cat("Min empirical p-value:", min(adjusted_dt$empirical_p), "\n")
cat("Pathways with p < 0.05:", sum(adjusted_dt$empirical_p < 0.05), "\n")
cat("Pathways with FDR < 0.05:", sum(adjusted_dt$fdr < 0.05), "\n")
cat("========================================\n\n")

# ============================================================================
# Write Output
# ============================================================================

cat("Writing adjusted results to:", output_file, "\n")

# Reorder columns for clarity
output_cols <- c("pathway_id", "pathway_size", "stat", "empirical_p", "fdr", "z_score",
                "null_mean", "null_sd", "n_random_obs", "tool_name")

# Add any optional columns that exist (like 'p', 'effect', 'se')
optional_cols <- c("p", "effect", "se", "tool_version", "run_id")
output_cols <- c(output_cols, intersect(optional_cols, names(adjusted_dt)))

# Select and write
fwrite(adjusted_dt[, ..output_cols], output_file, sep = "\t")

cat("\n========================================\n")
cat("SUCCESS!\n")
cat("Adjusted results written to:", output_file, "\n")
cat("========================================\n")
