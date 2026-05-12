/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { paramsSummaryMap } from 'plugin/nf-schema'
include { paramsSummaryMultiqc } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_taxflow_pipeline'
include { CLASSIFYREADS_COMMON } from '../subworkflows/local/classifyreads_common'
include {
    CSVTK_CONCAT as CSVTK_CONCAT_TAXPROF;
    CSVTK_CONCAT as CSVTK_CONCAT_SINGLEM;
    CSVTK_CONCAT as CSVTK_CONCAT_TOPMATCHES;

} from '../modules/local/csvtk/concat/main.nf'
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow CLASSIFYREADS_SHORT {
    take:
    ch_reads // channel: samplesheet read in from --input

    main:


    ch_versions = channel.empty()

    CLASSIFYREADS_COMMON(ch_reads)
    ch_versions = ch_versions.mix(CLASSIFYREADS_COMMON.out.versions)

    CSVTK_CONCAT_TOPMATCHES(
            CLASSIFYREADS_COMMON.out.bracken_topmatches
                .map { meta, csv -> csv }
                .collect()
                .map { csvs ->
                    tuple([id: "reads_short_kraken2_bracken.topmatches"], csvs)
                },

                'csv',
                'csv'
        )
        CSVTK_CONCAT_TAXPROF(
            CLASSIFYREADS_COMMON.out.sylph_taxprof
                .map { meta, csv -> csv }
                .collect()
                .map { csvs ->
                    tuple([id: "reads_short.sylph-tax_taxprof.filtered"], csvs)
                },

            'tsv',
            'tsv'
        )
        CSVTK_CONCAT_SINGLEM(
            CLASSIFYREADS_COMMON.out.singlem_profile_filtered
                .map { meta, csv -> csv }
                .collect()
                .map { csvs ->
                    tuple([id: "reads_short.singlem_profile_filtered"], csvs)
                },

            'tsv',
            'tsv'
        )

    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name: 'software_versions.yml',
            sort: true,
            newLine: true,
        )

    emit:
    versions = ch_versions // channel: [ path(versions.yml) ]
}
