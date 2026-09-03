#!/usr/bin/env bash
# =============================================================================
#  Vibrio vulnificus cgMLST typing pipeline
#  Version : 3.0
#  Scheme  : 2,705 core loci (95% presence across 2,900 V. vulnificus genomes)
#  License : MIT
#  Repo    : https://github.com/glefhoho/vv_cgMLST
#
#  Two input modes:
#    (a) local assembly  --fasta my_isolate.fna        (no NCBI tools needed)
#    (b) NCBI accession  GCA_000039765.1               (requires `datasets`)
#
#  Allele calling is restricted to the 2,705 cgMLST loci via chewBBACA's
#  --gl mechanism, so profiles are directly comparable to the published
#  2,900-genome matrix. The schema is never modified (--no-inferred).
# =============================================================================

set -euo pipefail

VERSION="3.0"

# ---------- defaults -------------------------------------------------------
CPU=8
SCHEMA_DIR="./schema_seed"
LOCI_LIST="./cgMLSTschema95.txt"
EXPECTED_LOCI=2705
FASTA_IN=""
GCA=""
OUTDIR=""
SAMPLE_NAME=""

# ---------- help -----------------------------------------------------------
usage() {
    cat <<EOF

vv_cgMLST_pipeline.sh v${VERSION}
Vibrio vulnificus cgMLST typing against a 2,705-locus core scheme.

USAGE
  Local assembly (one file, or a directory of assemblies):
    bash vv_cgMLST_pipeline.sh --fasta isolate.fna
    bash vv_cgMLST_pipeline.sh --fasta my_assemblies/ --cpu 16

  NCBI genome by accession:
    bash vv_cgMLST_pipeline.sh GCA_000039765.1 --cpu 16

OPTIONS
  --fasta PATH    Assembly file (.fna/.fa/.fasta, optionally .gz) or a
                  directory containing them. Mutually exclusive with an
                  accession argument.
  --cpu N         CPUs for allele calling            [${CPU}]
  --schema PATH   chewBBACA schema directory         [${SCHEMA_DIR}]
  --loci PATH     cgMLST locus list (2,705 entries)  [${LOCI_LIST}]
  --out PATH      Output directory                   [<sample>_cgMLST]
  --name STR      Sample name for the output profile [derived from input]
  -h, --help      Show this message
  -V, --version   Print version and exit

OUTPUT
  <out>/cgmlst_profile.tsv     allele profile over the 2,705 loci
  <out>/typing_summary.tsv     per-genome loci called / detection rate
  <out>/allele_call/           full chewBBACA AlleleCall output

REQUIREMENTS
  chewBBACA >= 3.5.3           (both modes)
  ncbi-datasets-cli, unzip     (accession mode only)

EOF
    exit "${1:-1}"
}

# ---------- argument parsing ----------------------------------------------
[ $# -eq 0 ] && usage 1

while [[ $# -gt 0 ]]; do
    case "$1" in
        --fasta)    FASTA_IN="$2";    shift 2 ;;
        --cpu)      CPU="$2";         shift 2 ;;
        --schema)   SCHEMA_DIR="$2";  shift 2 ;;
        --loci)     LOCI_LIST="$2";   shift 2 ;;
        --out)      OUTDIR="$2";      shift 2 ;;
        --name)     SAMPLE_NAME="$2"; shift 2 ;;
        -h|--help)  usage 0 ;;
        -V|--version) echo "vv_cgMLST_pipeline.sh v${VERSION}"; exit 0 ;;
        -*)         echo "ERROR: unknown option '$1'" >&2; usage 1 ;;
        *)
            if [ -n "$GCA" ]; then
                echo "ERROR: more than one accession given ('$GCA', '$1')." >&2
                exit 1
            fi
            GCA="$1"; shift ;;
    esac
done

# exactly one input mode
if [ -n "$FASTA_IN" ] && [ -n "$GCA" ]; then
    echo "ERROR: use either --fasta or an accession, not both." >&2
    exit 1
