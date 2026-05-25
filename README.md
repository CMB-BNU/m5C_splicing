# RNA-seq Alternative Splicing Pipeline

This repository contains a customized bioinformatics pipeline for RNA-seq data analysis, specifically designed to identify and quantify differential Alternative Splicing (AS) events between two conditions (e.g., Condition A vs. Condition B) across multiple biological replicates.

## Pipeline Overview
The workflow consists of the following core steps:
1. **Preprocessing & Quality Control**: `FastQC` and `Trimmomatic`
2. **Read Mapping**: `STAR` (Spliced Transcripts Alignment to a Reference)
#### 2.1 Build STAR Index (One-time setup)
Before running the mapping script, you must generate a STAR genome index for your specific reference genome. *Note: `--sjdbOverhang` should generally be set to (ReadLength - 1).*

```bash
STAR --runThreadN 20 \
     --runMode genomeGenerate \
     --genomeDir /path/to/star_index/ \
     --genomeFastaFiles /path/to/Mus_musculus.GRCm39.dna.primary_assembly.fa \
     --sjdbGTFfile /path/to/Mus_musculus.GRCm39.105.chr.gtf \
     --sjdbOverhang 149

4. **Alternative Splicing Analysis**: `MAJIQ` (Modeling Alternative Junction Inclusion Quantification)
5. **Specific AS Calculation**: Custom scripts for downstream AS filtering and quantification.

## Prerequisites
Ensure the following tools are installed and available in your system's `$PATH`:
* [FastQC](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/)
* [Trimmomatic](http://www.usadellab.org/cms/?page=trimmomatic) (Default path in script: `~/soft/Trimmomatic-0.39/trimmomatic-0.39.jar`)
* [STAR](https://github.com/alexdobin/STAR)
* [MAJIQ](https://majiq.biociphers.org/)
* Java, Python 3, and basic shell utilities (awk, bash).

## Usage

### 1. Data Preparation
Create a `samplelist.txt` file containing the absolute paths to your sample directories and their corresponding group assignments. **Note: Currently, the pipeline strictly supports exactly 2 groups.**

Format of `samplelist.txt` (Tab or space separated):
```text
/path/to/sample1_dir    GroupA
/path/to/sample2_dir    GroupA
/path/to/sample3_dir    GroupB
/path/to/sample4_dir    GroupB
