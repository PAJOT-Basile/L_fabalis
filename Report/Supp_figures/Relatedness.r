# Import libraries
require("anyLib")
anyLib(c("tidyverse", "readxl", "ggforce", "reshape2", "ggh4x", "patchwork"))

################################ Useful variables ################################
# Basic theme to use in the graphs
my_theme <- theme_bw() +
  theme(text = element_text(size = 20))

################## Import the metadata  ##################
metadata <- read_excel(path = "/shared/projects/pacobar/finalresult/bpajot/Data/data_Fabalis_resequencing_Basile.xlsx",
                       sheet = 1,
                       col_names = TRUE,
                       trim_ws = TRUE) %>%
  
  # Convert to the correct formats
  mutate(Species = as.factor(Species),
         ID_number = as.factor(ID_number),
         Population = as.factor(Population),
         Transect = as.factor(TRANSECT),
         Id = as.factor(ID),
         Shell_colour = factor(Shell.colour %>% str_to_title, levels = c("Black", "Black/Square", "Brown", "Brown/Square", "Dark", "Yellow", "Yellow/Brown", "Yellow/Square", "Grey", "White", "Banded", NA)),
         LCmeanDist = as.numeric(LCmeanDist),
         Mreads = as.numeric(Mreads),
         Gbp = as.numeric(Gbp),
         Q30 = as.numeric(Q30),
         x = as.numeric(x),
         y = as.numeric(y),
         Length = as.numeric(length),
         Bi_size = as.factor(biSIZE %>% str_to_title),
         Habitat = ifelse(Habitat %in% c("EXPOS"), "Exposed", Habitat),
         Habitat = ifelse(Habitat %in% c("HARB", "SHELT"), "Sheltered", Habitat),
         Habitat = ifelse(Habitat %in% c("TRANS", "TRANSI"), "Transition", Habitat),
         Habitat = as.factor(Habitat)
  ) %>%
  
  # Select only the necessary columns for the analysis
  select(-c(length, biSIZE, Shell.colour, ID, TRANSECT)) %>% 
  
  # select only the data we need (the one on fabalis just in the transects from LAM and LOKn)
  filter(Species == "FAB",
         Population != "BRE",
         Transect == "n") %>% 
  
  # Modify the population column to get only the name of the country
  mutate(Population = ifelse(Population == "LOK", "Sweden", "France") %>% 
           factor(levels = c("Sweden", "France"))) %>% 
  # Drop unused levels
  droplevels %>% 
  # Change the color information to have it into two simple colors: yellow or brown
  mutate(Shell_color_naive = (Shell_colour %>% str_split_fixed(., "/", 2))[, 1],
         Shell_color_morphology = (Shell_colour %>% str_split_fixed(., "/", 2))[, 2],
         Shell_color_naive = ifelse(Shell_color_naive %in% c("Yellow", "White", "Grey"), "Yellow", Shell_color_naive),
         Shell_color_morphology = ifelse(Shell_color_naive == "Banded", "Banded", Shell_color_morphology),
         Shell_color_naive = ifelse(Shell_color_naive %in% c("Black", "Brown", "Dark"), "Brown", Shell_color_naive),
         Shell_color_naive = ifelse(Shell_color_naive == "Banded", "Brown", Shell_color_naive),
         Shell_color_naive = Shell_color_naive %>% factor(levels = c("Yellow", "Brown")),
         Shell_color_morphology = ifelse(! Shell_color_morphology %in% c("Banded", "Square"), "Uniform", "Banded"))


################## Scaled relatedness matrix (calculated from vcftools)  ##################
## France
relatedness_france <- read.table("/shared/projects/pacobar/finalresult/bpajot/genomic_analysis/scripts/01_Filtering_stats_vcf/GWAS/French_relatedness.relatedness", header = TRUE) %>% 
  rename(Relatedness = RELATEDNESS_AJK) %>% 
  pivot_wider(names_from = INDV2, values_from = Relatedness) %>% 
  column_to_rownames("INDV1")

## Sweden
relatedness_sweden <- read.table("/shared/projects/pacobar/finalresult/bpajot/genomic_analysis/scripts/01_Filtering_stats_vcf/GWAS/Swedish_relatedness.relatedness", header = TRUE) %>% 
  rename(Relatedness = RELATEDNESS_AJK) %>% 
  pivot_wider(names_from = INDV2, values_from = Relatedness) %>% 
  column_to_rownames("INDV1")

# The matrix is not symmetrical but triangular, so, we make it symmetrical by hand
## France
for (i in 1:nrow(relatedness_france)){
  for (j in 1:ncol(relatedness_france)){
    if (i == j){
      relatedness_france[i, j] <- 1
    }else if (relatedness_france[i, j] %>% is.na){
      relatedness_france[i, j] <- relatedness_france[j, i]
    }
  }
}

## Sweden
for (i in 1:nrow(relatedness_sweden)){
  for (j in 1:ncol(relatedness_sweden)){
    if (i == j){
      relatedness_sweden[i, j] <- 1
    }else if (relatedness_sweden[i, j] %>% is.na){
      relatedness_sweden[i, j] <- relatedness_sweden[j, i]
    }
  }
}

