#!/usr/bin/env Rscript

# Validate that adapter output follows the standard schema
# Usage: Rscript validate_schema.R <output_file>

library(data.table)

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1) {
  stop("Usage: Rscript validate_schema.R <output_file>")
}

output_file <- args[1]

cat("========================================\n")
cat("Schema Validation\n")
cat("========================================\n")
cat("File:", output_file, "\n")
cat("========================================\n\n")

# Define required schema
REQUIRED_COLS <- c("pathway_id", "pathway_size", "stat", "tool_name", "run_id")
OPTIONAL_COLS <- c("p", "effect", "se", "tool_version", "seed", "timestamp")
RECOMMENDED_COLS <- c("p", "effect")

# Read file
if (!file.exists(output_file)) {
  stop("ERROR: File does not exist: ", output_file)
}

data <- tryCatch({
  fread(output_file)
}, error = function(e) {
  stop("ERROR: Could not read file as TSV: ", e$message)
})

cat("Loaded", nrow(data), "rows\n\n")

# ============================================================================
# Validate Required Columns
# ============================================================================

cat("Checking required columns...\n")
missing_required <- setdiff(REQUIRED_COLS, colnames(data))

if (length(missing_required) > 0) {
  cat("\n❌ VALIDATION FAILED\n")
  cat("Missing required columns:", paste(missing_required, collapse = ", "), "\n\n")
  cat("Required columns:\n")
  cat("  - pathway_id: Unique pathway identifier (character)\n")
  cat("  - pathway_size: Number of genes in pathway (integer)\n")
  cat("  - stat: Primary test statistic, higher = more enriched (numeric)\n")
  cat("  - tool_name: Tool identifier (character)\n")
  cat("  - run_id: 'real' or 'random1', 'random2', etc. (character)\n")
  stop("Schema validation failed")
} else {
  cat("✓ All required columns present\n\n")
}

# ============================================================================
# Validate Column Types and Values
# ============================================================================

cat("Checking column types and values...\n")

errors <- c()

# pathway_id: should be unique within run_id
if (!is.character(data$pathway_id) && !is.factor(data$pathway_id)) {
  errors <- c(errors, "pathway_id must be character type")
}

duplicates <- data[, .N, by = .(run_id, pathway_id)][N > 1]
if (nrow(duplicates) > 0) {
  errors <- c(errors, paste0("Duplicate pathway_id found within run_id: ", 
                            nrow(duplicates), " duplicates"))
}

# pathway_size: should be positive integer
if (!is.numeric(data$pathway_size)) {
  errors <- c(errors, "pathway_size must be numeric")
}
if (any(data$pathway_size < 1, na.rm = TRUE)) {
  errors <- c(errors, "pathway_size must be >= 1")
}

# stat: should be numeric, can't all be NA
if (!is.numeric(data$stat)) {
  errors <- c(errors, "stat must be numeric")
}
if (all(is.na(data$stat))) {
  errors <- c(errors, "stat column is all NA")
}

# tool_name: should not be empty
if (!is.character(data$tool_name) && !is.factor(data$tool_name)) {
  errors <- c(errors, "tool_name must be character type")
}
if (any(is.na(data$tool_name) | data$tool_name == "")) {
  errors <- c(errors, "tool_name contains empty values")
}

# run_id: should not be empty
if (!is.character(data$run_id) && !is.factor(data$run_id)) {
  errors <- c(errors, "run_id must be character type")
}
if (any(is.na(data$run_id) | data$run_id == "")) {
  errors <- c(errors, "run_id contains empty values")
}

# Optional: p-value validation if present
if ("p" %in% colnames(data)) {
  if (!is.numeric(data$p)) {
    errors <- c(errors, "p must be numeric")
  }
  if (any(data$p < 0 | data$p > 1, na.rm = TRUE)) {
    errors <- c(errors, "p-values must be between 0 and 1")
  }
}

if (length(errors) > 0) {
  cat("\n❌ VALIDATION FAILED\n")
  cat("Errors found:\n")
  for (err in errors) {
    cat("  -", err, "\n")
  }
  stop("Schema validation failed")
} else {
  cat("✓ All column types valid\n\n")
}

# ============================================================================
# Check Optional/Recommended Columns
# ============================================================================

present_optional <- intersect(OPTIONAL_COLS, colnames(data))
missing_recommended <- setdiff(RECOMMENDED_COLS, colnames(data))

if (length(present_optional) > 0) {
  cat("Optional columns present:", paste(present_optional, collapse = ", "), "\n")
}

if (length(missing_recommended) > 0) {
  cat("⚠️  Recommended columns missing:", paste(missing_recommended, collapse = ", "), "\n")
  cat("   (Not required, but helpful for interpretation)\n")
}

# ============================================================================
# Summary
# ============================================================================

cat("\n========================================\n")
cat("✓ VALIDATION PASSED\n")
cat("========================================\n")
cat("File:", output_file, "\n")
cat("Rows:", nrow(data), "\n")
cat("Pathways:", length(unique(data$pathway_id)), "\n")
cat("Run(s):", paste(unique(data$run_id), collapse = ", "), "\n")
cat("Tool:", unique(data$tool_name)[1], "\n")
cat("========================================\n")
