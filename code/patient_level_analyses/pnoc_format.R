# Author: Komal S. Rathi
# Function: for all PNOC008 data: 
# create a matrix of expression
# create metadata using clinical files
# create full summary data files of cnv, mutations and fusions
# this is to be run everytime a new patient comes in - before generating the report
# these summary files are required by mutational analysis and oncogrid

suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(readxl))
suppressPackageStartupMessages(library(stringr))
suppressPackageStartupMessages(library(tidyverse))
suppressPackageStartupMessages(library(GenomicRanges))

# directories
root_dir <- rprojroot::find_root(rprojroot::has_dir(".git"))
source(file.path(root_dir, "code", "utils", "define_directories.R"))

# source functions
source(file.path(patient_level_analyses_utils, 'create_copy_number.R'))
source(file.path(patient_level_analyses_utils, 'filter_mutations.R'))

# create output directory
gsea.dir <- file.path(ref_dir, 'gsea')
pnoc008.dir <- file.path(ref_dir, 'pnoc008')

# reference data
# 008 vs gtex brain degs
pnoc008_vs_gtex_brain <- readRDS(file.path(gsea.dir, 'pnoc008_vs_gtex_brain.rds'))

# cancer genes 
cancer_genes <- readRDS(file.path(ref_dir, 'cancer_gene_list.rds'))
gene_list <- unique(cancer_genes$Gene_Symbol)

# chr coordinates to gene symbol map
chr_map <- read.delim(file.path(ref_dir, "mart_export_genechr_mapping.txt"), stringsAsFactors =F)
colnames(chr_map) <- c("hgnc_symbol", "gene_start", "gene_end", "chromosome")

# function to merge files
merge_files <- function(nm){
  sample_name <- gsub(".*PNOC","PNOC",nm)
  sample_name <- gsub('/.*','',sample_name)
  x <- data.table::fread(nm)
  if(nrow(x) > 1){
    x <- as.data.frame(x)
    x$sample_name <- sample_name
    return(x)
  } 
}

# function to merge degs
merge_deg_list <- function(x){
  degs <- x$genes
  degs <- degs %>%
    dplyr::select(genes, diff_expr)
  return(degs)
}

# function to read cnv, filter by cancer genes and merge
# only gain/loss
merge_cnv <- function(cnvData, genelist){
  sample_name <- gsub(".*PNOC", "PNOC", cnvData)
  sample_name <- gsub('/.*', '', sample_name)
  cnvData <- data.table::fread(cnvData, header = T, check.names = T)
  ploidy <- NULL
  
  # wilcoxon pvalue < 0.05
  cnvData <- cnvData %>% 
    dplyr::select(chr, start, end, copy.number, status, WilcoxonRankSumTestPvalue) %>%
    filter(WilcoxonRankSumTestPvalue < 0.05) %>%
    as.data.frame()
  
  # map coordinates to gene symbol
  cnvOut <- create_copy_number(cnvData = cnvData, ploidy = ploidy)
  
  # filter to cancer genes with gain/loss
  cnvOut <- cnvOut %>%
    filter(hgnc_symbol %in% genelist,
           status != "neutral") %>% 
    mutate(sample_name = sample_name) 
  return(cnvOut)
}

# list of all PNOC patients
pnoc008_expr <- list.files(path = results_dir, pattern = "*.genes.results*", recursive = TRUE, full.names = T)
pnoc008_expr <- pnoc008_expr[grep('PNOC008-',  pnoc008_expr)]
pnoc008_expr <- lapply(pnoc008_expr, FUN = function(x) merge_files(x))
pnoc008_expr <- data.table::rbindlist(pnoc008_expr)

# separate gene_id and gene_symbol
pnoc008_expr <- pnoc008_expr %>% 
  mutate(gene_id = str_replace(gene_id, "_PAR_Y_", "_"))  %>%
  separate(gene_id, c("gene_id", "gene_symbol"), sep = "\\_", extra = "merge") %>%
  unique()

# fpkm matrix
pnoc008_fpkm <- pnoc008_expr %>% 
  group_by(sample_name) %>%
  arrange(desc(FPKM)) %>% 
  distinct(gene_symbol, .keep_all = TRUE) %>%
  dplyr::select(gene_symbol, sample_name, FPKM) %>%
  spread(sample_name, FPKM) %>%
  column_to_rownames('gene_symbol')
pnoc008_fpkm <- pnoc008_fpkm[,grep('CHOP', colnames(pnoc008_fpkm), invert = T)]
colnames(pnoc008_fpkm)  <- gsub("-NANT", "", colnames(pnoc008_fpkm))
saveRDS(pnoc008_fpkm, file = file.path(pnoc008.dir, 'pnoc008_fpkm_matrix.rds'))

# uniquify gene_symbol (tpm)
pnoc008_tpm <- pnoc008_expr %>% 
  group_by(sample_name) %>%
  arrange(desc(TPM)) %>% 
  distinct(gene_symbol, .keep_all = TRUE) %>%
  dplyr::select(gene_symbol, sample_name, TPM) %>%
  spread(sample_name, TPM) %>%
  column_to_rownames('gene_symbol')

