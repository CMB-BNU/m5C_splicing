#!/bin/bash
# Automatically generates experiments.tsv, builds the splicegraph, 
# and calculates PSI values for each group independently.

# default parameter
STAR_DIR=""
OUTPUT_DIR="./majiq_out"
GFF3_FILE=""
SAMPLELIST=""
THREADS=20

usage() {
    echo "========================================================================="
    echo "Usage: bash $0 -d <star_dir> -g <gff3> -s <samplelist> [options]"
    echo ""
    echo "Required Arguments:"
    echo "  -d  Directory containing STAR mapping results."
    echo "  -g  Path to the reference GFF3 file."
    echo "  -s  Sample list file (Tab-separated: SampleName, Group, Read1, Read2)."
    echo ""
    echo "Optional Arguments:"
    echo "  -o  Output directory for MAJIQ results (Default: ./majiq_out)."
    echo "  -t  Number of threads to use (Default: 20)."
    echo "  -h  Show this help message and exit."
    echo "========================================================================="
    exit 1
}

if [ $# -eq 0 ]; then
    usage
fi

while getopts "d:g:s:o:t:h" opt; do
    case $opt in
        d) STAR_DIR="$OPTARG" ;;
        g) GFF3_FILE="$OPTARG" ;;
        s) SAMPLELIST="$OPTARG" ;;
        o) OUTPUT_DIR="$OPTARG" ;;
        t) THREADS="$OPTARG" ;;
        h) usage ;;
        \?) echo "Invalid option: -$OPTARG" >&2; usage ;;
        :)  echo "Option -$OPTARG requires an argument." >&2; usage ;;
    esac
done

# ---------------------------------------------------------
# 1. environment check
# ---------------------------------------------------------
if [ -z "$STAR_DIR" ] || [ -z "$GFF3_FILE" ] || [ -z "$SAMPLELIST" ]; then
    echo "Error: Missing required arguments."
    usage
fi

if ! command -v majiq &> /dev/null; then
    echo "Error: MAJIQ is not found in PATH."
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

echo "========================================="
echo "Starting MAJIQ Pipeline (Build -> PSI-Coverage -> PSI)"
echo "STAR Dir     : $STAR_DIR"
echo "Output Dir   : $OUTPUT_DIR"
echo "Threads      : $THREADS"
echo "========================================="

# ---------------------------------------------------------
# 2. generate experiments.tsv
# ---------------------------------------------------------
TSV_FILE="${OUTPUT_DIR}/experiments.tsv"
echo "Generating MAJIQ config: $TSV_FILE..."
echo -e "group\tpath" > "$TSV_FILE"

VALID_BAM_COUNT=0

while IFS=$'\t' read -r sample_name group fastq_files; do
    if [[ -z "$sample_name" ]]; then continue; fi

    BAM_PATH="${STAR_DIR}/${sample_name}/${sample_name}_Aligned.sortedByCoord.out.bam"
    
    if [ ! -f "$BAM_PATH" ]; then
        echo "Warning: BAM file not found for sample $sample_name. Skipping..."
        continue
    fi

    ABS_BAM_PATH=$(readlink -f "$BAM_PATH")
    echo -e "${group}\t${ABS_BAM_PATH}" >> "$TSV_FILE"
    VALID_BAM_COUNT=$((VALID_BAM_COUNT+1))
done < "$SAMPLELIST"

if [ "$VALID_BAM_COUNT" -eq 0 ]; then
    echo "Error: No valid BAM files were found. Aborting."
    exit 1
fi

# ---------------------------------------------------------
# 3. 运行 MAJIQ Build
# ---------------------------------------------------------
echo "-----------------------------------------"
echo "[Step 1/3] Running MAJIQ Build..."
majiq build -j "$THREADS" "$GFF3_FILE" "$TSV_FILE" "$OUTPUT_DIR"

if [ $? -ne 0 ]; then
    echo "Error: MAJIQ build failed. Check logs."
    exit 1
fi

# ---------------------------------------------------------
# 4. extract samples from group and run PSI-Coverage & PSI
# ---------------------------------------------------------
SPLICEGRAPH="${OUTPUT_DIR}/splicegraph.zarr"

if [ ! -f "$SPLICEGRAPH" ]; then
    echo "Error: Splicegraph not found at $SPLICEGRAPH. Build may have failed."
    exit 1
fi

# awk extract the group name
GROUPS=$(awk -F'\t' '{if(NR>0 && $2!="") print $2}' "$SAMPLELIST" | sort | uniq)

echo "-----------------------------------------"
echo "Detected experimental groups: $GROUPS"

for current_group in $GROUPS; do
    echo ">>> Processing Group: $current_group <<<"
    
    # extract all the sample name from the group
    GROUP_SAMPLES=$(awk -F'\t' -v g="$current_group" '$2==g {print $1}' "$SAMPLELIST")
    
    # find all .sj files
    SJ_FILES_ARRAY=()
    for s in $GROUP_SAMPLES; do
        # find the correct prefix .sj file
        for sj in "${OUTPUT_DIR}/${s}"*.sj; do
            if [ -f "$sj" ]; then
                SJ_FILES_ARRAY+=("$sj")
            fi
        done
    done
    
    if [ ${#SJ_FILES_ARRAY[@]} -eq 0 ]; then
        echo "Warning: No .sj files found for group $current_group. Skipping..."
        continue
    fi

    PSICOV_OUT="${OUTPUT_DIR}/${current_group}.psicov"
    PSI_TSV_OUT="${OUTPUT_DIR}/${current_group}_psi.tsv"

    # run psi-coverage
    echo "[Step 2/3] Running MAJIQ psi-coverage for ${current_group}..."
    majiq psi-coverage -j "$THREADS" \
        --minreads 1 --minbins 1 \
        "$SPLICEGRAPH" \
        "$PSICOV_OUT" \
        "${SJ_FILES_ARRAY[@]}"

    if [ $? -ne 0 ] || [ ! -f "$PSICOV_OUT" ]; then
        echo "Error: psi-coverage failed for group $current_group."
        continue
    fi

    # run majiq psi
    echo "[Step 3/3] Running MAJIQ psi for ${current_group}..."
    majiq psi -j "$THREADS" \
        --min-experiments 1 \
        --splicegraph "$SPLICEGRAPH" \
        --output-tsv "$PSI_TSV_OUT" \
        "$PSICOV_OUT"

    echo "Finished processing group $current_group."
    echo "-----------------------------------------"
done

echo "========================================="
echo "Pipeline successfully completed!"
echo "All PSI TSV files are stored in: $OUTPUT_DIR"
echo "========================================="
