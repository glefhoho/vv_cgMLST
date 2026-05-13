#!/bin/bash
# =============================================================================
# Vibrio vulnificus cgMLST Typing Pipeline
# Schema: 2705 loci (95% completeness threshold)
# Requires: chewBBACA >= 3.5.3, datasets (NCBI), unzip
# Usage: bash vv_cgMLST_pipeline.sh GCA_XXXXXXXXX.X [--cpu 8]
# =============================================================================

set -euo pipefail

# ---------- default parameters ----------
CPU=8
SCHEMA_DIR="./schema_seed"
THRESHOLD=0.95
MIN_SHARED=100

# ---------- help message ----------
usage() {
    echo ""
    echo "Usage: bash vv_cgMLST_pipeline.sh <GCA_accession> [--cpu N] [--schema PATH]"
    echo ""
    echo "  GCA_accession   NCBI accession number (e.g. GCA_000123456.1)"
    echo "  --cpu N         Number of CPUs to use (default: 8)"
    echo "  --schema PATH   Path to schema_seed directory (default: ./schema_seed)"
    echo ""
    echo "Example:"
    echo "  bash vv_cgMLST_pipeline.sh GCA_000123456.1 --cpu 16"
    echo ""
    exit 1
}

# ---------- parse arguments ----------
if [ $# -lt 1 ]; then
    usage
fi

GCA=$1
shift

while [[ $# -gt 0 ]]; do
    case "$1" in
        --cpu) CPU=$2; shift 2 ;;
        --schema) SCHEMA_DIR=$2; shift 2 ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

# ---------- check dependencies ----------
echo "[1/5] Checking dependencies..."

for cmd in chewBBACA.py datasets unzip; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "ERROR: '$cmd' not found. Please install it first."
        echo "  chewBBACA:  pip install chewbbaca"
        echo "  datasets:   https://www.ncbi.nlm.nih.gov/datasets/docs/v2/download-and-install/"
        exit 1
    fi
done

# ---------- check schema ----------
if [ ! -d "$SCHEMA_DIR" ]; then
    echo "ERROR: Schema not found at '$SCHEMA_DIR'"
    echo "  Please download schema_seed from Zenodo and place it here."
    exit 1
fi

echo "  All dependencies found."
echo "  Schema: $SCHEMA_DIR"
echo "  CPUs: $CPU"

# ---------- set output directories ----------
OUTDIR="${GCA}_cgMLST_results"
FASTA_DIR="${OUTDIR}/genome"
ALLELE_DIR="${OUTDIR}/allele_call"
CGMLST_DIR="${OUTDIR}/cgMLST"

mkdir -p "$FASTA_DIR"

# ---------- download genome ----------
echo ""
echo "[2/5] Downloading genome: $GCA ..."

datasets download genome accession "$GCA" \
    --include genome \
    --filename "${OUTDIR}/${GCA}.zip"

unzip -o "${OUTDIR}/${GCA}.zip" -d "${OUTDIR}/ncbi_download" > /dev/null

# move fasta files to fasta dir
find "${OUTDIR}/ncbi_download" -name "*.fna" -exec cp {} "$FASTA_DIR/" \;

FASTA_COUNT=$(ls "$FASTA_DIR"/*.fna 2>/dev/null | wc -l)
if [ "$FASTA_COUNT" -eq 0 ]; then
    echo "ERROR: No FASTA files found after download. Check your GCA accession."
    exit 1
fi

echo "  Downloaded $FASTA_COUNT genome(s) to $FASTA_DIR"

# ---------- allele calling ----------
echo ""
echo "[3/5] Running allele calling with chewBBACA..."

chewBBACA.py AlleleCall \
    -i "$FASTA_DIR" \
    -g "$SCHEMA_DIR" \
    -o "$ALLELE_DIR" \
    --cpu "$CPU"

echo "  Allele calling complete."

# ---------- extract cgMLST ----------
echo ""
echo "[4/5] Extracting cgMLST profiles (threshold: $THRESHOLD)..."

chewBBACA.py ExtractCgMLST \
    -i "${ALLELE_DIR}/results_alleles.tsv" \
    -o "$CGMLST_DIR" \
    --t "$THRESHOLD" \
    --s "$MIN_SHARED"

echo "  cgMLST extraction complete."

# ---------- summary ----------
echo ""
echo "[5/5] Summary"
echo "============================================"
echo "  Input accession : $GCA"
echo "  Schema loci     : 2705"
echo "  Threshold       : $THRESHOLD (95%)"
echo ""

LOCI_COUNT=$(head -n 1 "${CGMLST_DIR}/cgMLST95.tsv" 2>/dev/null | tr '\t' '\n' | wc -l)
SAMPLE_COUNT=$(tail -n +2 "${CGMLST_DIR}/cgMLST95.tsv" 2>/dev/null | wc -l)

echo "  Loci in output  : $LOCI_COUNT"
echo "  Samples passed  : $SAMPLE_COUNT"
echo ""
echo "  Output files:"
echo "    $CGMLST_DIR/cgMLST95.tsv        <- cgMLST profiles"
echo "    $CGMLST_DIR/missing_loci_stats.tsv <- missing loci per genome"
echo "    $CGMLST_DIR/presence_absence.tsv   <- loci presence/absence"
echo "    $CGMLST_DIR/cgMLST.html            <- interactive visualization"
echo ""
echo "  All results saved to: $OUTDIR/"
echo "============================================"
echo "Done!"