# only keep NANT sample for PNOC008-5
pnoc008_tpm <- pnoc008_tpm[,grep('CHOP', colnames(pnoc008_tpm), invert = T)]
colnames(pnoc008_tpm)  <- gsub("-NANT", "", colnames(pnoc008_tpm))

# now merge all clinical data for all patients
pnoc008_clinical <- readxl::read_xlsx(file.path(ref_dir, 'manifest' , 'pnoc008_manifest.xlsx'), sheet = 1)
colnames(pnoc008_clinical) <- gsub('[() ]', '.', colnames(pnoc008_clinical))
pnoc008_clinical <- pnoc008_clinical %>%
  filter_all(any_vars(!is.na(.))) %>%
  mutate(PNOC.Subject.ID = gsub('P-','PNOC008-', PNOC.Subject.ID))
pnoc008_clinical <- pnoc008_clinical %>%
  mutate(study_id = "PNOC008",
         KF_ParticipantID = PNOC.Subject.ID,
         subjectID = PNOC.Subject.ID,
         reportDate = Sys.Date(),
         tumorType = Diagnosis.a,
         tumorLocation = Primary.Site.a,
         ethnicity = Ethnicity,
         age_diagnosis_days = Age.at.Diagnosis..in.days.,
         age_collection_days = Age.at.Collection..in.days.,
         sex = Gender) %>%
  dplyr::select(subjectID, KF_ParticipantID, tumorType, tumorLocation, ethnicity, sex, age_diagnosis_days, age_collection_days, study_id, library_name) %>%
  as.data.frame()
rownames(pnoc008_clinical) <- pnoc008_clinical$subjectID

common.pnoc008 <- intersect(rownames(pnoc008_clinical), colnames(pnoc008_tpm))
pnoc008_clinical <- pnoc008_clinical[common.pnoc008,]
pnoc008_tpm <- pnoc008_tpm[,common.pnoc008]

# save expression and clinical
saveRDS(pnoc008_tpm, file = file.path(pnoc008.dir, 'pnoc008_tpm_matrix.rds'))
saveRDS(pnoc008_clinical, file = file.path(pnoc008.dir, "pnoc008_clinical.rds"))

# copy number
pnoc008_cnv <- list.files(path = results_dir, pattern = "*.CNVs.p.value.txt", recursive = TRUE, full.names = T)
pnoc008_cnv <- pnoc008_cnv[grep('PNOC008-',  pnoc008_cnv)]
pnoc008_cnv <- lapply(pnoc008_cnv, FUN = function(x) merge_cnv(cnvData = x, genelist = gene_list))
pnoc008_cnv <- data.table::rbindlist(pnoc008_cnv)
# only keep NANT sample for PNOC008-5
pnoc008_cnv <- pnoc008_cnv[grep('CHOP', pnoc008_cnv$sample_name, invert = T),]
pnoc008_cnv$sample_name  <- gsub("-NANT", "", pnoc008_cnv$sample_name)

pnoc008_cnv <- pnoc008_cnv %>%
  mutate(Gene = hgnc_symbol,
         Alteration_Datatype = "CNV",
         Alteration_Type = stringr::str_to_title(status),
         Alteration = paste0('Copy Number Value:', copy.number),
         Kids_First_Biospecimen_ID = sample_name,
         SampleID = sample_name,
         Study = "PNOC008") %>%
  dplyr::select(Gene, Alteration_Datatype, Alteration_Type, Alteration, Kids_First_Biospecimen_ID, SampleID, Study) %>%
  unique()
saveRDS(pnoc008_cnv, file = file.path(pnoc008.dir, "pnoc008_cnv_filtered.rds"))

# fusions
pnoc008_fusions <- list.files(path = results_dir, pattern = "*.arriba.fusions.tsv", recursive = TRUE, full.names = T)
pnoc008_fusions <- pnoc008_fusions[grep('PNOC008-',  pnoc008_fusions)]
pnoc008_fusions <- lapply(pnoc008_fusions, FUN = function(x) merge_files(x))
pnoc008_fusions <- data.table::rbindlist(pnoc008_fusions)
colnames(pnoc008_fusions)[1] <- "gene1"
# only keep NANT sample for PNOC008-5
pnoc008_fusions <- pnoc008_fusions[grep('CHOP', pnoc008_fusions$sample_name, invert = T),]
pnoc008_fusions$sample_name  <- gsub("-NANT", "", pnoc008_fusions$sample_name)

pnoc008_fusions <- pnoc008_fusions %>%
  separate_rows(gene1, gene2, sep = ",", convert = TRUE) %>%
  mutate(gene1 = gsub('[(].*', '', gene1),
         gene2 = gsub('[(].*',' ', gene2),
         reading_frame = ifelse(reading_frame == ".", "other", reading_frame)) %>%
  mutate(Alteration_Datatype = "Fusion",
         Alteration_Type = stringr::str_to_title(reading_frame),
         Alteration = paste0(gene1, '_',  gene2),
         Kids_First_Biospecimen_ID = sample_name,
         SampleID = sample_name,
         Study = "PNOC008") %>%
  unite(col = "Gene", gene1, gene2, sep = ", ", na.rm = T) %>%
  dplyr::select(Gene, Alteration_Datatype, Alteration_Type, Alteration, Kids_First_Biospecimen_ID, SampleID, Study) %>%
  separate_rows(Gene, convert = TRUE) %>%
  filter(Gene %in% gene_list) %>%
  unique()
