# genomic summary

# directories
root_dir <- rprojroot::find_root(rprojroot::has_dir(".git"))
source(file.path(root_dir, "code", "utils", "define_directories.R"))

genomic_summary <- function(snv_pattern, key_clinical_findings_output, all_findings_output) {
  if(exists('expData')){
    headers <- c("High Confidence Genomic Alterations", "Total Genomic Alterations", "Transcriptomic Alterations", "Aberrant Pathway Activity")
    
    # total alterations
    numLesions <- all_findings_output %>%
      filter(Type %in% c("Amplification", "Deletion", "Mutation", "Fusion")) %>%
      nrow()
    
    # high confidence alterations
    highConfLesions <- nrow(key_clinical_findings_output)
    
    # highly upreg genes (z-score > 3)
    numTranscripts <- rnaseq_analysis_output$diffexpr.top20 %>%
      filter(z_score > 3) %>%
      nrow()
    
    # adj. pval < 0.05 (highly significant pathways)
    numPathways <- rnaseq_analysis_output$pathways %>%
      nrow()
    
    tmpVals <- c(highConfLesions, numLesions, numTranscripts, numPathways)
    df1 <- data.frame(headers, tmpVals)
  } else {
    df1 <- data.frame()
  }
  
  return(df1)
}