# Now, we scale the matrix to only have a positive relatedness between 0 and 1
## France
min_rel_france <- relatedness_france %>% min
max_rel_france <- relatedness_france %>% max
kin_france <- relatedness_france %>% 
  mutate(across(everything(), .fns = function(x) (x + abs(min_rel_france)) / (max_rel_france - min_rel_france))) %>% 
  as.matrix

## Sweden
min_rel_sweden <- relatedness_sweden %>% min
max_rel_sweden <- relatedness_sweden %>% max
kin_sweden <- relatedness_sweden %>% 
  mutate(across(everything(), .fns = function(x) (x + abs(min_rel_sweden)) / (max_rel_sweden - min_rel_sweden))) %>% 
  as.matrix

################## Transform data and plot it  ##################
# First order the individuals to use
## France
ordered_sample_names_france <- metadata %>% 
  filter(Population == "France") %>% 
  arrange(LCmeanDist) %>% 
  select(Sample_Name) %>% 
  as.vector %>% unlist %>% unname

## Sweden
ordered_sample_names_sweden <- metadata %>% 
  filter(Population == "Sweden") %>% 
  arrange(LCmeanDist) %>% 
  select(Sample_Name) %>% 
  as.vector %>% unlist %>% unname

# Now transform and plot the results
kin_france %>% 
  as.data.frame %>% 
  rownames_to_column("Sample_Name") %>% 
  gather(key = "Sample_dup", value = "kinship", -Sample_Name) %>% 
  mutate(Sample_Name = Sample_Name %>% 
           factor(levels = ordered_sample_names_france),
         Sample_dup = Sample_dup %>% 
           factor(levels = ordered_sample_names_france),
         Population = "France") %>%
  rbind(kin_sweden %>% 
          as.data.frame %>% 
          rownames_to_column("Sample_Name") %>% 
          gather(key = "Sample_dup", value = "kinship", -Sample_Name) %>% 
          mutate(Sample_Name = Sample_Name %>% 
                   factor(levels = ordered_sample_names_sweden),
                 Sample_dup = Sample_dup %>% 
                   factor(levels = ordered_sample_names_sweden),
                 Population = "Sweden")) %>% 
  mutate(Population = ifelse(Population == "Sweden", "Suède", "France") %>% 
           factor(levels = c("Suède", "France")),
         analysis = "relat" %>% 
           factor(levels = "relat", "habitat")) %>% 
  ggplot() +
  geom_tile(aes(x=Sample_Name, y = Sample_dup, fill = kinship)) +
  scale_fill_gradientn(colors = c("moccasin", "darkgoldenrod1", "orange", "darkred")) +
  facet_row(vars(Population), scales = "free") +
  labs(x = "",
       y = "") +
  my_theme +
  theme(legend.position = "none",
        axis.text = element_blank(),
        axis.ticks = element_blank())



############# Test
plot <- kin_france %>% 
  as.data.frame %>% 
  rownames_to_column("Sample_Name") %>% 
  gather(key = "Sample_dup", value = "kinship", -Sample_Name) %>% 
  mutate(Sample_Name = Sample_Name %>% 
           factor(levels = ordered_sample_names_france),
         Sample_dup = Sample_dup %>% 
           factor(levels = ordered_sample_names_france),
         Population = "France") %>%
  rbind(kin_sweden %>% 
          as.data.frame %>% 
          rownames_to_column("Sample_Name") %>% 
          gather(key = "Sample_dup", value = "kinship", -Sample_Name) %>% 
          mutate(Sample_Name = Sample_Name %>% 
                   factor(levels = ordered_sample_names_sweden),
                 Sample_dup = Sample_dup %>% 
                   factor(levels = ordered_sample_names_sweden),
                 Population = "Sweden")) %>% 
  mutate(Population = ifelse(Population == "Sweden", "Suède", "France") %>% 
           factor(levels = c("Suède", "France")),
         analysis = "relat" %>% 
           factor(levels = "relat", "habitat")) %>% 
  ggplot() +
  geom_tile(aes(x=Sample_Name, y = Sample_dup, fill = kinship)) +
  scale_fill_gradientn(colors = c("moccasin", "darkgoldenrod1", "orange", "darkred")) +
  facet_row(vars(Population), scales = "free") +
  labs(x = "",
       y = "") +
  my_theme +
  theme(legend.position = "none",
        axis.text = element_blank(),
        axis.ticks = element_blank())

plot2 <- metadata %>% 
  mutate(Population = ifelse(Population == "Sweden", "Suède", "France") %>% 
           factor(levels = c("Suède", "France")),
         Habitat = ifelse(Habitat == "Sheltered", "Abrité", ifelse(Habitat == "Exposed", "Exposé", "Transition")) %>% 
           factor(levels = c("Exposé", "Transition", "Abrité")),
         Sample_Name = Sample_Name %>% 
           factor(levels = c(ordered_sample_names_france, ordered_sample_names_sweden))) %>% 
  ggplot() +
  geom_point(aes(x = Sample_Name, y = Length, color = Habitat)) +
  scale_color_manual(name = "Habitat",
                     values = c("Exposé" = "orange2", "Transition" = "deeppink", "Abrité" = "dodgerblue3")) +
  facet_row(vars(Population), scales = "free_x") +
  my_theme +
  theme(axis.text.x = element_blank(),
        axis.ticks.x = element_blank()) +
  labs(x = "Échantillon",
       y = "Taille")

plot / plot2 + plot_layout(guides = "collect")
  
