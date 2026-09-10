# *Vibrio vulnificus* cgMLST Schema (2,705 loci)

A core genome multilocus sequence typing (cgMLST) schema for *Vibrio vulnificus*,
built with [chewBBACA](https://github.com/B-UMMI/chewBBACA) v3.5.3 from 2,900 publicly
available genome assemblies in the NCBI Pathogen Detection resource.

To our knowledge no curated, publicly available cgMLST scheme for *V. vulnificus*
exists in PubMLST or cgMLST.org; genotyping of the species has relied on the
ten-locus MLST scheme of Bisharat *et al.* (2007). This repository provides the
locus list, a typing script, and pointers to the archived schema so that the
scheme can be used, tested and improved by others.

---

## Schema at a glance

| | |
|---|---|
| Organism | *Vibrio vulnificus* |
| cgMLST loci | **2,705** |
| Locus presence threshold | 95% (`--t 0.95`) |
| Construction set | 2,900 draft assemblies, NCBI Pathogen Detection (January 2026) |
| Software | chewBBACA v3.5.3 (gene prediction by Pyrodigal, as used by chewBBACA ≥ 3.3.0) |
| Licence | MIT (code) · CC BY 4.0 (archived data) |

---

## Files

### In this repository

| File | Description |
|---|---|
| `cgMLSTschema95.txt` | The 2,705 cgMLST loci (95% presence threshold) |
| `vv_cgMLST_pipeline_v3.sh` | Typing pipeline — types a new assembly or NCBI accession against the scheme |
| `README.md` | This file |
| `LICENSE` | MIT |

### Archived on Zenodo (too large for GitHub)

| File | Description | Size | DOI |
|---|---|---|---|
| `schema_seed.zip` | chewBBACA schema seed — the representative allele sequence for every locus. **Required** to run the pipeline. Unzip before use. | 302 MB | [10.5281/zenodo.20128405](https://doi.org/10.5281/zenodo.20128405) |
| `presence_absence.tsv` | Locus presence/absence matrix across the 2,900-genome construction set | 321 MB | [10.5281/zenodo.20127814](https://doi.org/10.5281/zenodo.20127814) |

---

## Requirements

- Python ≥ 3.7
- chewBBACA ≥ 3.5.3

```bash
pip install chewbbaca
```

The pipeline additionally uses the NCBI `datasets` command-line tool when you pass
an assembly accession rather than a local file.

---

## Quick start

**1. Download and unzip the schema seed** from the Zenodo record above.

**2. Type a genome.** Either an NCBI assembly accession:

```bash
bash vv_cgMLST_pipeline_v3.sh GCA_000123456.1 --cpu 8
```

or a local assembly / directory of assemblies:

```bash
bash vv_cgMLST_pipeline_v3.sh ./my_assemblies/ --cpu 8
```

The script performs four steps:

1. **Validation** — checks that chewBBACA is installed and that the schema directory and locus list are present
2. **Input preparation** — stages the assembly, downloading and decompressing it from NCBI if an accession was supplied
3. **Allele calling** — restricted to the 2,705 cgMLST loci
4. **Summary** — detection statistics and formatted output tables

Set the schema path with the appropriate option if `schema_seed/` is not in the
working directory.

---

## What the pipeline runs

A single chewBBACA invocation is enough to obtain a cgMLST profile:

```bash
chewBBACA.py AlleleCall \
    -i "$GENOME_DIR" \
    -g "$SCHEMA_DIR" \
    --gl cgMLSTschema95.txt \
    -o "$ALLELE_DIR" \
    --cpu 8 \
    --no-inferred
```

Two flags do the important work:

- **`--gl cgMLSTschema95.txt`** restricts allele calling to the 2,705 core loci.
  The schema seed contains the full candidate (wgMLST) locus set, so this both
  speeds up the run and returns the cgMLST profile directly — `ExtractCgMLST` is
  **not** needed when typing against the published scheme. Column order matches the
  published 2,900-genome matrix, so profiles can be concatenated with it directly.

- **`--no-inferred`** stops chewBBACA from writing novel alleles back into the
  schema. Without it, every run mutates your local copy of the schema and the
  scheme drifts apart between laboratories. With it, the deposited seed stays
  byte-identical for everyone, so identifiers for alleles already in the seed are
  directly comparable across installations.

  Novel alleles are still detected and still receive an identifier in the local
  profile — they are simply not added to the schema. Those identifiers are assigned
  per run and are **not** comparable between laboratories. Only a shared nomenclature
  server (Chewie-NS, PubMLST/BIGSdb) can fix that; see *Limitations*.

---

## How the schema was built

The steps below are for reference and reproducibility. **You do not need to run them
to type genomes** — download the schema seed instead.

```bash
# 1. Candidate wgMLST schema from 2,900 assemblies
chewBBACA.py CreateSchema \
    -i vv_genomes/ \
    -o vv_cgMLST_schema \
    --cpu 8

# 2. Allele calling across the construction set
chewBBACA.py AlleleCall \
    -i vv_genomes/ \
    -g vv_cgMLST_schema/schema_seed/ \
    -o vv_alleles \
    --cpu 8

# 3. Extract the core locus set at a 95% presence threshold
chewBBACA.py ExtractCgMLST \
    -i vv_alleles/results_alleles.tsv \
    -o vv_cgMLST_results \
    --t 0.95 --s 100
```

Step 3 produced the 2,705 loci in `cgMLSTschema95.txt`.

> **On `--s 100`:** this is the *iteration step size* for the core-genome-size curve —
> how many profiles are added per iteration when ExtractCgMLST plots core genome size
> against the number of genomes considered. It does **not** set a minimum genome count
> and has no effect on which loci are retained. (An earlier version of this README
> described it incorrectly.)

---

## Limitations

The scheme was produced with the chewBBACA default workflow. These are stated so that
users know what they are getting:

- **No assembly quality filtering.** All 2,900 assemblies were used as retrieved from
  NCBI Pathogen Detection.
- **No paralog removal.** Loci flagged as paralogous were not excluded via
  `ExtractCgMLST --r`. This is partly self-correcting, since chewBBACA assigns no allele
  identifier to a paralogous hit (NIPH/NIPHEM) and such loci tend to fall below the 95%
  threshold on their own — but it has not been verified.
- **No species-specific training file.** Gene prediction used chewBBACA defaults
  (per-genome training) rather than a single `--ptf` training file. The chewBBACA
  documentation recommends supplying one; note that the training file would otherwise
  be bundled into the schema and reused during allele calling.
- **No formal schema evaluation.** `SchemaEvaluator` and `AlleleCallEvaluator` have not
  been run.
- **No locus annotation.** Loci carry chewBBACA identifiers only; no UniProt gene names
  or product descriptions.
- **No comparison with existing MLST**, and no discriminatory-power analysis
  (Simpson's index of diversity).
- **No external validation.** The loci were defined on the same 2,900 genomes, so call
  rates measured on that set are optimistic by construction.
- **No clustering threshold.** No allelic-distance cut-off for cluster or outbreak
  definition is proposed; cut-offs from other species should not be assumed to apply.

Contributions addressing any of these are welcome.

---

## Citation

If you use this schema, please cite:

<!-- TODO: replace with the bioRxiv DOI once the preprint is posted -->
> Zhan, Q., & Li, X. A publicly available core genome multilocus sequence typing scheme for
> *Vibrio vulnificus*. *bioRxiv* (2026). doi: TBD

and the underlying tool:

> Silva, M. *et al.* (2018). chewBBACA: A complete suite for gene-by-gene schema
> creation and strain identification. *Microbial Genomics* 4(3), e000166.
> doi:10.1099/mgen.0.000166

Please also cite the Zenodo DOI of whichever archived object you used.

---

## Licence

MIT — see [LICENSE](LICENSE). Archived data objects on Zenodo are released under
CC BY 4.0.
