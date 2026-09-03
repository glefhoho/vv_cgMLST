# vv_cgMLST — a core-genome MLST scheme for *Vibrio vulnificus*

A 2,705-locus cgMLST scheme derived from 2,900 publicly available *Vibrio vulnificus*
genomes, plus a single-command pipeline for typing new isolates against it.

[![Schema DOI](https://img.shields.io/badge/Zenodo-10.5281%2Fzenodo.20128405-blue)](https://doi.org/10.5281/zenodo.20128405)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## What this is

*V. vulnificus* has no widely adopted public cgMLST scheme. This repository provides one,
together with the tooling to apply it, so that allele profiles generated in different
laboratories are directly comparable.

| | |
|---|---|
| Core loci | **2,705** |
| Presence threshold | 95% of input genomes |
| Genomes used to define the core | 2,900 |
| Seed schema (all loci) | 55,034 |
| Allele caller | chewBBACA ≥ 3.5.3 |

The scheme is distributed as two pieces: the **seed schema** (all 55,034 loci, hosted on
Zenodo because of its size) and the **core locus list** (`cgMLSTschema95.txt`, in this
repository). Allele calling is restricted to the 2,705 core loci at runtime via chewBBACA's
`--gl` option, which is the mechanism chewBBACA provides for exactly this purpose.

---

## Installation

### 1. Dependencies

```bash
conda create -n chewBBACA -c bioconda -c conda-forge chewbbaca'>=3.5.3'
conda activate chewBBACA

# only needed if you want to type genomes by NCBI accession
conda install -c conda-forge ncbi-datasets-cli
```

### 2. This repository

```bash
git clone https://github.com/glefhoho/vv_cgMLST.git
cd vv_cgMLST
```

### 3. The schema

```bash
wget 'https://zenodo.org/records/20128405/files/schema_seed.zip?download=1' -O schema_seed.zip
unzip schema_seed.zip          # creates ./schema_seed/
```

Sanity check — the schema directory must contain the hidden `.schema_config` file and a
`short/` subdirectory:

```bash
ls -a schema_seed | head
find schema_seed -maxdepth 1 -name '*.fasta' | wc -l
wc -l cgMLSTschema95.txt        # 2705
```

---

## Usage

### Typing your own assembly

No NCBI tools required.

```bash
bash vv_cgMLST_pipeline.sh --fasta my_isolate.fna --cpu 16
```

A directory of assemblies works too — `.fna`, `.fa`, `.fasta`, optionally gzipped:

```bash
bash vv_cgMLST_pipeline.sh --fasta my_assemblies/ --cpu 16
```

### Typing a genome from NCBI

```bash
bash vv_cgMLST_pipeline.sh GCA_000039765.1 --cpu 16
```

### Options

```
--fasta PATH    assembly file or directory (mutually exclusive with an accession)
--cpu N         CPUs for allele calling                        [8]
--schema PATH   chewBBACA schema directory                     [./schema_seed]
--loci PATH     cgMLST locus list                              [./cgMLSTschema95.txt]
--out PATH      output directory                               [<sample>_cgMLST]
--name STR      sample name for the profile                    [derived from input]
```

### Runtime

A single genome against the 2,705 core loci takes a few minutes on 8 CPUs. Calling against
the full 55,034-locus seed schema (i.e. omitting `--gl`) takes roughly an hour per genome
and produces profiles that are **not** comparable to the published matrix — the pipeline
always restricts to the core list.

---

## Output

```
<sample>_cgMLST/
├── cgmlst_profile.tsv     allele profile across the 2,705 core loci
├── typing_summary.tsv     loci called and detection rate per genome
├── genome/                the assembly as submitted to chewBBACA
└── allele_call/           full chewBBACA AlleleCall output
    ├── results_alleles.tsv
    ├── results_statistics.tsv     EXC / INF / LNF / PLOT / ASM / ALM counts
    └── ...
```

`cgmlst_profile.tsv` has one row per genome and 2,705 allele columns in the same order as
the published matrix, so it can be concatenated with the 2,900-genome profile table for
distance calculation or clustering.

### Interpreting the detection rate

A good-quality *V. vulnificus* assembly typically calls **> 97%** of the 2,705 loci.
Markedly lower values usually mean a fragmented assembly, contamination, or a non-target
species. Inspect `results_statistics.tsv` for the breakdown: a high **LNF** (locus not
found) count points to a different organism or a very incomplete assembly, while high
**ASM/ALM** (allele smaller/larger than mode) counts point to assembly artefacts.

The pipeline runs chewBBACA with `--no-inferred`, so novel alleles are reported as `INF-`
but **never written back into the schema**. Your local copy of the schema stays identical
to the published one, and results remain reproducible across users.

---

## How the scheme was built

Three chewBBACA v3.5.3 commands, on 2,900 *V. vulnificus* assemblies retrieved from NCBI:

```bash
# 1. build the seed schema from all genomes
chewBBACA.py CreateSchema -i fasta_file/ -o vv_cgMLST_schema --cpu 32
#    -> 55,034 loci

# 2. call alleles for all 2,900 genomes against the seed schema
chewBBACA.py AlleleCall -i fasta_file/ -g vv_cgMLST_schema/schema_seed \
                        -o vv_alleles --cpu 32

# 3. extract loci present in >= 95% of genomes
chewBBACA.py ExtractCgMLST -i vv_alleles/results_alleles.tsv \
                           -o vv_cgMLST_results --t 0.95 --s 100
#    -> 2,705 core loci, listed in cgMLSTschema95.txt
```

Step 3 also produced `presence_absence.tsv` (locus presence across all 2,900 genomes),
archived separately at [10.5281/zenodo.20127814](https://doi.org/10.5281/zenodo.20127814).

---

## Limitations

Stated plainly, so users can judge fitness for their purpose:

- **No assembly quality filtering** was applied to the 2,900 input genomes. Poor assemblies
  in the input set will have inflated the apparent locus loss and therefore made the 95%
  core slightly more conservative than it would otherwise be.
- **No Prodigal training file** was used; gene prediction relied on chewBBACA's defaults.
- **No paralog removal** beyond chewBBACA's built-in NIPH/NIPHEM flagging.
- **No SchemaEvaluator or AlleleCallEvaluator** run, so per-locus quality metrics
  (allele length variation, fragment rates) are not characterised.
- **Loci are not functionally annotated** — locus identifiers are protein IDs from the
  seed genome (GCA_000009745.1, strain YJ016) and carry no functional information.
- **No congruence analysis against 7-gene MLST** has been performed.
- **No external validation set**: the scheme has not been benchmarked on an independent
  genome collection, and no clustering thresholds (e.g. allele distances defining an
  outbreak cluster) are proposed. Users defining thresholds should validate them on their
  own epidemiologically characterised isolates.

Contributions addressing any of these are welcome — please open an issue first.

---

## Citation

If you use this scheme, please cite the Zenodo archive and chewBBACA:

> Li X. *A 2,705-locus core-genome MLST scheme for* Vibrio vulnificus. Zenodo.
> https://doi.org/10.5281/zenodo.20128405

> Silva M, Machado MP, Silva DN, et al. chewBBACA: A complete suite for gene-by-gene
> schema creation and strain identification. *Microb Genom.* 2018;4(3):e000166.
> https://doi.org/10.1099/mgen.0.000166

---

## License

MIT — see [LICENSE](LICENSE). The schema and derived data on Zenodo are released under
CC BY 4.0.
