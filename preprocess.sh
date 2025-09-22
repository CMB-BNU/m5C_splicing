#!/bin/bash
#preprocessing 
#We expect your source directory be like: /path/to/sample_name , you should provide a sample list at the same time

OUTPUT_DIR=""
THREADS=1
ZIP=false
SAMPLELIST=""
WHERETRIM=${WHERETRIM:-"$HOME/soft/Trimmomatic-0.39/trimmomatic-0.39.jar"}

while getopts "o:t:s:z" opt; do
	case $opt in
		o)
			OUTPUT_DIR="$OPTARG"
			;;
		t)
			THREADS="$OPTARG"
			;;
		s)
			SAMPLELIST="$OPTARG"
			;;
		z)
			ZIP=true
			;;
		\?)
			echo "useless command: -$OPTARG" >&2
			exit 1
			;;
		:)
			echo "need command -$OPTARG" >&2
			exit 1
			;;
	esac
done

if [ -z "$OUTPUT_DIR" ]; then
	echo "false, must use -o to tell me your output directory"
	exit 1
fi

mkdir -p "$OUTPUT_DIR"

if [ "$ZIP" = true ]; then
	EXTENSION="*gz"
else
	EXTENSION="*fastq"
fi

if [ ! -f "$SAMPLELIST" ]; then
	echo "No,I can't find samplelist file"
	exit 1
fi

declare -A SAMPLE_GROUPS

while IFS= read -r line; do
	if [[ -z "$line" ]]; then
		continue
	fi

	sample_path=$(echo "$line" | awk '{print $1}')
	group=$(echo "$line" | awk '{print $2}')

	sample_path=$(echo "$sample_path" | tr -d '[:space:]')
	group=$(echo "$group" | tr -d '[:space:]')

	SAMPLE_GROUPS["$sample_path"]="$group"
	
done < "$SAMPLELIST"

declare -A GROUP_COUNT

for group in "${SAMPLE_GROUPS[@]}"; do
	GROUP_COUNT["$group"]=1
done

if [ ${#GROUP_COUNT[@]} -gt 2 ]; then
	echo "Sorry, the group number is > 2: ${!GROUP_COUNT[@]}"
	echo "Please check your samplelist file, and make sure the group only have A and B "
	exit 1
fi

FC_OUTPUT_DIR="$OUTPUT_DIR/fastqc_result"
mkdir -p "$FC_OUTPUT_DIR"

for sample in "${!SAMPLE_GROUPS[@]}"; do
	sample=$(echo "$sample" | tr -d '[:space:]')

	if [ -n "$sample" ]; then
		filename="${sample}/${EXTENSION}"

		echo "$filename is executing fastqc"

		fastqc -o $FC_OUTPUT_DIR -t "$THREADS" $filename
	fi
done

echo "fastqc all done!"

TRIM_DIR="$OUTPUT_DIR/trimmomatic_result"
mkdir -p "$TRIM_DIR"


for sample in "${!SAMPLE_GROUPS[@]}"; do
	sample=$(echo "$sample" | tr -d '[:space:]')

	sample_name=$(basename $sample)

	if [ -n "$sample" ]; then
		filename="${sample}/${EXTENSION}"

		echo "$filename is executing Trimmomatic"
		
		TRIM_BASEOUT="$TRIM_DIR/${sample_name}_trim.fastq.gz"

		java -jar $WHERETRIM PE -threads "$THREADS" $filename -baseout $TRIM_BASEOUT SLIDINGWINDOW:4:15 LEADING:3 TRAILING:3 MINLEN:36 
	fi
done

echo "trim all done!"
