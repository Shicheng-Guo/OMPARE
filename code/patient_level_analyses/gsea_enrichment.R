# Author: Komal S. Rathi
# Date: 04/25/2020
# Function: Up/Down pathways for each PBTA sample, compare to rest of PBTA (1) and GTEx (2) and TCGA GBM (3) and PNOC008 (4)
# do this once and read in for tabulate pathways (Page 8 of report)

# Function to return all results from RNA-Seq Analysis
suppressPackageStartupMessages(library(tidyverse))
suppressPackageStartupMessages(library(GSEABase))
suppressPackageStartupMessages(library(reshape2))
suppressPackageStartupMessages(library(doMC))
registerDoMC(cores = 4)

# directories
root_dir <- rprojroot::find_root(rprojroot::has_dir(".git"))
source(file.path(root_dir, "code", "utils", "define_directories.R"))

# source function for RNA-seq diffexpr & pathway analysis
source(file.path(patient_level_analyses_utils, "rnaseq_analysis_accessory.R"))

# Dataset1: GTex Brain
gtex_brain_clinical <- readRDS(file.path(ref_dir, 'gtex', 'gtex_brain_clinical.rds'))
gtex_brain_tpm <- readRDS(file.path(ref_dir, "gtex", "gtex_brain_tpm.rds"))
gtex_brain_tpm <- gtex_brain_tpm[grep("^HIST", rownames(gtex_brain_tpm), invert = T),]

# Dataset2: TCGA GBM
tcga_gbm_clinical <- readRDS(file.path(ref_dir, 'tcga', 'tcga_gbm_clinical.rds'))
tcga_gbm_tpm <- readRDS(file.path(ref_dir, 'tcga', 'tcga_gbm_tpm_matrix.rds'))
tcga_gbm_tpm <- tcga_gbm_tpm[grep("^HIST", rownames(tcga_gbm_tpm), invert = T),]

# Dataset3: PBTA (polyA + corrected stranded n = 1028)
# clinical
pbta_clinical <- read.delim(file.path(ref_dir, 'pbta', 'pbta-histologies.tsv'), stringsAsFactors = F)
pbta_clinical <- pbta_clinical %>%
  filter(experimental_strategy == "RNA-Seq",
         short_histology == "HGAT")

# expression  (polyA + stranded combined TPM data collapsed to gene symbols)
pbta_full_tpm <- readRDS(file.path(ref_dir, 'pbta','pbta-gene-expression-rsem-tpm-collapsed.polya.stranded.rds'))
pbta_full_tpm <- pbta_full_tpm[grep("^HIST", rownames(pbta_full_tpm), invert = T),]

# Dataset4: PBTA (polyA + corrected stranded HGG n = 186)
pbta_hgg_tpm <- pbta_full_tpm[,colnames(pbta_full_tpm) %in% pbta_clinical$Kids_First_Biospecimen_ID]

# Dataset5: PNOC008
pnoc008_tpm <- readRDS(file.path(ref_dir, 'pnoc008', 'pnoc008_tpm_matrix.rds'))
pnoc008_tpm <- pnoc008_tpm[grep("^HIST", rownames(pnoc008_tpm), invert = T),]

# Cancer Genes
cancer_genes <- readRDS(file.path(ref_dir, 'cancer_gene_list.rds'))

# Genesets (c2 reactome)
gene_set <- getGmt(file.path(ref_dir, 'msigdb', 'c2.cp.reactome.v6.0.symbols.gmt'), collectionType = BroadCollection(), geneIdType = SymbolIdentifier())
gene_set <- geneIds(gene_set)

# input data
pbta_full_tpm_melt <- melt(as.matrix(pbta_full_tpm), value.name = "TPM", varnames = c("Gene", "Sample"))
tcga_gbm_tpm_melt <- melt(as.matrix(tcga_gbm_tpm), value.name = "TPM", varnames = c("Gene", "Sample"))
pnoc008_tpm_melt <- melt(as.matrix(pnoc008_tpm), value.name = "TPM", varnames = c("Gene", "Sample"))

# create output directory
gsea.dir <- file.path(ref_dir, 'gsea')
dir.create(gsea.dir, showWarnings = F, recursive = T)

# overwrite pnoc008 comparisons with addition of each new patient
# pnoc008 vs gtex brain
pnoc008_vs_gtex_brain <-  plyr::dlply(pnoc008_tpm_melt, .variables = "Sample", .fun = function(x) run_rnaseq_analysis(exp.data = x, refData = gtex_brain_tpm, gene_set = gene_set, comparison = paste0("GTExBrain_", ncol(gtex_brain_tpm))), .parallel = TRUE)
saveRDS(pnoc008_vs_gtex_brain, file = file.path(ref_dir, 'gsea', 'pnoc008_vs_gtex_brain.rds'))

