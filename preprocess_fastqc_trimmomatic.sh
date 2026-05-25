#!/bin/bash
# RNA-seq preprocessing pipeline
# Performs quality control (FastQC) and adapter trimming (Trimmomatic)
# 
# Sample list format (Tab-separated):
# SampleName    GroupName    Read1.fastq.gz,Read2.fastq.gz

# 默认参数初始化
OUTPUT_DIR=""
THREADS=1
SAMPLELIST=""
WHERETRIM=""
ADAPTERS=""

# 帮助文档
usage() {
    echo "========================================================================="
    echo "Usage: bash $0 -o <output_dir> -s <samplelist> -a <adapters.fa> [options]"
    echo ""
    echo "Required Arguments:"
    echo "  -o  Output directory path."
    echo "  -s  Sample list file (Tab-separated: SampleName, Group, Read1,Read2)."
    echo "  -a  Path to the adapter Fasta file (e.g., TruSeq3-PE.fa)."
    echo ""
    echo "Optional Arguments:"
    echo "  -t  Number of threads to use (Default: 1)."
    echo "  -m  Path to trimmomatic.jar. (Optional if 'trimmomatic' is in PATH/Conda)."
    echo "  -h  Show this help message and exit."
    echo "========================================================================="
    exit 1
}

# 如果没有任何参数，显示帮助
if [ $# -eq 0 ]; then
    usage
fi

# 解析参数
while getopts "o:t:s:a:m:h" opt; do
	case $opt in
		o) OUTPUT_DIR="$OPTARG" ;;
		t) THREADS="$OPTARG" ;;
		s) SAMPLELIST="$OPTARG" ;;
		a) ADAPTERS="$OPTARG" ;;
		m) WHERETRIM="$OPTARG" ;;
        h) usage ;;
		\?) echo "Invalid option: -$OPTARG" >&2; usage ;;
		:)  echo "Option -$OPTARG requires an argument." >&2; usage ;;
	esac
done

# ---------------------------------------------------------
# Sanity Checks
# ---------------------------------------------------------

if [ -z "$OUTPUT_DIR" ] || [ -z "$SAMPLELIST" ] || [ -z "$ADAPTERS" ]; then
	echo "Error: Missing required arguments."
    usage
fi

if [ ! -f "$SAMPLELIST" ]; then
	echo "Error: Cannot find sample list file: $SAMPLELIST"
	exit 1
fi

if [ ! -f "$ADAPTERS" ]; then
	echo "Error: Cannot find adapter file: $ADAPTERS"
	exit 1
fi

# 智能识别 Trimmomatic (Conda 或者 Jar)
TRIM_CMD=""
if [ -n "$WHERETRIM" ]; then
    # 用户明确提供了 jar 包路径
    if [ ! -f "$WHERETRIM" ]; then
        echo "Error: Trimmomatic jar not found at $WHERETRIM"
        exit 1
    fi
    TRIM_CMD="java -jar $WHERETRIM"
elif command -v trimmomatic &> /dev/null; then
    # 用户没有提供 jar，但在环境变量(如 Conda)中找到了 trimmomatic
    TRIM_CMD="trimmomatic"
else
    echo "Error: Trimmomatic is not found in PATH and no jar path was provided (-m)."
    echo "Please either install Trimmomatic via Conda OR provide the jar path using '-m'."
    exit 1
fi

if ! command -v fastqc &> /dev/null; then
    echo "Error: FastQC is not found in PATH. Please install it or load the module."
    exit 1
fi

# ---------------------------------------------------------
# Pipeline Execution
# ---------------------------------------------------------

FC_OUTPUT_DIR="$OUTPUT_DIR/fastqc_result"
TRIM_DIR="$OUTPUT_DIR/trimmomatic_result"
mkdir -p "$FC_OUTPUT_DIR"
mkdir -p "$TRIM_DIR"

echo "========================================="
echo "Starting Preprocessing Pipeline..."
echo "Sample List  : $SAMPLELIST"
echo "Output Dir   : $OUTPUT_DIR"
echo "Threads      : $THREADS"
echo "Adapter File : $ADAPTERS"
echo "Trim Command : $TRIM_CMD"
echo "========================================="

while IFS=$'\t' read -r sample_name group fastq_files; do
	if [[ -z "$sample_name" ]]; then continue; fi

	read1=$(echo "$fastq_files" | cut -d',' -f1)
	read2=$(echo "$fastq_files" | cut -d',' -f2)

	if [ ! -f "$read1" ] || [ ! -f "$read2" ]; then
		echo "Warning: Cannot find $read1 or $read2 for sample $sample_name. Skipping..."
		continue
	fi

	echo "-----------------------------------------"
	echo "Processing Sample: $sample_name (Group: $group)"
	
	echo "[1/2] Running FastQC..."
	fastqc -o "$FC_OUTPUT_DIR" -t "$THREADS" "$read1" "$read2"
	
	echo "[2/2] Running Trimmomatic..."
	TRIM_BASEOUT="$TRIM_DIR/${sample_name}_trim.fastq.gz"
	
	$TRIM_CMD PE -threads "$THREADS" \
		"$read1" "$read2" \
		-baseout "$TRIM_BASEOUT" \
		ILLUMINACLIP:"$ADAPTERS":2:30:10 \
		SLIDINGWINDOW:4:15 LEADING:3 TRAILING:3 MINLEN:36 
		
	echo "Sample $sample_name finished."

done < "$SAMPLELIST"

echo "========================================="
echo "Preprocessing successfully completed."
echo "Results are stored in: $OUTPUT_DIR"
echo "========================================="
