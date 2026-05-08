process BRACKEN_BRACKEN {
    tag "$meta.id"
    label 'process_low'

    //version 3.x has errors: "Error: no reads found. Please check your Kraken report,
    // added -t 0 solve the problems

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bracken%3A3.1--h9948957_0':
        'biocontainers//bracken%3A3.1--h9948957_0' }"

    input:
    tuple val(meta), path(kraken_report)
    path database

    output:
    tuple val(meta), path(bracken_report)        , emit: reports
    tuple val(meta), path(bracken_kraken_style_report), emit: txt
    path "versions.yml"          , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ""
    def prefix = task.ext.prefix ?: "${meta.id}"
    bracken_report = "${prefix}.tsv"
    bracken_kraken_style_report = "${prefix}.kraken2.report_bracken.txt"
    //LEVEL          level to estimate abundance at [options: D,P,C,O,F,G,S,S1,etc] (default: S)
    """
    LEVEL="S"

    if [ ! -s "${kraken_report}" ]; then
        echo "Empty report"
        exit 0
    fi

    if ! grep -q \$'\\tS\\t' "${kraken_report}"; then
        if grep -q \$'\\tG\\t' "${kraken_report}"; then LEVEL="G"
        elif grep -q \$'\\tF\\t' "${kraken_report}"; then LEVEL="F"
        elif grep -q \$'\\tO\\t' "${kraken_report}"; then LEVEL="O"
        elif grep -q \$'\\tC\\t' "${kraken_report}"; then LEVEL="C"
        elif grep -q \$'\\tP\\t' "${kraken_report}"; then LEVEL="P"
        elif grep -q \$'\\tK\\t' "${kraken_report}"; then LEVEL="K"
        else LEVEL="D"
        fi
    fi

    echo "Using LEVEL: \$LEVEL"

    bracken ${args} \\
        -d '${database}' \\
        -i '${kraken_report}' \\
        -l \$LEVEL \\
        -o '${bracken_report}' \\
        -w '${bracken_kraken_style_report}' \\
        -t 0


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bracken: \$(echo \$(bracken -v) | cut -f2 -d'v')
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    bracken_report = "${prefix}.tsv"
    bracken_kraken_style_report = "${prefix}.kraken2.report_bracken.txt"
    """
    touch ${prefix}.tsv
    touch ${bracken_kraken_style_report}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bracken: \$(echo \$(bracken -v) | cut -f2 -d'v')
    END_VERSIONS
    """
}
