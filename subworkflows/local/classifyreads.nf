/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { KRAKEN2_KRAKEN2 } from '../../modules/local/kraken2/kraken2/main'
include { SYLPH_PROFILE } from '../../modules/local/sylph/profile/main'
include { SYLPHTAX_TAXPROF } from '../../modules/local/sylphtax/taxprof/main'
include { SINGLEM_PIPE } from '../../modules/local/singlem/pipe/main'
include { BRACKEN_BRACKEN } from '../../modules/local/bracken/bracken/main'
include { BRACKEN_COMBINEBRACKENOUTPUTS } from '../../modules/local/bracken/combinebrackenoutputs/main'
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Function to select and validate database files
def selectDatabaseFiles(db_map, selected_databases) {
    //Get selected database keys
    def selected_keys
    if (selected_databases == 'all') {
        selected_keys = db_map.keySet()
    }
    else if (selected_databases instanceof List) {
        selected_keys = selected_databases
    }
    else {
        selected_keys = selected_databases.split(',')*.trim()
    }
    // Validate keys (optional but useful)
    def unknown_keys = selected_keys - db_map.keySet()
    if (unknown_keys) {
        error("Invalid database keys: ${unknown_keys.join(', ')}. Allowed: ${db_map.keySet().join(', ')}")
    }

    // Get the file paths
    def selected_dbs = selected_keys.collect { db_map[it] }

    // Convert to Nextflow file objects
    def db_paths = selected_dbs.collect { file(it) }

    return db_paths
}

workflow CLASSIFYREADS {
    take:
    ch_reads // channel: samplesheet read in from --input

    main:

    ch_versions = channel.empty()

    //classify
    if (!params.skip_kraken2) {
        KRAKEN2_KRAKEN2(ch_reads, params.kraken2_db, false, true)
        ch_versions = ch_versions.mix(KRAKEN2_KRAKEN2.out.versions)

        BRACKEN_BRACKEN(KRAKEN2_KRAKEN2.out.report, params.kraken2_db)

        //custom column names for bracken report
        // Step 1: Convert reports to [sample_id, path] pairs
        ch_bracken_pairs = BRACKEN_BRACKEN.out.reports.map { item -> [item[0]['id'], item[1]] }
        // keep as 2-element list

        // Step 2: Collect all pairs into a single list
        ch_bracken_pairs_list = ch_bracken_pairs.toList().view()

        ch_to_combine_bracken_report = ch_bracken_pairs_list.map { items ->
            def reports = items.collect { it[1] }
            // file paths
            def names = items.collect { it[0] }.join(',')
            // sample IDs
            tuple([id: "bracken_report"], reports, names)
        }
        ch_to_combine_bracken_report.view()

        BRACKEN_COMBINEBRACKENOUTPUTS(ch_to_combine_bracken_report)
        ch_versions = ch_versions.mix(BRACKEN_COMBINEBRACKENOUTPUTS.out.versions)
    }
    /*
    sylph, a species-level metagenome profiler that estimates genome-to-metagenome containment
    average nucleotide identity (ANI) through zero-inflated Poisson k-mer statistics, enabling
    ANI-based taxa detection.
    */
    if (!params.skip_sylph) {
        // Load DB map from params
        // Get database file paths using the function
        def db_paths = selectDatabaseFiles(params.sylph_db_files, params.sylph_databases)

        // Wrap as a channel
        ch_reads
            .map { meta, reads -> tuple(meta, reads, db_paths) }
            .set { ch_sylph_inputs }


        SYLPH_PROFILE(ch_sylph_inputs)
        ch_versions = ch_versions.mix(SYLPH_PROFILE.out.versions)


        // Get database file paths using the function
        def sylphtax_db_paths = selectDatabaseFiles(params.sylphtax_db_files, params.sylphtax_databases)
        // Wrap as a channel
        //ch_sylph_profile_output = SYLPH_PROFILE.out.profile_out

        SYLPH_PROFILE.out.profile_out
            .filter { meta, tsv -> tsv.size() > 0 && tsv.countLines() > 1 }
            .map { meta, tsv ->
                tuple(meta, tsv, sylphtax_db_paths)
            }
            .set { ch_sylphtax_inputs }

        SYLPHTAX_TAXPROF(ch_sylphtax_inputs)
        ch_versions = ch_versions.mix(SYLPHTAX_TAXPROF.out.versions)

    }
    /*
    SingleM is a software suite which takes short read metagenomic data as input,
    and estimates the relative abundance and per-base read coverage of Bacteria and
    Archaea at each taxonomic level from domain to species. SingleM starts by matching
    reads to highly conserved regions (’windows’) of 59 single copy marker genes
    (22 Bacteria-specific, 24 Archaea-specific, 13 targeting both domains).
    Importantly, reads are matched to these conserved gene windows by searching in
    amino acid space, using DIAMOND BLASTX(Buchfink et al. 2021), maximising recruitment
    of reads from divergent lineages. This is in contrast to other marker-based taxonomic
    profilers, which map the nucleotide sequences of reads to markers directly (e.g. MetaPhlAn, mOTUs).

    starting from 0.20, it can support long reads
    */


    if (!params.skip_singlem) {
        SINGLEM_PIPE(ch_reads, params.singlem_db)
        ch_versions = ch_versions.mix(SINGLEM_PIPE.out.versions)

    }

    emit:
    versions = ch_versions // channel: [ path(versions.yml) ]
}
