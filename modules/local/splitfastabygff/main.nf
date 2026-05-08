process SPLITFASTABYGFF {
    label 'process_single'

    conda "conda-forge::python=3.9.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.9--1' :
        'biocontainers/python:3.9--1' }"
    input:
    tuple val(meta), path(fasta), path(gff)

    output:

    tuple val(meta), path("*5S_rRNA.fa"),  optional:true, emit: rrna_5S
    tuple val(meta), path("*16S_rRNA.fa"), optional: true, emit: rrna_16S
    tuple val(meta), path("*23S_rRNA.fa"), optional: true, emit: rrna_23S
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"
    def VERSION = '1.2' // WARN: Version information not provided by tool on CLI. Please update this string when bumping container versions.
    """

    split_fasta_by_gff.py ${gff} ${fasta} ./ ${prefix}

    cat <<-END_VERSIONS > versions.yml
     "${task.process}":
        python: \$(python --version | sed 's/Python //g')
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.top_matches.csv

    cat <<-END_VERSIONS > versions.yml
     "${task.process}":
        python: \$(python --version | sed 's/Python //g')
    END_VERSIONS
    """
}
