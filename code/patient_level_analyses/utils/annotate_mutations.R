# annotate mutations vs vus

annotate_mutations <- function(myMutData = mutData, myCancerGenes = cancerGenes, cancer_hotspots = cancer_hotspots_v2) {

  # variant classification filters
  keepVC <- c("Nonsense_Mutation", "Missense_Mutation", 
              "Splice_Region", "Splice_Site",
              "3'UTR", "5'UTR", 
              "In_Frame_Ins", "In_Frame_Del",
              "Frame_Shift_Ins", "Frame_Shift_Del")
  
  # impact filters
  keepVI <- c("MODIFIER", "MODERATE", "HIGH")
  
  # gene to annotation mutation vs vus
  myCancerGenes <- as.character(myCancerGenes$Gene_Symbol)
  
  # filter by biotype, variant class, impact 
  mutDataFilt <- mutData %>%
    filter(BIOTYPE == "protein_coding" &
             Variant_Classification %in% keepVC &
             IMPACT %in% keepVI) 
  
  # annotate by cancer gene list, TERT promoter and cancer hotspots
  # TERT is chr5:1253167-5:1295047 on negative strand
  mutDataFilt <- mutDataFilt %>%
    mutate(Type = ifelse(Hugo_Symbol %in% myCancerGenes, "Mutation", "VUS")) %>%
    mutate(tert_promoter_mutations = ifelse(Chromosome == "chr5" & Start_Position >= 1295047 & End_Position <= 1595047, yes = "TERT_Promoter_Mutation", NA),
           cancer_hotspots = ifelse(Hugo_Symbol %in% cancer_hotspots$Hugo_Symbol &
                                      Chromosome %in%  cancer_hotspots$Chromosome &
                                      Start_Position %in% cancer_hotspots$Start_Position &
                                      End_Position %in% cancer_hotspots$End_Position &
                                      Variant_Classification %in% cancer_hotspots$Variant_Classification &
                                      HGVSp %in% cancer_hotspots$HGVSp &
                                      HGVSp_Short %in% cancer_hotspots$HGVSp_Short, yes = "Cancer_Hotspot_Mutation", NA)) %>%
    rowwise() %>%
    mutate(Type = toString(na.omit(Type, tert_promoter_mutations, cancer_hotspots)))

  return(mutDataFilt)
}
