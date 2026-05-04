# RNA-seq HPC Pipeline Benchmark

## Overview

This project benchmarks multiple optimization strategies for a bulk RNA-seq analysis pipeline on NUS HPC clusters (Vanda and Atlas9). Starting from a 5.8-hour serial baseline, we systematically explored multi-threading, sample-level parallelism, workflow management (Nextflow), shared memory genome loading (GenomeLoad), and NFS-aware I/O optimization.

**Key result: 20796s → 843s, 24.7× speedup**

## Dataset

- **GEO Accession**: GSE284355
- **Cell line**: HeLa STEAP3-KD
- **Samples**: 6 paired-end samples (PE150, NovaSeq 6000)
- **Reference genome**: GRCh38 (Ensembl 109)

## Pipeline Steps

## Environments

| Cluster | Scheduler | Storage | Notes |
|---------|-----------|---------|-------|
| Vanda (NUS HPC) | PBS Pro | NFS (/scratch) | shmget disabled |
| Atlas9 (NUS HPC) | PBS Pro | NFS (/hpctmp) | shmget enabled |

## Methods & Results

| Method | Cores | Cluster | Mean Time | Std Dev | Speedup |
|--------|-------|---------|-----------|---------|---------|
| L1 Serial (1T) | 1 | Vanda | 20796s | 542s | 1.0× |
| L2 Multicore (8T) | 8 | Vanda | 4571s | 347s | 4.6× |
| Nextflow 24core | 24 | Vanda | 1339s | 36s | 15.5× |
| Nextflow scratch 24core | 24 | Vanda | 1134s | 60s | 18.3× |
| Bash parallel 24core | 24 | Vanda | 1261s | 52s | 16.5× |
| Nextflow 48core | 48 | Vanda | 843s | 32s | 24.7× |
| GenomeLoad bash 24core | 24 | Atlas9 | 8875s | 3267s | 2.3× |

## Per-Step Timing (Nextflow scratch, representative run)

| Step | Time |
|------|------|
| fastp (6 parallel) | ~211s |
| STAR alignment (3 parallel × 2 batch) | ~547s |
| samtools index (6 parallel) | ~37s |
| featureCounts | ~30s |

## Key Findings

1. **Multi-threading alone** (L1→L2) gives 4.6× speedup but is limited by NFS I/O — STAR scales only 2.8× despite 8× more threads.
2. **Sample-level parallelism** (L2→L3) is the dominant optimization — processing 6 samples concurrently gives the largest speedup jump.
3. **Nextflow scratch mode** reduces I/O pressure by using local `/tmp` for intermediate files, improving on standard Nextflow by 15%.
4. **Bash parallel vs Nextflow**: nearly identical performance (1261s vs 1134s), showing that for single-node workloads, bash parallelism can match workflow managers.
5. **GenomeLoad on Atlas9**: despite loading genome only once, overall performance was slower than Nextflow on Vanda due to Atlas9's higher NFS latency and node contention.

## Data Quality (MultiQC)

| Metric | Range | Assessment |
|--------|-------|------------|
| STAR uniquely mapped | 91.3% – 94.6% | Excellent (>90%) |
| featureCounts assigned | 72.9% – 76.8% | Normal for bulk RNA-seq |
| fastp pass filter | 98.9% – 99.2% | High quality raw data |
| Duplication rate | 13.6% – 18.9% | Normal range |

All pipeline versions produce identical biological results — optimization affects runtime only, not output quality.

## Amdahl's Law Analysis

Serial fraction (featureCounts only) ≈ 60/20796 ≈ 0.3%

Theoretical maximum speedup = 1/0.003 ≈ 333×

Observed maximum speedup = 24.7× (Nextflow 48core)

Gap between theoretical and observed speedup is explained by:
- NFS I/O bottleneck (not captured by Amdahl's model)
- Memory bandwidth saturation during genome loading
- PBS scheduling overhead

## Failed Experiments

| Experiment | Failure | Root Cause |
|-----------|---------|------------|
| GenomeLoad on Vanda | shmget error | shmget disabled by HPC admin |
| Nextflow + GenomeLoad process | shmget error | Nextflow subshells cannot share memory segments |
| STAR BAM sort with 24 cores | Empty BAM files | NFS I/O bandwidth exceeded by concurrent sort threads |
| Nextflow 24core with 120GB RAM | OOM kill | 6 STAR × 31GB = 186GB required |

## Vanda vs Atlas9 Comparison

| Feature | Vanda | Atlas9 |
|---------|-------|--------|
| Shared memory (shmget) | ❌ Disabled | ✅ Enabled |
| Max queue memory | ~166GB | 540GB |
| STAR module | 2.7.11b | 2.7.5b |
| NFS performance | Faster | Slower (higher latency) |
| GenomeLoad | Not possible | Possible but slower overall |

**Conclusion**: GenomeLoad requires Atlas9, but Atlas9's higher NFS latency negates the genome-loading benefit. For NFS-based clusters, sample-level parallelism (Nextflow/Bash) is more effective than shared memory optimization.

## Repository Structure

├── scripts/
│   ├── 00_build_star_index.pbs      # Build STAR genome index
│   ├── 04_serial_level1.pbs         # L1: Serial 1-thread baseline (~5.8h)
│   ├── 05_serial_level2.pbs         # L2: Multicore 8-thread serial (~1.3h)
│   ├── 08_bash_parallel.pbs         # Bash sample-level parallel (~21min)
│   └── run_nf.pbs                   # Nextflow pipeline submission
├── nextflow/
│   ├── main.nf                      # Nextflow DSL2 pipeline
│   └── nextflow.config              # Executor config (scratch mode enabled)
├── results/
│   ├── timing_*.txt                 # Per-run timing data (3 runs each)
│   ├── trace_nf_scratch.txt         # Nextflow per-process trace
│   └── summary.txt                  # Aggregated benchmark summary
└── README.md
