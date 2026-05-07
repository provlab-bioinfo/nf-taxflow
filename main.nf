#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    xiaoli-dong/pathotax
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Github : https://github.com/xiaoli-dong/pathotax
----------------------------------------------------------------------------------------
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS / WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/


include { PIPELINE_INITIALISATION } from './subworkflows/local/utils_nfcore_taxflow_pipeline'
include { PIPELINE_COMPLETION } from './subworkflows/local/utils_nfcore_taxflow_pipeline'
include { getGenomeAttribute } from './subworkflows/local/utils_nfcore_taxflow_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    GENOME PARAMETER VALUES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    NAMED WORKFLOW FOR PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { CLASSIFYGENOMES } from './workflows/classifygenomes'
include { CLASSIFYREADS_SHORT } from './workflows/classifyreads_short' // for short reads
include { CLASSIFYREADS_LONG } from './workflows/classifyreads_long' // for long reads, we can use the same workflow as for contigs/genomes, since the classification is the same (just different input format)
//}
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    NAMED WORKFLOWS FOR PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// WORKFLOW: Run main analysis pipeline depending on type of input
//

workflow ABRPOVLAB_TAXFLOW {

    take:
    ch_samplesheet

    main:

    //ch_samplesheet.view { println "Input samplesheet channel: ${it}" }


    //ch_samplesheet.view ()
    /*
     * SHORT READS
     */
    ch_short = ch_samplesheet
        .filter { meta, pe, lfq, contig -> pe != null }
        .map { meta, pe, lfq, contig ->
            tuple(meta, pe)
        }

    /*
     * LONG READS
     */
    ch_long = ch_samplesheet
        .filter { meta, pe, lfq, contig -> lfq != null }
        .map { meta, pe, lfq, contig ->
            tuple(
                [ id: meta.id, single_end: true ],
                lfq
            )
        }

    /*
     * CONTIGS
     */
    ch_contig = ch_samplesheet
        .filter { meta, pe, lfq, contig -> contig != null }
        .map { meta, pe, lfq, contig ->
            tuple(meta, contig)
        }

    /*
     * EXECUTION SAFETY FLAGS
     */

    /*
     * SHORT (always safe if enabled)
     */
    if (params.datatype in ['short', 'all']) {
        CLASSIFYREADS_SHORT(ch_short)
    }

    /*
     * LONG (SAFE GUARD)
     */


    if (params.datatype in ['long', 'all']) {

        CLASSIFYREADS_LONG(ch_long)

    }

    /*
     * CONTIG (SAFE GUARD)
     */
    if (params.datatype in ['contig', 'all']) {

         CLASSIFYGENOMES(ch_contig)
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {
    //
    // SUBWORKFLOW: Run initialisation tasks
    //
    PIPELINE_INITIALISATION(
        params.version,
        params.validate_params,
        params.monochrome_logs,
        args,
        params.outdir,
        params.input,
    )

    //
    // WORKFLOW: Run main workflow
    //
     ABRPOVLAB_TAXFLOW(
        // PIPELINE_INITIALISATION.out.short_reads,
        // PIPELINE_INITIALISATION.out.long_reads,
        // PIPELINE_INITIALISATION.out.fasta_contig,
        PIPELINE_INITIALISATION.out.ch_samplesheet
    )

    /* ABRPOVLAB_TAXFLOW(
        PIPELINE_INITIALISATION.out.ch_samplesheet

    ) */
    //
    // SUBWORKFLOW: Run completion tasks
    //
    PIPELINE_COMPLETION(
        params.email,
        params.email_on_fail,
        params.plaintext_email,
        params.outdir,
        params.monochrome_logs,
        params.hook_url
    )
}
