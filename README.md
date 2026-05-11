# Vibrio vulnificus cgMLST Schema (2705 loci)

## Description
A core genome MLST (cgMLST) schema for Vibrio vulnificus containing 2705 loci,
developed using chewBBACA.

## Schema Download
Schema seed (~2 GB) is available on Zenodo: [DOI link]

## Requirements
- chewBBACA >= 3.5.3

## Usage
```bash
# Allele calling
chewBBACA.py AlleleCall \
  -i ./your_genomes/ \
  -g schema_seed/ \
  -o allele_results \
  --cpu 8

# Extract cgMLST at 95% completeness
chewBBACA.py ExtractCgMLST \
  -i allele_results/results_alleles.tsv \
  -o cgMLST_output \
  --t 0.95 --s 100
```

## Citation