fi
if [ -z "$FASTA_IN" ] && [ -z "$GCA" ]; then
    echo "ERROR: no input given. Provide --fasta PATH or a GCA/GCF accession." >&2
    usage 1
fi

MODE="local"; [ -n "$GCA" ] && MODE="accession"

# ---------- [1/4] dependency and input checks ------------------------------
echo "[1/4] Checking dependencies and inputs (mode: ${MODE})..."

need() {
    command -v "$1" &> /dev/null || {
        echo "ERROR: required command '$1' not found." >&2
        [ "$1" = "chewBBACA.py" ] && echo "  install: pip install chewbbaca" >&2
        [ "$1" = "datasets" ] && echo "  install: conda install -c conda-forge ncbi-datasets-cli" >&2
        exit 1
    }
}

need chewBBACA.py
if [ "$MODE" = "accession" ]; then
    need datasets
    need unzip
fi

[ -d "$SCHEMA_DIR" ] || { echo "ERROR: schema directory not found: '$SCHEMA_DIR'" >&2; exit 1; }
[ -f "$SCHEMA_DIR/.schema_config" ] || {
    echo "ERROR: '$SCHEMA_DIR' is not a chewBBACA schema (.schema_config missing)." >&2
    echo "  Download schema_seed.zip from https://doi.org/10.5281/zenodo.20128405 and unzip it." >&2
    exit 1
}
[ -d "$SCHEMA_DIR/short" ] || {
    echo "ERROR: '$SCHEMA_DIR/short' missing — the schema is incomplete." >&2
    exit 1
}
[ -f "$LOCI_LIST" ] || { echo "ERROR: locus list not found: '$LOCI_LIST'" >&2; exit 1; }

N_LOCI=$(grep -cve '^[[:space:]]*$' "$LOCI_LIST")
if [ "$N_LOCI" -ne "$EXPECTED_LOCI" ]; then
    echo "  WARNING: locus list has ${N_LOCI} entries, expected ${EXPECTED_LOCI}."
fi

echo "  schema : ${SCHEMA_DIR}"
echo "  loci   : ${LOCI_LIST} (${N_LOCI} loci)"
echo "  CPUs   : ${CPU}"

# ---------- resolve output location ---------------------------------------
if [ -z "$SAMPLE_NAME" ]; then
    if [ "$MODE" = "accession" ]; then
        SAMPLE_NAME="$GCA"
    elif [ -d "$FASTA_IN" ]; then
        SAMPLE_NAME="$(basename "${FASTA_IN%/}")"
    else
        SAMPLE_NAME="$(basename "$FASTA_IN")"
        SAMPLE_NAME="${SAMPLE_NAME%.gz}"
        SAMPLE_NAME="${SAMPLE_NAME%.*}"
    fi
fi
[ -z "$OUTDIR" ] && OUTDIR="${SAMPLE_NAME}_cgMLST"

GENOME_DIR="${OUTDIR}/genome"
ALLELE_DIR="${OUTDIR}/allele_call"
mkdir -p "$GENOME_DIR"

# ---------- [2/4] assemble the input set ----------------------------------
echo ""
echo "[2/4] Preparing input genome(s)..."

# copy one assembly into GENOME_DIR, decompressing and normalising extension
stage_one() {
    local src="$1" stem
    stem="$(basename "$src")"
    case "$stem" in
        *.gz) stem="${stem%.gz}" ;;
    esac
    stem="${stem%.*}"
    case "$src" in
        *.gz) gunzip -c "$src" > "${GENOME_DIR}/${stem}.fasta" ;;
        *)    cp "$src" "${GENOME_DIR}/${stem}.fasta" ;;
    esac
}

