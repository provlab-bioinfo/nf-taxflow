
process SYLPHTAX_TAXPROF {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/sylph-tax:1.9.0--pyhdfd78af_0':
        'biocontainers/sylph-tax:1.9.0--pyhdfd78af_0' }"

    input:
    tuple val(meta), path(sylph_results), path(db_paths)



    output:
    tuple val(meta), path("*.sylphmpa"), emit: taxprof_output
    tuple val(meta), path("*.filtered.sylphmpa"), emit: taxprof_filtered_output
    path "versions.yml"                , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def db_flags = db_paths.collect { "${it}" }.join(' ')
    def taxons = db_flags ? "-t $db_flags" : ''

    """
    export SYLPH_TAXONOMY_CONFIG="/tmp/config.json"
    sylph-tax \\
        taxprof \\
        $sylph_results \\
        $args \\
        ${taxons}

    mv *.sylphmpa ${prefix}.sylphmpa


    echo -e "sample\tclade_name\trelative_abundance\tsequence_abundance\tANI\tCoverage" > "${prefix}.filtered.sylphmpa"
    awk -v s="${meta.id}" '
    BEGIN {FS=OFS="\t"}
    NR==1 {next}
    \$1 ~ /t__/ {
        print s, \$1, \$2, \$3, \$4, \$5
    }
    ' ${prefix}.sylphmpa >> "${prefix}.filtered.sylphmpa"


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sylph-tax: \$(sylph-tax --version)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    export SYLPH_TAXONOMY_CONFIG="/tmp/config.json"
    touch ${prefix}.sylphmpa

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sylph-tax: \$(sylph-tax --version)
    END_VERSIONS
    """
}