# pnoc008 vs pbta
pnoc008_vs_pbta <- plyr::dlply(pnoc008_tpm_melt, .variables = "Sample", .fun = function(x) run_rnaseq_analysis(exp.data = x, refData = pbta_full_tpm, gene_set = gene_set, comparison = paste0("PBTA_All_", ncol(pbta_full_tpm))), .parallel = TRUE)
saveRDS(pnoc008_vs_pbta, file = file.path(ref_dir, 'gsea', 'pnoc008_vs_pbta.rds'))

# pnoc008 vs pbta hgg
pnoc008_vs_pbta_hgg <- plyr::dlply(pnoc008_tpm_melt, .variables = "Sample", .fun = function(x) run_rnaseq_analysis(exp.data = x, refData = pbta_hgg_tpm, gene_set = gene_set, comparison = paste0("PBTA_HGG_", ncol(pbta_hgg_tpm))), .parallel = TRUE)
saveRDS(pnoc008_vs_pbta_hgg, file = file.path(ref_dir, 'gsea', 'pnoc008_vs_pbta_hgg.rds'))

# pnoc008 vs tcga gbm
pnoc008_vs_tcga_gbm <- plyr::dlply(pnoc008_tpm_melt, .variables = "Sample", .fun = function(x) run_rnaseq_analysis(exp.data = x, refData = tcga_gbm_tpm, gene_set = gene_set, comparison = paste0("TCGA_GBM_", ncol(tcga_gbm_tpm))), .parallel = TRUE)
saveRDS(pnoc008_vs_tcga_gbm, file = file.path(ref_dir, 'gsea', 'pnoc008_vs_tcga_gbm.rds'))

# pbta comparisons only need to be run once
# pbta vs gtex brain
fname <- file.path(ref_dir, 'gsea', 'pbta_vs_gtex_brain.rds')
if(!file.exists(fname)){
  pbta_vs_gtex_brain <-  plyr::dlply(pbta_full_tpm_melt, .variables = "Sample", .fun = function(x) run_rnaseq_analysis(exp.data = x, refData = gtex_brain_tpm, gene_set = gene_set, comparison = paste0("GTExBrain_", ncol(gtex_brain_tpm))), .parallel = TRUE)
  saveRDS(pbta_vs_gtex_brain, file = fname)
}

# pbta vs pbta
fname <- file.path(ref_dir, 'gsea', 'pbta_vs_pbta.rds')
if(!file.exists(fname)){
  pbta_vs_pbta <- plyr::dlply(pbta_full_tpm_melt, .variables = "Sample", .fun = function(x) run_rnaseq_analysis(exp.data = x, refData = pbta_full_tpm, gene_set = gene_set, comparison = paste0("PBTA_All_", ncol(pbta_full_tpm))), .parallel = TRUE)
  saveRDS(pbta_vs_pbta, file = fname)
}

# pbta vs pbta hgg
fname <- file.path(ref_dir, 'gsea', 'pbta_vs_pbta_hgg.rds')
if(!file.exists(fname)){
  pbta_vs_pbta_hgg <- plyr::dlply(pbta_full_tpm_melt, .variables = "Sample", .fun = function(x) run_rnaseq_analysis(exp.data = x, refData = pbta_hgg_tpm, gene_set = gene_set, comparison = paste0("PBTA_HGG_", ncol(pbta_hgg_tpm))), .parallel = TRUE)
  saveRDS(pbta_vs_pbta_hgg, file = fname)
}

# tcga comparisons only need to be run once
# tcga gbm vs gtex brain
fname <- file.path(ref_dir, 'gsea', 'tcga_gbm_vs_gtex_brain.rds')
if(!file.exists(fname)){
  tcga_gbm_vs_gtex_brain <-  plyr::dlply(tcga_gbm_tpm_melt, .variables = "Sample", .fun = function(x) run_rnaseq_analysis(exp.data = x, refData = gtex_brain_tpm, gene_set = gene_set, comparison = paste0("GTExBrain_", ncol(gtex_brain_tpm))), .parallel = TRUE)
  saveRDS(tcga_gbm_vs_gtex_brain, file = fname)
}

# tcga gbm vs tcga gbm
fname <- file.path(ref_dir, 'gsea', 'tcga_gbm_vs_tcga_gbm.rds')
if(!file.exists(fname)){
  tcga_gbm_vs_tcga_gbm <-  plyr::dlply(tcga_gbm_tpm_melt, .variables = "Sample", .fun = function(x) run_rnaseq_analysis(exp.data = x, refData = tcga_gbm_tpm, gene_set = gene_set, comparison = paste0("TCGA_GBM_", ncol(tcga_gbm_tpm))), .parallel = TRUE)
  saveRDS(tcga_gbm_vs_tcga_gbm, file = fname)
}
