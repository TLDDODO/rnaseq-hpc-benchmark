params.samples = [
    'SRR24949775',
    'SRR24949778',
    'SRR24949781',
    'SRR24949786',
    'SRR24949787',
    'SRR24949788'
]

params.raw    = '/scratch/e1546946/phm5004/data/raw'
params.outdir = '/scratch/e1546946/phm5004/data/level3_out'
params.index  = '/scratch/e1546946/phm5004/ref/star_index'
params.gtf    = '/scratch/e1546946/phm5004/ref/gtf/Homo_sapiens.GRCh38.109.gtf'

process FASTP {
    tag "$sample"
    module 'fastp/0.23.2-GCC-11.3.0'
    publishDir "${params.outdir}/trimmed", mode: 'copy', overwrite: false

    input:
    tuple val(sample), path(r1), path(r2)

    output:
    tuple val(sample), path("${sample}_1.trimmed.fastq"), path("${sample}_2.trimmed.fastq")

    script:
    """
    fastp \
        -i $r1 -I $r2 \
        -o ${sample}_1.trimmed.fastq \
        -O ${sample}_2.trimmed.fastq \
        -j ${sample}_fastp.json \
        -h ${sample}_fastp.html \
        -w 8
    """
}

process STAR_ALIGN {
    tag "$sample"
    module 'STAR/2.7.11b-GCC-11.3.0'
    publishDir "${params.outdir}/aligned", mode: 'copy'

    input:
    tuple val(sample), path(r1), path(r2)

    output:
    tuple val(sample), path("${sample}_Aligned.sortedByCoord.out.bam")

    script:
    """
    STAR \
        --runThreadN 8 \
        --genomeDir ${params.index} \
        --readFilesIn $r1 $r2 \
        --outSAMtype BAM SortedByCoordinate \
        --outFileNamePrefix ${sample}_
    """
}

process SAMTOOLS_INDEX {
    tag "$sample"
    module 'SAMtools/1.16.1-GCC-11.3.0'
    publishDir "${params.outdir}/aligned", mode: 'copy'

    input:
    tuple val(sample), path(bam)

    output:
    tuple val(sample), path("${bam}"), path("${bam}.bai")

    script:
    """
    samtools index -@ 8 ${bam}
    """
}

process FEATURECOUNTS {
    tag "$sample"
    module 'Subread/2.0.4-GCC-11.3.0'
    publishDir "${params.outdir}/counts", mode: 'copy'

    input:
    tuple val(sample), path(bam), path(bai)

    output:
    tuple val(sample), path("${sample}_counts.txt")

    script:
    """
    featureCounts \
        -p \
        -T 8 \
        -a ${params.gtf} \
        -o ${sample}_counts.txt \
        $bam
    """
}

workflow {
    Channel
        .from(params.samples)
        .map { sample ->
            tuple(
                sample,
                file("${params.raw}/${sample}_1.fastq"),
                file("${params.raw}/${sample}_2.fastq")
            )
        }
        .set { reads_ch }

    FASTP(reads_ch)
    STAR_ALIGN(FASTP.out)
    SAMTOOLS_INDEX(STAR_ALIGN.out)
    FEATURECOUNTS(SAMTOOLS_INDEX.out)
}