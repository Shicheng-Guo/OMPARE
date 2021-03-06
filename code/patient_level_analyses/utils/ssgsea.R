# ssGSEA of top 20 genomically similar patients using TPM
suppressPackageStartupMessages(library(msigdbr)) ## Contains the msigDB gene sets
suppressPackageStartupMessages(library(GSVA))    ## Performs GSEA analysis

ssgsea <- function(top_cor, fname) {
  
  if(!file.exists(fname)) {
    expression_data <- top_cor
    human_geneset <- msigdbr::msigdbr(species = "Homo sapiens", category = "C2", subcategory = "CP:REACTOME") ## human REACTOME genes from `migsdbr` package. The loaded data is a tibble.
    
    # Prepare expression data: log2 transform re-cast as matrix
    ### Rownames are genes and column names are samples
    expression_data_log2_matrix <- as.matrix(log2(expression_data + 1))
    
    # Prepare REACTOME genes: Create a list of REACTOME gene sets, each of which is a list of genes
    human_geneset_twocols <- human_geneset %>% dplyr::select(gs_name, human_gene_symbol)
    human_geneset_list    <- base::split(human_geneset_twocols$human_gene_symbol, list(human_geneset_twocols$gs_name))
    
    # We then calculate the Gaussian-distributed scores
    gsea_scores <- GSVA::gsva(expression_data_log2_matrix,
                              human_geneset_list,
                              method = "ssgsea",
                              min.sz = 1, max.sz = 1500,
                              mx.diff = TRUE, ## Setting this argument to TRUE computes Gaussian-distributed scores (bimodal score distribution if FALSE)
                              verbose = FALSE)        
    
    ### Clean scoring into tidy format
    gsea_scores_df <- as.data.frame(gsea_scores) %>%
      rownames_to_column(var = "geneset_name")
    
    #first/last_bs needed for use in gather (we are not on tidyr1.0)
    first_bs <- head(colnames(gsea_scores), n=1)
    last_bs  <- tail(colnames(gsea_scores), n=1)
    
    gsea_scores_df_tidy <- gsea_scores_df %>%
      tidyr::gather(Kids_First_Biospecimen_ID, gsea_score, !!first_bs : !!last_bs) %>%
      dplyr::select(Kids_First_Biospecimen_ID, geneset_name, gsea_score)
    
    # add sample id
    gsea_scores_df_tidy[,"IsSample"] <- ifelse(grepl(sampleInfo$subjectID, gsea_scores_df_tidy$Kids_First_Biospecimen_ID), T, F)
    
    # calculate median score
    gsea_scores_df_tidy <- gsea_scores_df_tidy %>%
      group_by(geneset_name) %>%
      arrange(geneset_name, gsea_score) %>%
      mutate(gsea_score_median = median(gsea_score))
    
    # top 50 pathways
    top50 <- gsea_scores_df_tidy %>%
      filter(IsSample) %>%
      summarise(abs.score = abs(gsea_score - gsea_score_median)) %>%
      arrange(desc(abs.score)) %>%
      slice_head(n = 50)
    gsea_scores_df_tidy <- gsea_scores_df_tidy %>%
      filter(geneset_name %in% top50$geneset_name)
    
    # save output
    write.table(gsea_scores_df_tidy, file = fname, sep = "\t", row.names = F)
  } else {
    gsea_scores_df_tidy <- read.delim(fname, check.names = F)
  }
  
  # factorize by median
  tmp <- gsea_scores_df_tidy %>%
    dplyr::select(geneset_name, gsea_score_median) %>%
    arrange(desc(gsea_score_median)) %>%
    unique() %>%
    .$geneset_name
  gsea_scores_df_tidy$geneset_name <- factor(gsea_scores_df_tidy$geneset_name, levels = tmp)
  
  # plot as boxplot
  p <- ggplot(gsea_scores_df_tidy, aes(geneset_name, gsea_score)) + 
    geom_boxplot(outlier.shape = NA) +  
    theme_bw()
  raw.scoresSample <- gsea_scores_df_tidy[gsea_scores_df_tidy$IsSample == T,]
  p <- p + 
    geom_point(data = raw.scoresSample, aes(geneset_name, gsea_score), colour = "red", size = 3, shape = "triangle") +
    theme(axis.text = element_text(size = 8, face = "bold"), 
          axis.title = element_blank()) + coord_flip() +
    theme(plot.margin = unit(c(1, 5, 1, 2), "cm"))
  return(p)  
}
