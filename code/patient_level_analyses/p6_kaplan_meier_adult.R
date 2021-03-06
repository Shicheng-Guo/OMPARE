# directories
root_dir <- rprojroot::find_root(rprojroot::has_dir(".git"))
source(file.path(root_dir, "code", "utils", "define_directories.R"))

# source functions
source(file.path(patient_level_analyses_utils, 'kaplan_meier.R'))

# recurrent alterations
kaplan_meier_adult <- kaplan_meier(all_cor = tcga_gbm_pnoc008_nn_table, 
                                   surv_data = tcga_gbm_survival)

# save output
saveRDS(kaplan_meier_adult, file = file.path(topDir, "output", "kaplan_meier_adult.rds"))
