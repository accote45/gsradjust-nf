#!/usr/bin/env nextflow
/*
 * GSR-Adjust: Gene Set Randomization Adjustment Pipeline
 * 
 * A tool-agnostic pipeline for adjusting pathway enrichment results
 * using BiReWire randomization to account for gene overlap.
 */

nextflow.enable.dsl=2

// ============================================================================
// Parameters
// ============================================================================

params {
    // Required inputs
    gmt_file = null                      // Original gene set database (GMT format)
    adapter = null                       // Adapter name (e.g., "magma", "prset") or path to custom adapter
    adapter_config = null                // JSON file with tool-specific configuration
    
    // GSR parameters
    num_random_sets = 1000              // Number of randomized gene sets to generate
    
    // Output
    outdir = "results"
    
    // Optional
    help = false
}

// ============================================================================
// Help Message
// ============================================================================

def helpMessage() {
    log.info"""
    ============================================================================
    GSR-Adjust: Gene Set Randomization Adjustment Pipeline
    ============================================================================
    
    Usage:
      nextflow run main.nf --gmt_file <FILE> --adapter <NAME> --adapter_config <JSON>
    
    Required Arguments:
      --gmt_file           Path to GMT gene set database file
      --adapter            Adapter name (magma, prset, etc.) or path to custom adapter
      --adapter_config     JSON file with tool-specific inputs
    
    Optional Arguments:
      --num_random_sets    Number of random gene sets to generate [default: 1000]
      --outdir             Output directory [default: results]
    
    Examples:
      # Run with MAGMA adapter
      nextflow run main.nf \\
        --gmt_file data/pathways.gmt \\
        --adapter magma \\
        --adapter_config config/magma_config.json
      
      # Run with custom adapter
      nextflow run main.nf \\
        --gmt_file data/pathways.gmt \\
        --adapter /path/to/my_adapter \\
        --adapter_config config/my_config.json
    
    For more information, see docs/QUICK_START.md
    ============================================================================
    """.stripIndent()
}

if (params.help) {
    helpMessage()
    exit 0
}

// ============================================================================
// Input Validation
// ============================================================================

if (!params.gmt_file) {
    log.error "ERROR: --gmt_file is required"
    helpMessage()
    exit 1
}

if (!params.adapter) {
    log.error "ERROR: --adapter is required"
    helpMessage()
    exit 1
}

if (!params.adapter_config) {
    log.error "ERROR: --adapter_config is required"
    helpMessage()
    exit 1
}

// ============================================================================
// Include Modules
// ============================================================================

include { generate_birewire_gmts } from './modules/randomization/birewire'
include { run_adapter } from './modules/adapter/run_adapter'
include { calc_empirical } from './modules/adjustment/calc_empirical'

// ============================================================================
// Main Workflow
// ============================================================================

workflow {
    log.info """
    ============================================================================
    GSR-Adjust Pipeline
    ============================================================================
    GMT file         : ${params.gmt_file}
    Adapter          : ${params.adapter}
    Random sets      : ${params.num_random_sets}
    Output directory : ${params.outdir}
    ============================================================================
    """.stripIndent()
    
    // Input files
    gmt_file = file(params.gmt_file)
    adapter_config = file(params.adapter_config)
    
    // 1. Generate randomized gene sets using BiReWire
    random_gmts = generate_birewire_gmts(
        gmt_file,
        params.num_random_sets
    )
    
    // 2. Run enrichment on REAL gene sets
    real_results = run_adapter(
        gmt_file,
        "real",
        params.adapter,
        adapter_config
    )
    
    // 3. Run enrichment on RANDOM gene sets (1000 permutations)
    random_inputs = random_gmts
        .flatten()
        .map { gmt -> 
            // Extract permutation number from filename (e.g., GeneSet.random123.gmt)
            def matcher = (gmt.name =~ /random(\d+)/)
            def perm = matcher ? matcher[0][1] : "unknown"
            tuple(gmt, "random${perm}")
        }
    
    random_results = run_adapter(
        random_inputs.map { it[0] },
        random_inputs.map { it[1] },
        params.adapter,
        adapter_config
    )
    
    // 4. Collect all random results
    all_random_results = random_results.collect()
    
    // 5. Calculate empirical p-values and standardized effects
    adjusted_results = calc_empirical(
        real_results,
        all_random_results,
        params.adapter
    )
}

// ============================================================================
// Workflow Completion
// ============================================================================

workflow.onComplete {
    log.info """
    ============================================================================
    Pipeline Completed!
    ============================================================================
    Status      : ${workflow.success ? 'SUCCESS' : 'FAILED'}
    Duration    : ${workflow.duration}
    Output dir  : ${params.outdir}
    
    Results:
      - Adjusted results : ${params.outdir}/${params.adapter}_adjusted.tsv
      - Diagnostics      : ${params.outdir}/diagnostics/
    ============================================================================
    """.stripIndent()
}
