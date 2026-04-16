process SINGLEM_PIPE {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/singlem:0.20.2--pyhdfd78af_1' :
        'biocontainers/singlem:0.20.2--pyhdfd78af_1' }"

    input:
    tuple val(meta), path(reads)
    path(metapackage)

    output:
    tuple val(meta), path('*.tsv'), emit: profile_out
    path "versions.yml"           , emit: versions


    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def input = meta.single_end ? "-1 ${reads}" : "-1 ${reads[0]} -2 ${reads[1]}"

    """

    singlem pipe \\
        ${input} \\
        -p ${prefix}.taxonomic-profile.tsv \\
        --taxonomic-profile-krona ${prefix}.taxonomic-profile-krona.html \\
        --threads  $task.cpus \\
        --metapackage ${metapackage} \\
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sylph: \$(singlem --version)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"


    """
    touch ${prefix}.taxonomic-profile.tsv
    touch ${prefix}.taxonomic-profile-krona.html

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        singlem: \$(singlem --version)
    END_VERSIONS
    """

}
