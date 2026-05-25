#!/bin/bash
# RNA-seq mapping pipeline using STAR
# This script is designed to run after 'preprocess.sh'
# It automatically reads the paired-end outputs (_1P.fastq.gz, _2P.fastq.gz) from Trimmomatic.

# 默认参数
TRIM_DIR=""
OUTPUT_DIR=""
INDEX_DIR=""
GTF_FILE=""
SAMPLELIST=""
THREADS=10
OVERHANG=149

usage() {
    echo "========================================================================="
    echo "Usage: bash $0 -d <trimmomatic_dir> -o <output_dir> -x <star_index> -g <gtf> -s <samplelist> [options]"
    echo ""
    echo "Required Arguments:"
    echo "  -d  Directory containing Trimmomatic results (output from preprocess.sh)."
    echo "  -o  Output directory for STAR mapping results."
    echo "  -x  Path to the STAR genome index directory."
    echo "  -g  Path to the reference GTF file."
    echo "  -s  Sample list file (Tab-separated: SampleName, Group, Read1, Read2)."
    echo ""
    echo "Optional Arguments:"
    echo "  -t  Number of threads to use (Default: 10)."
    echo "  -r  --sjdbOverhang value (Default: 149. Usually read_length - 1)."
    echo "  -h  Show this help message and exit."
    echo "========================================================================="
    exit 1
}

if [ $# -eq 0 ]; then
    usage
fi

while getopts "d:o:x:g:s:t:r:h" opt; do
    case $opt in
        d) TRIM_DIR="$OPTARG" ;;
        o) OUTPUT_DIR="$OPTARG" ;;
        x) INDEX_DIR="$OPTARG" ;;
        g) GTF_FILE="$OPTARG" ;;
        s) SAMPLELIST="$OPTARG" ;;
        t) THREADS="$OPTARG" ;;
        r) OVERHANG="$OPTARG" ;;
        h) usage ;;
        \?) echo "Invalid option: -$OPTARG" >&2; usage ;;
        :)  echo "Option -$OPTARG requires an argument." >&2; usage ;;
    esac
done

# ---------------------------------------------------------
# environment check
# ---------------------------------------------------------

if [ -z "$TRIM_DIR" ] || [ -z "$OUTPUT_DIR" ] || [ -z "$INDEX_DIR" ] || [ -z "$GTF_FILE" ] || [ -z "$SAMPLELIST" ]; then
    echo "Error: Missing required arguments."
    usage
fi

if ! command -v STAR &> /dev/null; then
    echo "Error: STAR is not found in PATH. Please install it or load the module."
    exit 1
fi

if [ ! -d "$INDEX_DIR" ]; then
    echo "Error: STAR index directory not found at $INDEX_DIR."
    exit 1
fi

if [ ! -f "$GTF_FILE" ]; then
    echo "Error: GTF file not found at $GTF_FILE."
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

echo "========================================="
echo "Starting STAR Mapping Pipeline..."
echo "Trimmomatic Dir : $TRIM_DIR"
echo "Output Dir      : $OUTPUT_DIR"
echo "STAR Index      : $INDEX_DIR"
echo "GTF File        : $GTF_FILE"
echo "sjdbOverhang    : $OVERHANG"
echo "Threads         : $THREADS"
echo "========================================="

# ---------------------------------------------------------
# Mapping
# ---------------------------------------------------------

# 按行读取 samplelist，只提取第一列的 sample_name
while IFS=$'\t' read -r sample_name group fastq_files; do
    if [[ -z "$sample_name" ]]; then continue; fi

    # 精准拼接在 preprocess.sh 中由 Trimmomatic 生成的配对文件路径
    fq1="${TRIM_DIR}/${sample_name}_trim_1P.fastq.gz"
    fq2="${TRIM_DIR}/${sample_name}_trim_2P.fastq.gz"

    if [ ! -f "$fq1" ] || [ ! -f "$fq2" ]; then
        echo "Warning: Cannot find cleaned paired reads for $sample_name in $TRIM_DIR. Skipping..."
        continue
    fi

    echo "-----------------------------------------"
    echo "Mapping Sample: $sample_name"
    
    SAMPLE_OUT_DIR="${OUTPUT_DIR}/${sample_name}"
    mkdir -p "$SAMPLE_OUT_DIR"
    
    # STAR output prefix star_out/ko1/ko1_
    OUT_PREFIX="${SAMPLE_OUT_DIR}/${sample_name}_"

    STAR --runMode alignReads \
         --runThreadN "$THREADS" \
         --genomeDir "$INDEX_DIR" \
         --twopassMode Basic \
         --readFilesCommand gunzip -c \
         --readFilesIn "$fq1" "$fq2" \
         --outFileNamePrefix "$OUT_PREFIX" \
         --sjdbGTFfile "$GTF_FILE" \
         --sjdbOverhang "$OVERHANG" \
         --outSAMunmapped None \
         --outSAMtype BAM SortedByCoordinate \
         --quantMode GeneCounts \
         --outFilterType BySJout

    echo "Finished mapping for $sample_name."

done < "$SAMPLELIST"

echo "========================================="
echo "STAR mapping successfully completed."
echo "Results are stored in: $OUTPUT_DIR"
echo "========================================="