saveRDS(pnoc008_fusions, file = file.path(pnoc008.dir, "pnoc008_fusions_filtered.rds"))

# mutations
pnoc008_mutations <- list.files(path = results_dir, pattern = "*consensus_somatic.vep.maf", recursive = TRUE, full.names = T)
pnoc008_mutations <- pnoc008_mutations[grep('PNOC008-',  pnoc008_mutations)]
pnoc008_mutations <- lapply(pnoc008_mutations, FUN = function(x) merge_files(x))
pnoc008_mutations <- data.table::rbindlist(pnoc008_mutations)
# only keep NANT sample for PNOC008-5
pnoc008_mutations <- pnoc008_mutations[grep('CHOP', pnoc008_mutations$sample_name, invert = T),]
pnoc008_mutations$sample_name  <- gsub("-NANT", "", pnoc008_mutations$sample_name)

# filter mutations
pnoc008_mutations <- filter_mutations(myMutData = pnoc008_mutations, myCancerGenes = cancer_genes)
pnoc008_mutations <- pnoc008_mutations %>%
  mutate(Gene = Hugo_Symbol,
         Alteration_Datatype = "Mutation",
         Alteration_Type = Variant_Classification,
         Alteration = HGVSp_Short,
         Kids_First_Biospecimen_ID = sample_name,
         SampleID = sample_name,
         Study = "PNOC008") %>%
  dplyr::select(Gene, Alteration_Datatype, Alteration_Type, Alteration, Kids_First_Biospecimen_ID, SampleID, Study) %>%
  unique()
saveRDS(pnoc008_mutations, file = file.path(pnoc008.dir, "pnoc008_consensus_mutation_filtered.rds"))

# cohort level degs
pnoc008_deg <- sapply(pnoc008_vs_gtex_brain, FUN = function(x) merge_deg_list(x = x), simplify = F, USE.NAMES = T)
pnoc008_deg <- data.table::rbindlist(pnoc008_deg, idcol = 'sample_name', use.names = T)
saveRDS(pnoc008_deg, file = file.path(pnoc008.dir, "pnoc008_vs_gtex_brain_degs.rds"))

# cohort level tmb scores
tmb_bed_file <- data.table::fread(file.path(ref_dir, "xgen-exome-research-panel-targets_hg38_ucsc_liftover.100bp_padded.sort.merged.bed"))
colnames(tmb_bed_file)  <- c("chr", "start", "end")

# read mutect2 for TMB profile
pnoc008_mutect2 <- list.files(path = results_dir, pattern = 'mutect2_somatic.vep.maf', recursive = TRUE, full.names = T)
pnoc008_mutect2 <- pnoc008_mutect2[grep('PNOC008-',  pnoc008_mutect2)]
pnoc008_mutect2 <- lapply(pnoc008_mutect2, FUN = function(x) merge_files(x))
pnoc008_mutect2 <- data.table::rbindlist(pnoc008_mutect2, fill = T)
# only keep NANT sample for PNOC008-5
pnoc008_mutect2 <- pnoc008_mutect2[grep('CHOP', pnoc008_mutect2$sample_name, invert = T),]
pnoc008_mutect2$sample_name  <- gsub("-NANT", "", pnoc008_mutect2$sample_name)

# mutect2 nonsense and missense mutations
pnoc008_mutect2 <- pnoc008_mutect2 %>%
  filter(Variant_Classification %in% c("Missense_Mutation", "Nonsense_Mutation")) %>%
  dplyr::select(sample_name, Hugo_Symbol, Variant_Classification, Chromosome, Start_Position, End_Position) %>%
  unique()
  
# intersect with bed file
subject <- with(tmb_bed_file, GRanges(chr, IRanges(start = start, end = end)))
query <- with(pnoc008_mutect2, GRanges(Chromosome, IRanges(start = Start_Position, end = End_Position, names = Hugo_Symbol)))
pnoc008_tmb <- findOverlaps(query = query, subject = subject, type = "within")
pnoc008_tmb <- data.frame(pnoc008_mutect2[queryHits(pnoc008_tmb),], tmb_bed_file[subjectHits(pnoc008_tmb),])
  
# return the number of missense + nonsense overlapping with the bed file/77.46
pnoc008_tmb <- pnoc008_tmb %>%
  group_by(sample_name) %>%
  mutate(num.mis.non = n()) %>%
  dplyr::select(sample_name, num.mis.non)  %>%
  unique() %>%
  mutate(tmb = num.mis.non/77.46) %>%
  dplyr::select(sample_name, tmb)
saveRDS(pnoc008_tmb, file = file.path(pnoc008.dir, "pnoc008_tmb_scores.rds"))



