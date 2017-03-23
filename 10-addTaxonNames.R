#!/usr/bin/env Rscript

# written by B. Medeiros 23-mar-2017
# requires library argparse and openxlsx (if input table in xlsx format)
# should be pretty general and be able to change names in multiple file formats (alignments, trees, xml, etc)


library(argparse)
library(tools)

parser <- ArgumentParser(description='Script to append or substitute species names to sample ids')

parser$add_argument('-i', '--inputs', type="character", nargs='+', 
                    dest='inputs', help='files where names need to be changed')
parser$add_argument('-t', '--table', type="character",  
                    dest='table', help='path to table in xls or csv formats. Must have a column named genomics with ids and another named taxon with names')
parser$add_argument('-a', '--append', action='store_true',  
                    dest='append', help='use this flag to append taxon name instead of substituting')
parser$add_argument('-o', '--overwrite', action='store_true',
                    dest='overwrite', help='use this flag to overwrite files instead of creating a new one')


#cargs = parser$parse_args(c("-t", "workflow_static.xlsx", "-i", "326.fa", "2442.fa"))

cargs = parser$parse_args()


if (file_ext(cargs$table) %in% c('xls','xlsx') ){
  library(openxlsx)
  intable = read.xlsx(cargs$table)
  
} else if (file_ext(cargs$table) %in% c('csv')) {
  intable = read.csv(cargs$table, row.names = NULL)
  
}

for (infile in cargs$inputs){
  cat(paste('Replacing names in file', infile,'\n'))
  contents = readLines(infile)
  for (sampleid in na.exclude(unique(intable$genomics))){
    taxon_name = gsub('\\.','',gsub('\\s','_',intable$taxon[which(intable$genomics == sampleid)]))
    if (cargs$append){
      contents = gsub(sampleid, paste(sampleid, taxon_name, sep='_'), contents)
    } else {
      contents = gsub(sampleid, taxon_name, contents)
    }
  }
  if (cargs$overwrite){
    writeLines(contents, infile)
  } else {
    writeLines(contents, paste('edited',infile, sep = '_'))
  }
  
}