if [ "$MODE" = "accession" ]; then
    echo "  Downloading ${GCA} from NCBI..."
    datasets download genome accession "$GCA" \
        --include genome \
        --filename "${OUTDIR}/${GCA}.zip"
    unzip -oq "${OUTDIR}/${GCA}.zip" -d "${OUTDIR}/ncbi_download"

    n=0
    while IFS= read -r f; do
        cp "$f" "${GENOME_DIR}/${GCA}.fasta"
        n=$((n + 1))
    done < <(find "${OUTDIR}/ncbi_download" -name '*.fna' -type f)

    if [ "$n" -eq 0 ]; then
        echo "ERROR: no FASTA found after download. Check the accession '${GCA}'." >&2
        exit 1
    fi
else
    if [ -d "$FASTA_IN" ]; then
        while IFS= read -r f; do
            stage_one "$f"
        done < <(find "$FASTA_IN" -maxdepth 1 -type f \
                   \( -name '*.fna' -o -name '*.fa' -o -name '*.fasta' \
                      -o -name '*.fna.gz' -o -name '*.fa.gz' -o -name '*.fasta.gz' \))
    elif [ -f "$FASTA_IN" ]; then
        stage_one "$FASTA_IN"
    else
        echo "ERROR: --fasta path not found: '${FASTA_IN}'" >&2
        exit 1
    fi
fi

GENOME_COUNT=$(find "$GENOME_DIR" -name '*.fasta' -type f | wc -l)
if [ "$GENOME_COUNT" -eq 0 ]; then
    echo "ERROR: no usable assemblies found in '${FASTA_IN:-$GCA}'." >&2
    echo "  Accepted extensions: .fna .fa .fasta (optionally .gz)" >&2
    exit 1
fi

# reject obviously non-FASTA input early
for f in "$GENOME_DIR"/*.fasta; do
    head -c 1 "$f" | grep -q '>' || {
        echo "ERROR: '$(basename "$f")' does not start with '>' — not a FASTA file." >&2
        exit 1
    }
done
echo "  ${GENOME_COUNT} assembly/assemblies ready."

# ---------- [3/4] allele calling ------------------------------------------
echo ""
echo "[3/4] Allele calling against ${N_LOCI} cgMLST loci..."

chewBBACA.py AlleleCall \
    -i "$GENOME_DIR" \
    -g "$SCHEMA_DIR" \
    --gl "$LOCI_LIST" \
    -o "$ALLELE_DIR" \
    --cpu "$CPU" \
    --no-inferred

PROFILE="${ALLELE_DIR}/results_alleles.tsv"
[ -f "$PROFILE" ] || { echo "ERROR: allele calling produced no results_alleles.tsv" >&2; exit 1; }

cp "$PROFILE" "${OUTDIR}/cgmlst_profile.tsv"

# ---------- [4/4] summary --------------------------------------------------
echo ""
echo "[4/4] Typing summary"
echo "======================================================================"

awk -F'\t' -v total="$N_LOCI" '
BEGIN { print "sample\tloci_called\tloci_total\tdetection_pct" }
NR == 1 { next }
{
    called = 0
    for (i = 2; i <= NF; i++) {
        v = $i
        sub(/^INF-/, "", v)
        if (v ~ /^[0-9]+$/) called++
    }
    printf "%s\t%d\t%d\t%.2f\n", $1, called, total, 100 * called / total
}' "$PROFILE" > "${OUTDIR}/typing_summary.tsv"

column -t -s "$(printf '\t')" "${OUTDIR}/typing_summary.tsv" | sed 's/^/  /'

if [ -f "${ALLELE_DIR}/results_statistics.tsv" ]; then
    echo ""
    echo "  chewBBACA per-class counts:"
    column -t -s "$(printf '\t')" "${ALLELE_DIR}/results_statistics.tsv" | sed 's/^/    /'
fi

cat <<EOF

  Profile : ${OUTDIR}/cgmlst_profile.tsv
  Summary : ${OUTDIR}/typing_summary.tsv
  Details : ${ALLELE_DIR}/

  Interpretation: a V. vulnificus assembly of good quality typically calls
  >97% of the 2,705 loci. Substantially lower values usually indicate a
  fragmented assembly, contamination, or a non-target species.
======================================================================
EOF
echo "Done."
