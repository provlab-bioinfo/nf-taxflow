process SINGLEM_SUMMARISE {
    tag "$meta.id"
    label 'process_medium'
    //database version must match the software version. it is better to redownload the database when the software is updated, to avoid compatibility issues. if the database is not available for the new version
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/singlem%3A0.20.3--pyhdfd78af_2' :
        'biocontainers/singlem%3A0.20.3--pyhdfd78af_2' }"

    input:
    tuple val(meta), path(taxonomic_profile)


    output:
    tuple val(meta), path('*-domain.tsv'),  optional:true, emit: domain_profile
    tuple val(meta), path('*-phylum.tsv'),  optional:true, emit: phylum_profile
    tuple val(meta), path('*-class.tsv'),  optional:true, emit: class_profile
    tuple val(meta), path('*-order.tsv'),  optional:true, emit: order_profile
    tuple val(meta), path('*-family.tsv'),  optional:true, emit: family_profile
    tuple val(meta), path('*-genus.tsv'),  optional:true, emit: genus_profile
    tuple val(meta), path('*-species.tsv'),  optional:true, emit: species_profile
    path "versions.yml"           , emit: versions


    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"


    """
    singlem summarise \\
        --input-taxonomic-profile ${taxonomic_profile} \\
        --output-species-by-site-relative-abundance-prefix ${prefix}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        singlem: \$(singlem --version)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"


    """
    touch ${prefix}-domain.tsv
    touch ${prefix}-phylum.tsv
    touch ${prefix}-class.tsv
    touch ${prefix}-order.tsv
    touch ${prefix}-family.tsv
    touch ${prefix}-genus.tsv
    touch ${prefix}-species.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        singlem: \$(singlem --version)
    END_VERSIONS
    """

}
