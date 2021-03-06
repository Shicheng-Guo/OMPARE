# script to highlight relevant alterations top 20 transcriptomically similar patients

# directories
root_dir <- rprojroot::find_root(rprojroot::has_dir(".git"))
source(file.path(root_dir, "code", "utils", "define_directories.R"))

# reference directories
pbta_dir <- file.path(ref_dir, 'pbta')
pnoc008_dir <- file.path(ref_dir, 'pnoc008')

mutational_analysis <- function(top_cor, key_clinical_findings_output){
  
  # matrix of top 20 correlated samples
  top20 <- colnames(top_cor)
  
  # pbta corresponding sample ids
  pbta_clinical <- read.delim(file.path(pbta_dir, 'pbta-histologies.tsv'))
  pbta_clinical <- pbta_clinical %>%
    filter(Kids_First_Biospecimen_ID %in% top20)  %>%
    mutate(SampleID = sample_id) %>%
    dplyr::select(SampleID, Kids_First_Biospecimen_ID)
  
  # pnoc008 corresponding sample ids
  pnoc008_clinical <- readRDS(file.path(pnoc008_dir, 'pnoc008_clinical.rds'))
  pnoc008_top20_clinical <- pnoc008_clinical %>%
    filter(subjectID %in% top20) %>%
    mutate(SampleID = subjectID, Kids_First_Biospecimen_ID = subjectID) %>%
    dplyr::select(SampleID, Kids_First_Biospecimen_ID)
  combined_clinical <- rbind(pbta_clinical, pnoc008_top20_clinical)
  
  # merge pbta + pnoc008 mutations, copy number and fusions
  # mutations
  pbta_mutations <- readRDS(file.path(pbta_dir, 'pbta-snv-consensus-mutation-filtered.rds'))
  pnoc_mutations <- readRDS(file.path(pnoc008_dir, 'pnoc008_consensus_mutation_filtered.rds'))
  total_mutations <- rbind(pbta_mutations, pnoc_mutations)
  
  # copy number
  pbta_cnv <- readRDS(file.path(pbta_dir, 'pbta-cnv-controlfreec-filtered.rds'))
  pnoc_cnv <- readRDS(file.path(pnoc008_dir, 'pnoc008_cnv_filtered.rds'))
  total_cnv <- rbind(pbta_cnv, pnoc_cnv)
  
  # fusions
  pbta_fusions <- readRDS(file.path(pbta_dir, 'pbta-fusion-putative-oncogenic-filtered.rds'))
  pnoc_fusions <- readRDS(file.path(pnoc008_dir, 'pnoc008_fusions_filtered.rds'))
  total_fusions <- rbind(pbta_fusions, pnoc_fusions)
  
  # merge
  total_alterations <- rbind(total_mutations, total_cnv, total_fusions)
  
  # filter to top 20 genomically similar patients
  total_alterations <- total_alterations %>%
    filter(SampleID %in% combined_clinical$SampleID)
  
  # alterations in genomically similar patients
  total_alt_table1 <- total_alterations %>%
    inner_join(total_alterations %>%
                 dplyr::select(Gene, Kids_First_Biospecimen_ID) %>%
                 unique() %>%
                 group_by(Gene) %>% 
                 summarise(SampleCount = n()), by = c("Gene"))
  
  # at least 5/20 genomically similar patients
  total_alt_table1 <- total_alt_table1 %>%
    filter(SampleCount >= 5)
  
  # overlap with key clinical findings
  key.clinical <- key_clinical_findings_output
  key.genes <- unique(key.clinical$Aberration)
  total_alt_table2 <- total_alterations %>%
    filter(Gene %in% key.genes)
  
  # shared genes that are present in patient of interest + at least 1 more sample
  total_alt_table2 <- total_alt_table2 %>%
    inner_join(total_alt_table2 %>%
                 dplyr::select(Gene, SampleID) %>% 
                 unique() %>%
                 group_by(Gene) %>% 
                 summarise(SampleCount = n()), by = c("Gene")) %>%
    filter(SampleCount != 1)
  
  alt_tables <- list(recurrent_alterations = total_alt_table1, 
                     shared_genes = total_alt_table2)
  return(alt_tables)
}