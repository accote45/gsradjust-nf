/*
 * Generic Adapter Executor
 * 
 * Runs any enrichment tool adapter that follows the standard interface:
 * bash run_adapter.sh <GMT_FILE> <RUN_ID> <CONFIG_JSON> <OUTPUT_FILE>
 */

process run_adapter {
    tag "${run_id}"
    publishDir "${params.outdir}/adapter_outputs/${run_id}", mode: 'copy'
    
    input:
    path(gmt_file)
    val(run_id)
    val(adapter_name)
    path(adapter_config)
    
    output:
    path("${run_id}_standardized.tsv")
    
    script:
    // Determine adapter directory (built-in or custom)
    def adapter_dir = adapter_name.startsWith('/') ? 
                      adapter_name : 
                      "${projectDir}/adapters/${adapter_name}"
    
    """
    # Check if adapter exists
    if [ ! -f ${adapter_dir}/run_adapter.sh ]; then
        echo "ERROR: Adapter not found at ${adapter_dir}"
        echo "Expected file: ${adapter_dir}/run_adapter.sh"
        exit 1
    fi
    
    # Run adapter with standardized interface
    bash ${adapter_dir}/run_adapter.sh \
        ${gmt_file} \
        ${run_id} \
        ${adapter_config} \
        ${run_id}_standardized.tsv
    
    # Validate output schema
    if [ -f ${projectDir}/scripts/validate_schema.R ]; then
        Rscript ${projectDir}/scripts/validate_schema.R ${run_id}_standardized.tsv
    fi
    """
}
