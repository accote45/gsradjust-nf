# Example Data

This directory should contain example/test datasets for validating the pipeline.

## What to Include

### Test GMT File
Create a small gene set database for quick testing:
- **File**: `small_pathways.gmt`
- **Size**: 10-20 pathways, 50-100 genes total
- **Format**: Standard GMT (pathway\tdescription\tgene1\tgene2\t...)

### Example Config
- **File**: `example_magma_config.json`
- **Content**: Template configuration with placeholder paths

## Creating Test Data

### Minimal GMT File

```bash
cat > small_pathways.gmt << 'EOF'
GO:0006915_APOPTOSIS	apoptosis	CASP3	CASP8	CASP9	BAX	BCL2
GO:0008219_CELL_DEATH	cell death	CASP3	CASP8	TP53	BAX	BCL2	FAS
KEGG_APOPTOSIS	KEGG apoptosis pathway	CASP3	CASP8	CASP9	TP53	BAX	BCL2	FAS	BID
GO:0006281_DNA_REPAIR	DNA repair	TP53	BRCA1	BRCA2	ATM	PTEN
KEGG_P53_PATHWAY	p53 signaling	TP53	BAX	BCL2	CASP3	CASP9	ATM	PTEN
EOF
```

### Test Config

```json
{
  "gene_results_file": "examples/test_gene_results.genes.raw",
  "_comment": "Replace with actual paths for real analysis"
}
```

## Usage

Test the pipeline with example data:

```bash
nextflow run main.nf \
  -profile test \
  --gmt_file examples/small_pathways.gmt \
  --adapter magma \
  --adapter_config examples/example_magma_config.json \
  --num_random_sets 10 \
  --outdir test_results
```

## Real Data

For actual analysis, use:
- **MSigDB**: http://www.gsea-msigdb.org/
- **GO**: http://geneontology.org/
- **KEGG**: https://www.genome.jp/kegg/
- **Reactome**: https://reactome.org/

Download in GMT format.
