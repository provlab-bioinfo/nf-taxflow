process GTDBTK_ANIREP {
    tag "${meta.id}"
    label 'process_high_memory'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/gtdbtk:2.5.2--pyh1f0d9b5_0' :
        'biocontainers/gtdbtk:2.5.2--pyh1f0d9b5_0' }"

    // --------------------------
    // INPUT
    // --------------------------
    input:
    tuple val(meta), path(contigs, stageAs: "input_dir/*")
    path(db)

    // --------------------------
    // OUTPUT
    // --------------------------
    output:
    tuple val(meta), path("*.ani_closest.tsv"),       emit: closest
    tuple val(meta), path("*.ani_summary.tsv"),       emit: summary
    tuple val(meta), path("*.json"),                  emit: json
    tuple val(meta), path("${prefix}.log"),           emit: log
    tuple val(meta), path("${prefix}.warnings.log"),  emit: warnings
    path ("versions.yml"),                                      emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args        = task.ext.args ?: ''
    prefix          = task.ext.prefix ?: "${meta.id}"

    def contigFiles = contigs instanceof List ? contigs : [contigs]
    def firstFileName = contigFiles[0].getName()

    // Extract extension
    def extension = firstFileName.endsWith('.gz')
        ? '.' + firstFileName.tokenize('.')[-2] + '.gz'
        : '.' + firstFileName.tokenize('.')[-1]

    // Log it (optional)
    log.info "Detected extension for ${firstFileName}: ${extension}"

    // Validate against allowed extensions (with leading dots)
    def allowed = ['.fna', '.fna.gz', '.fasta', '.fasta.gz', '.fa', '.fa.gz']
    if (!(extension in allowed)) {
        error "Unsupported contig file extension: ${extension}"
    }


 //--prefix ${meta.id} \\
    """
    # Set GTDB database path
    export GTDBTK_DATA_PATH="\$(find -L ${db} -maxdepth 2 -name 'metadata' -type d -exec dirname {} \\;)"

    # Run GTDB-Tk ANI REP on *all* genomes in input_dir/
    gtdbtk ani_rep \\
        ${args} \\
        -x ${extension} \\
        --genome_dir input_dir \\
        --out_dir ./ \\
        --cpus ${task.cpus}

    # Normalize filenames
    mv gtdbtk.log             ${prefix}.log
    mv gtdbtk.warnings.log    ${prefix}.warnings.log
    mv gtdbtk.json            ${prefix}.json
    mv gtdbtk.ani_summary.tsv ${prefix}.ani_summary.tsv
    mv gtdbtk.ani_closest.tsv ${prefix}.ani_closest.tsv

    # Version file
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gtdbtk: \$(echo \$(gtdbtk --version 2>/dev/null) | sed "s/gtdbtk: version //; s/ Copyright.*//")
    END_VERSIONS
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"
    """

    touch ${prefix}.ani_summary.tsv
    touch ${prefix}.ani_closest.tsv
    touch ${prefix}.log
    touch ${prefix}.json
    touch ${prefix}.warnings.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gtdbtk: "stub"
    END_VERSIONS
    """
}
