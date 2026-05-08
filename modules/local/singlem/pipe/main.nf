process SINGLEM_PIPE {
    tag "$meta.id"
    label 'process_medium'
    //database version must match the software version. it is better to redownload the database when the software is updated, to avoid compatibility issues. if the database is not available for the new version
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/singlem%3A0.20.3--pyhdfd78af_2' :
        'biocontainers/singlem%3A0.20.3--pyhdfd78af_2' }"

    input:
    tuple val(meta), path(reads)
    path(metapackage)

    output:

    tuple val(meta), path('*.profile.tsv'), emit: profile
    tuple val(meta), path('*.profile_filtered.tsv'), emit: profile_filtered
    tuple val(meta), path('*.taxonomic-profile-krona.html'),  optional:true, emit: taxonomic_profile_krona
    tuple val(meta), path('*.otu-table.tsv'), optional:true, emit: otu_table

    path "versions.yml"           , emit: versions


    when:
    task.ext.when == null || task.ext.when

    script:
    //def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def input = meta.single_end ? "-1 ${reads}" : "-1 ${reads[0]} -2 ${reads[1]}"

    """

    singlem pipe \\
        ${input} \\
        -p ${prefix}.profile.tsv \\
        --taxonomic-profile-krona ${prefix}.taxonomic-profile-krona.html \\
        --otu-table ${prefix}.otu-table.tsv \\
        --threads  $task.cpus \\
        --metapackage ${metapackage}


    echo -e "sample\tcoverage\ttaxonomy" > "${prefix}.profile_filtered.tsv"
    awk -v s="${meta.id}" '
    BEGIN {FS=OFS="\t"}
    NR==1 {next}
    \$3 ~ /s__/ {
        print s, \$2, \$3
    }
    ' ${prefix}.profile.tsv >> "${prefix}.profile_filtered.tsv"


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        singlem: \$(singlem --version)
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
