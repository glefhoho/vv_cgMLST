# Vibrio vulnificus cgMLST Schema (2705 loci)

## Description
A core genome multilocus sequence typing (cgMLST) schema for Vibrio vulnificus 
containing 2705 loci, developed using chewBBACA. This schema enables standardized 
genomic epidemiology and outbreak investigation of V. vulnificus.

## Data Availability
Large files are hosted on Zenodo due to size constraints:

| File | Description | Size | Link |
|------|-------------|------|------|
| `schema_seed/` | chewBBACA schema seed | ~2 GB | [Zenodo DOI] |
| `presence_absence.tsv` | Loci presence/absence matrix | ~300 MB | DOI: 10.5281/zenodo.20127814 |

## Files in This Repository
| File | Description |
|------|-------------|
| `cgMLSTschema95.txt` | List of 2705 cgMLST loci (95% completeness threshold) |
| `missing_loci_stats.tsv` | Missing loci statistics per genome |
| `cgMLST.html` | Interactive visualization of cgMLST results |

## Schema Details
- Organism: Vibrio vulnificus
- Total cgMLST loci: 2705
- Completeness threshold: 95%
- Minimum genome coverage: 100 genomes
- Software: chewBBACA v3.5.3

## Requirements
- Python >= 3.7
- chewBBACA >= 3.0

Installation:
```bash
pip install chewbbaca
```

## Usage

### 1. Download schema from Zenodo
```bash
# Download and extract schema_seed from Zenodo link above
```

### 2. Allele calling
```bash
chewBBACA.py AlleleCall \
  -i ./your_genomes/ \
  -g schema_seed/ \
  -o allele_results \
  --cpu 8 # change based on your end
```

### 3. Extract cgMLST profiles
```bash
chewBBACA.py ExtractCgMLST \
  -i allele_results/results_alleles.tsv \
  -o cgMLST_output \
  --t 0.95 --s 100
```

## Citation
If you use this schema, please cite:


## License
MIT License — see [LICENSE](LICENSE) for details.
