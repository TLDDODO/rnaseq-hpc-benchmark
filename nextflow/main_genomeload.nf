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

process GENOME_LOAD {
    module 'STAR/2.7.11b-GCC-11.3.0'

    output:
    val true

    script:
    """
    STAR --genomeLoad LoadAndExit --genomeDir ${params.index}
    """
}

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
        -w 4
    """
}

process STAR_ALIGN {
    tag "$sample"
    module 'STAR/2.7.11b-GCC-11.3.0'
    publishDir "${params.outdir}/aligned", mode: 'copy'
    maxForks 6

    input:
    tuple val(sample), path(r1), path(r2)
    val genome_ready

    output:
    tuple val(sample), path("${sample}_Aligned.sortedByCoord.out.bam")

    script:
    """
    STAR \
        --runThreadN 4 \
        --genomeDir ${params.index} \
        --genomeLoad LoadAndKeep \
        --readFilesIn $r1 $r2 \
        --outSAMtype BAM SortedByCoordinate \
        --outFileNamePrefix ${sample}_
    """
}

process GENOME_REMOVE {
    module 'STAR/2.7.11b-GCC-11.3.0'

    input:
    val all_done

    script:
    """
    STAR --genomeLoad Remove --genomeDir ${params.index}
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
    samtools index -@ 4 ${bam}
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
        -T 4 \
        -p \
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

    genome_loaded = GENOME_LOAD()

    FASTP(reads_ch)
    STAR_ALIGN(FASTP.out, genome_loaded.first())
    SAMTOOLS_INDEX(STAR_ALIGN.out)
    FEATURECOUNTS(SAMTOOLS_INDEX.out)

    GENOME_REMOVE(STAR_ALIGN.out.collect().map { true })
}
