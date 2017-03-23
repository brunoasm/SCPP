Sequence Capture using PCR-generated Probes (SCPP)
=================================================

Pipeline for Illumina SCPP experiment data.
Joshua Penalba, Sonal Singhal, & Ke Bi
December 24 2013

Pipeline is a constant work in progress. Contact Josh for python scripts and Ke for perl script questions.

This pipeline is a combination of novel scripts and scripts from other pipelines http://www.github.com/MVZSEQ/transcriptome and http://www.github.com/singhal/exomeCapture.


## Fork information

Bruno de Medeiros (souzademedeiros@fas.harvard.edu) forked this repository on 23 Mar 2017 to use some scripts for his SCPP experiment. 
Modifications were done mostly to return functionality to scripts that had problems with newer versions of dependencies, and to add an appropriate shebang to files so that they could be directly executed in the linux system available at Harvard Odyssey Cluster. Other than the shebang, the following files were modified:

1. 6-generateReferences.py 
 * corrected bug with name of output directory (was adding a slash even when not needed)
 * updated command for samtools sort (output now needs to include .bam extension and be provided as -o argument)
 * updated blast commands to use programs in blast+
 * blast output parser now ignores commented lines
 * added argument for user to decide number of threads for blast and bowtie

2. 7-alignment.py
 * updated command for samtools sort (output now needs to include .bam extension and be provided as -o argument)
 
3. 8-phaseHap.pl 
 * updated command for picard (now the only executable is picard.jar, *AddOrReplaceReadGroups* and *CreateSequenceDictionary* are options)

4. 9-hapTools.py
 * corrected a bug that resulted in consensus being saved in the wrong folder and inability to delete temporary files

Also, a new script was written to rename samples in alignment and tree files. See ** 10-addTaxonNames.R **

This fork is a work in progress and scripts that I did not use will eventually be deleted (mainly those related to read cleaning and assembly)

****************************************************************
1-pre-cleanup.pl: Reformats raw sequencing reads from Illumina for 2-scrubReads.pl

Dependencies: fastqc (if evaluation is desired)

Input is the raw libraries with the following naming convention: 
<br>LIB1_ATCAGC_L006_R1_001.fasta.gz

Output in a folder called "pre-clean" will be:
<br>LIB1_R1.fq

****************************************************************
2-scrubReads.pl: Removes adapters, contamination, and low complexity reads and merges overlapping reads

Dependencies: COPE, cutadapt, FLASH, fastQC, Bowtie2

Input is reformated libraries:
<br>LIB1_R1.fq
<br>LIB1_R2.fq

Output is the following .txt files:
<br>LIB1_1_final.txt (left reads)
<br>LIB1_2_final.txt (right reads)
<br>LIB1_u_final.txt (merged or unpaired reads)
<br>LIB1.contam.out
<br>LIB1.duplicates.out
<br>LIB1.lowComplexity.out

Note: If only single indexing (P7) leave out P5 column

****************************************************************
3-denovoAssembly.py: Uses ABySS to assemble each library.

Dependencies: ABySS, samtools

Input are cleaned reads:
<br>LIB1_1_final.txt
<br>LIB1_2_final.txt
<br>LIB1_u_final.txt

Output is ABySS output:
<br>LIB1_k61_5-contigs.fa
<br>(k61 being the kmer and 5 being the kmer coverage)

****************************************************************
4-poolAssembly.py: Pools all the kmers and kmer coverages into one file/

Dependencies: none

Input are ABySS assemblies:
<br>LIB1_k61_5-contigs.fa

Output:
<br>LIB1.fa

****************************************************************
5-finalAssembly.pl: clusters contigs and assembles larger contigs.

Dependencies: blat (v34), CAP3, cd-hit-est

Input is the pooled assemblies:
<br>LIB1.fa

Output:
<br>LIB1.fa.final (final output)
<br>LIB1.fa.original
<br>LIB1.fa.cl98a
<br>LIB1.fa.cl98b
<br>LIB1.fa.cl98b.clustered
<br>LIB1.fa.cl99a
<br>LIB1.fa.cl99b

****************************************************************
6-generateReferences.py: generates a reference for each library using its own contigs.

Dependencies: bowtie2, samtools

Input:
<br>LIB1_1_final.txt
<br>LIB1.fa.final
<br>RefLoci.fa

Output:
<br>LIB1.fa
<br>LIB1_ref.report

****************************************************************
7-alignment.py: Reads are aligned to the references using novoalign

Dependencies: novoalign, samtools

Input are cleaned reads and reference:
<br>LIB1_1_final.txt
<br>LIB1_2_final.txt
<br>LIB1_u_final.txt
<br>LIB1.fa

Output:
<br>LIB1.sorted.bam
<br>LIB1.sorted.bam.bai
<br>LIB1.cov (only if coverage is desired)

****************************************************************
8-phaseHap.pl: Uses GATK to come up with haplotypes

Dependencies: GATK, picard

Input are alignments:
<br>LIB1.sorted.bam
<br>LIB1.sorted.bam.bai
<br>LIB1.fa (reference file)

Output: 
<br>LIB1.final_hap1.txt
<br>LIB1.final_hap2.txt

****************************************************************
9-hapTools.py: Has different functions to manipulate the haplotypes

Command: callFixer
Function: fixes the references so that each base is the majority of all the reads that map. This is how homozygous loci are called. The mitochondrial haplotype is the output of this script. The script needs to be called for nuclear loci as well so that the homozygous loci are not comprised of bases from reads with sequencing errors. 

Dependencies: samtools, assembly_evaluation.pl

Input are alignments and references:
<br>LIB1.fa (reference file)
<br>LIB1.sorted.bam
LIB1.sorted.bam.bai

Output:
<br>LIB1_fixed.fa
<br>LIB1_pos.txt


Command: consensus
Function: Creates a consensus sequences from the haplotypes. It is always preferable to use the haplotype data from GATK rather than consensus sequences. This is to be used by the researcher's discretion. The output is only the heterozygous loci. The output should be combined with fixed references using the 'combine' command to get all the loci.

Dependecies: mafft

Input:
<br>LIB1.final_hap1.txt
<br>LIB1.final_hap2.txt

Output: 
<br>LIB1.fa (heterozygous consensus)
<br>LIB1.out (output information with indel and SNP info)


Command: combine
Function: Combines the heterozygous output of the 'consensus' function with the fixed references to get all the loci in one file.

Dependencies: none

Input:
<br>LIB1.fa (heterozygous only)

Output:
<br>LIB1.fa (combined)


Command: rename
Function: Renames the libraries if the name is not what the researcher desires.

Input:
<br>LIB1.fa (combined or otherwise)
<br>ExtInfo.txt

Output:
<br>RENAME1.fa


Command: perLoc
Function: Turns each library consensus file to files organized per locus rather than per library.

Input:
<br>LIB1.fa (combined or RENAME1.fa)

Output:
<br>LOC1.fa
<br>LOC2.fa
<br>LOC3.fa

****************************************************************
10-addTaxonNames.R: replaces taxon names in text files (e. g. tree or alignment files). It can either replace names or append them.
Usage:
`Rscript 10-addTaxonNames.R -h` for help

Input:

* files in which names should be replaced
* a table in xlsx or csv format, containg a column named *genomics* with sample ids and another names *taxon* with corresponding taxon names. Spaces in names will be replaced by underscores and dots will be removed.
