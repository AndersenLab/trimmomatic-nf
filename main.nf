#!/usr/bin/env nextflow 
/*
    Andersen Lab C. elegans Trimming Pipeline
    Authors:
    - Dan Lu <dan.lu@northwestern.edu>
*/


nextflow.preview.dsl=2


// See config in config/ folder for parameter default values


/* 
    ==================================================
    Calculate MD5 for all files in a single process
    ==================================================
*/

process pre_trim_md5sum {
    // this process runs in the data folder, instead of nextflow working dir

    """
    cd ${params.fastq_path}/${params.fastq_folder}
    md5sum *.fq.gz > md5.txt
    """
}




/* 
    ==================
    trim raw data
    ==================
*/


process fastp_trim {

    tag { sampleID }

    publishDir "${params.trimmed_path}/${params.trimmed_folder}", mode: 'copy', pattern: "*.fq.gz"


    input:
      tuple sampleID, path(fq1), path(fq2) 

    output:
      path "*_trimmed.fq.gz" 
      path "*_fastp.json", emit: fastp_json
    

      """

      fastp -i $fq1 -I $fq2 \\
            -o ${sampleID}_1_trimmed.fq.gz -O ${sampleID}_2_trimmed.fq.gz \\
            --length_required 20 \\
            -j ${sampleID}_fastp.json -h ${sampleID}_fastp.html

      """
}



/* 
    =======================
    combine all trim report
    =======================
*/



process multi_QC {


    publishDir "${params.trimmed_path}/${params.trimmed_folder}/multi_QC", mode: 'copy', pattern: "*.html"

    input:
      path(json) 

    output:
      path "*.html"
    
    script:
      """

      multiqc .

      """
}




// read input
fq = Channel.fromFilePairs("${params.fastq_path}/${params.fastq_folder}/*_{1,2}.fq.gz", flat: true)


// run workflow
workflow { 


pre_trim_md5sum()  // check sum for all files. 
// I don't know how to get the .fq out of fq channel (it has sampleID, fq1, fq2), so this process doesn't take input channel and run locally in the data folder.

fq | fastp_trim

fastp_trim.out.fastp_json.toSortedList() | multi_QC

}
