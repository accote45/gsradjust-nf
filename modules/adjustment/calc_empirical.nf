/*
 * Empirical P-value Calculation
 * 
 * Calculates pathway-specific null distributions:
 * - Empirical p-value: (1 + #{nulls >= real}) / (K + 1)
 * - Z-score: (real - mean(nulls)) / sd(nulls)
 */

process calc_empirical {
    publishDir "${params.outdir}", mode: 'copy'
    
    input:
    path(real_results)
    path(random_results)
    val(tool_name)
    
    output:
    path("${tool_name}_adjusted.tsv")
    path("diagnostics/*")
    
    script:
    """
    # Create random results directory
    mkdir -p random_results
    
    # Move all random results to directory
    for file in ${random_results}; do
        cp \$file random_results/
    done
    
    # Calculate empirical p-values
    Rscript ${projectDir}/scripts/calc_empirical.R \
        ${real_results} \
        random_results/ \
        ${tool_name}_adjusted.tsv
    
    # Create diagnostics directory
    mkdir -p diagnostics
    
    # Generate diagnostic plots (if script exists)
    if [ -f ${projectDir}/scripts/diagnostic_plots.R ]; then
        Rscript ${projectDir}/scripts/diagnostic_plots.R \
            ${tool_name}_adjusted.tsv \
            diagnostics/
    fi
    """
}
