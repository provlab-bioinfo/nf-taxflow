/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { paramsSummaryMap } from 'plugin/nf-schema'
include { paramsSummaryMultiqc } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_taxflow_pipeline'
include { GTDBTK_ANIREP } from '../modules/local/gtdbtk/anirep/main'
include { BARRNAP } from '../modules/local/barrnap/barrnap/main'
include { BARRNAP_SPLITFASTABYGFF } from '../modules/local/barrnap/splitfastabygff/main'

include { BLAST_BLASTN } from '../modules/nf-core/blast/blastn/main'
include {
    CSVTK_CONCAT as CSVTK_CONCAT_RRNA_BLAST;
} from '../modules/local/csvtk/concat/main.nf'
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/



workflow CLASSIFYGENOMES {
    take:
    ch_contigs // channel: samplesheet read in from --input

    main:

    ch_versions = channel.empty()
    ch_contigs.view { println "Input samplesheet channel for CLASSIFYGENOMES: ${it}" }
    ch_contigs.filter {meta, reads -> reads.size() > 0 && reads.countFasta() > 0}.set { fasta_contigs }

    if (!params.skip_gtdbtk) {
        //To run GTDB-Tk ANI REP once on ALL genomes together
        fasta_contigs
            .map { meta, fasta -> fasta }
            .collect()
            .map { list -> tuple([id: "contigs"], list) }
            .set { ch_all_genomes }
        ch_all_genomes.view()
        GTDBTK_ANIREP(
            ch_all_genomes,
            params.gtdbtk_db,
        )

        ch_versions = ch_versions.mix(GTDBTK_ANIREP.out.versions)
    }
    if (!params.skip_rrna) {
        BARRNAP(
            fasta_contigs,
        )
        ch_versions = ch_versions.mix(BARRNAP.out.versions)


            BARRNAP_SPLITFASTABYGFF(
                BARRNAP.out.fasta.join(BARRNAP.out.gff)

            )
        BARRNAP_SPLITFASTABYGFF.out.rrna_16S.filter { meta, fasta -> fasta.size() > 0 && fasta.countFasta() > 0 }.set { ch_16S_fasta }

        BLAST_BLASTN(
            ch_16S_fasta,
            [[id:"blastdb"], params.gtdbtk_ssu_db],
            [],
            [],
            []
        )
        ch_versions = ch_versions.mix(BARRNAP_SPLITFASTABYGFF.out.versions)
        ch_versions = ch_versions.mix(BLAST_BLASTN.out.versions)

        CSVTK_CONCAT_RRNA_BLAST(
            BLAST_BLASTN.out.txt
                .map { meta, tsv -> tsv }
                .flatten()
                .collect()
                .map { tsvs ->
                    // Debug: print file paths
                    tsvs.each { println "File: ${it}" }
                    tuple([id: "contigs.barrnap_16S_rRNA.blastn_gtdb_ssu"], tsvs)
                },

            'tsv',
            'tsv'
        )
    }


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
