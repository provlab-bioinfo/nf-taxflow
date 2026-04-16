process BRACKEN_COMBINEBRACKENOUTPUTS {
    tag "${meta.id}"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/bracken%3A3.1--h9948957_0'
        : 'biocontainers//bracken%3A3.1--h9948957_0'}"

    input:
    tuple val(meta), path(input), val(names)

    output:
    tuple val(meta), path("${prefix}.tsv"), emit: txt
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"

    // WARN: Version information not provided by tool on CLI.
    // Please update version string below when bumping container versions.
    def VERSION = '3.1'
    """
    combine_bracken_outputs.py \\
        ${args} \\
        --files ${input} \\
        --names ${names ?: ''} \\
        -o ${prefix}.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        combine_bracken_output: ${VERSION}
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    // WARN: Version information not provided by tool on CLI.
    // Please update version string below when bumping container versions.
    def VERSION = '3.1'
    """
    touch ${prefix}.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        combine_bracken_output: ${VERSION}
    END_VERSIONS
    """
}
