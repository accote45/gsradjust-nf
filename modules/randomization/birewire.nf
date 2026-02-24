/*
 * BiReWire Randomization Module
 * 
 * Generates randomized gene set databases while preserving:
 * - Pathway sizes (number of genes per pathway)
 * - Gene degree distribution (number of pathways per gene)
 */

process generate_birewire_gmts {
    tag "birewire_randomization"
    publishDir "${params.outdir}/random_genesets", mode: 'copy', pattern: "*.gmt"
    
    input:
    path(gmt_file)
    val(num_random_sets)
    
    output:
    path("GeneSet.random*.gmt")
    
    script:
    """
    Rscript ${projectDir}/scripts/generate_birewire_gmts.R \
        ${gmt_file} \
        . \
        ${num_random_sets}
    """
}
