# m5C_splicing: A computational framework for condition-specific alternative splicing

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Introduction
While 5-Methylcytosine (m5C) is critical for mRNA metabolism, its global influence on alternative splicing (AS) remains largely unexplored. This repository contains a robust and automated computational framework developed to systematically identify both **differential and condition-specific alternative splicing (AS) events** across multiple biological conditions. 

Originally applied to *Nsun2* conditional knockout mouse livers, this pipeline effectively maps how epitranscriptomic regulators reshape the splicing architecture. It processes raw RNA-seq data through quality control, precise genomic mapping, splice graph construction, and robust PSI (Percent Spliced In) quantification.

## Prerequisites & Dependencies
To run this pipeline, ensure the following tools are installed and available in your system's `$PATH` or specified via script arguments:

* **[FastQC](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/)**: For sequencing data quality control.
* **[Trimmomatic](http://www.usadellab.org/cms/?page=trimmomatic)**: For adapter trimming and read filtering.
* **[STAR](https://github.com/alexdobin/STAR)** (v2.7+ recommended): For spliced alignments.
* **[MAJIQ](https://majiq.biociphers.org/)** (v2.4+): For local splice graph building and AS quantification.
* **Basic utilities**: `awk`, `bash`, `java`, `python3`.

## Pipeline Workflow

### 0. Data Preparation (`samplelist.txt`)
Before running any scripts, you must create a Tab-separated configuration file named `samplelist.txt`. This file tells the pipeline exactly what your samples are, which experimental group they belong to, and where the raw paired-end fastq files are located.

**Format (No headers, Tab-separated):**
`SampleName` `\t` `GroupName` `\t` `Read1.fastq.gz,Read2.fastq.gz`

*Example:*
```text
WT_1    WT      /path/to/raw/WT_1_R1.fq.gz,/path/to/raw/WT_1_R2.fq.gz
WT_2    WT      /path/to/raw/WT_2_R1.fq.gz,/path/to/raw/WT_2_R2.fq.gz
cKO_1   cKO     /path/to/raw/cKO_1_R1.fq.gz,/path/to/raw/cKO_1_R2.fq.gz
```

---

### Step 1: Preprocessing (`preprocess.sh`)
This script performs raw data quality control using FastQC and trims adapter sequences/low-quality bases using Trimmomatic.

```bash
bash preprocess.sh -o ./preprocessing_out -s samplelist.txt -a /path/to/adapters/TruSeq3-PE.fa -t 10
```
**Parameters:**
* `-o`: Output directory for FastQC and trimmed fastq files.
* `-s`: Path to your `samplelist.txt`.
* `-a`: Path to the Trimmomatic adapter FASTA file (e.g., `TruSeq3-PE.fa`).
* `-m`: *(Optional)* Absolute path to `trimmomatic.jar` if not installed via Conda.
* `-t`: Number of threads to use.

---

### Step 2: Read Mapping (`run_star.sh`)
Maps the cleaned reads to the reference genome using STAR. *Note: You must generate a STAR genome index (`STAR --runMode genomeGenerate`) prior to running this step.*

```bash
bash run_star.sh -d ./preprocessing_out/trimmomatic_result -o ./star_out -x /path/to/star_index -g /path/to/reference.gtf -s samplelist.txt -t 20
```
**Parameters:**
* `-d`: The output directory containing the cleaned reads from Step 1.
* `-o`: Output directory for STAR alignment results (`.bam` files).
* `-x`: Path to your pre-built STAR genome index.
* `-g`: Path to the reference GTF annotation file.
* `-s`: Path to your `samplelist.txt`.
* `-r`: *(Optional)* `--sjdbOverhang` value (Default: 149, usually ReadLength - 1).

---

### Step 3: Splice Graph Construction & Quantification (`run_majiq.sh`)
This integrated script automatically generates the required `experiments.tsv` configuration from the mapping results, builds the MAJIQ splice graphs, runs `psi-coverage` to filter reliable splicing events, and executes `majiq psi` independently for each condition.

```bash
bash run_majiq.sh -d ./star_out -g /path/to/reference.gff3 -s samplelist.txt -o ./majiq_out -t 20
```
**Parameters:**
* `-d`: The output directory from Step 2 containing STAR `.bam` files.
* `-g`: Path to the reference **GFF3** file.
* `-s`: Path to your `samplelist.txt`.
* `-o`: Output directory for all MAJIQ results (splicegraphs, `.psicov`, and `.tsv` files).
* `-t`: Number of threads to use.

**Key Behavior:**
The pipeline natively supports dynamic group detection. It uses `--minreads 1` and `--minbins 1` for broad coverage, and `--min-experiments 1` to ensure that an event is quantified if it passes the reliability threshold in at least one replicate of a given condition.

## ✉️ Contact
For questions, bug reports, or feature requests, please open an issue on the GitHub repository.
