# Import libraries
libraries <- c("tidyverse", "adegenet", "vcfR", "readxl", "ggforce", "ggh4x")
if (!require("pacman")) install.packages("pacman")
pacman::p_load(charaters = libraries, character.only = TRUE)
rm(libraries)
if (!require("patchwork")) devtools::install_github("thomasp85/patchwork")

################## Useful functions  ##################
source("../General_scripts/Functions_optimise_plot_clines.r")

################################ Useful variables ################################
# Color palette to be reused everywhere with the shell size
size_palette = c("#4e79a7", "grey75", "#f28e2b")
# Basic theme to use in the graphs
my_theme <- theme_bw() +
  theme(text = element_text(size = 20))

################## Import the vcf file  ##################
data <- read.vcfR("../../Output/Sweden_France_parallelism/02_Filter_VCF/09_Maf_thin/VCF_File.vcf.gz") %>% 
  vcfR2genind()

# We add the poputations to the vcf object
data@pop <- (data@tab %>% rownames %>% str_split_fixed(., "_", 4))[, 3] %>% as.factor
data@other$exposition <- (data@tab %>% rownames %>% str_split_fixed(., "_", 6))[, 5] %>% as.factor
data@other$exposition[which(data@other$exposition == "TRANSI")] <- "TRANS" %>% as.factor
data@other$exposition <- data@other$exposition %>% droplevels()


############################ PCA on whole genome ##########################

# Scale the genome to get rid of missing data
pca <- scaleGen(data, NA.method="mean", scale=FALSE, center=TRUE) %>% 
  # And run the pca
  dudi.pca(scale=TRUE, nf=5, scannf=FALSE)

################## Import the metadata  ##################
metadata <- read_excel(path = "../Input_Data/Data/data_Fabalis_resequencing_Basile.xlsx",
                       sheet = 1,
                       col_names = TRUE,
                       trim_ws = TRUE) %>%
  
  # Convert to the correct formats
  mutate(Population = as.factor(Population),
         Shell_colour = factor(Shell.colour %>% str_to_title, levels = c("Black", "Black/Square", "Brown", "Brown/Square", "Dark", "Yellow", "Yellow/Brown", "Yellow/Square", "Grey", "White", "Banded", NA)),
         LCmeanDist = as.numeric(LCmeanDist),
         Length = as.numeric(length),
         Habitat = ifelse(Habitat %in% c("EXPOS"), "Exposed", Habitat),
         Habitat = ifelse(Habitat %in% c("HARB", "SHELT"), "Sheltered", Habitat),
         Habitat = ifelse(Habitat %in% c("TRANS", "TRANSI"), "Transition", Habitat),
         Habitat = as.factor(Habitat)
  ) %>%
  
  # Select only the necessary columns for the analysis
  select(-length) %>% 

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

################## Making the delta frequencies correlation plot  ##################
Delta_freqs_whole_genome <- get_delta_freqs_and_F4(
  genetic_data = data,
  Extreme_values = pca$li,
  var = "Axis2",
  meta_data = metadata
) %>% 
  left_join(pca$co %>% 
              rownames_to_column("Position"),
            by = "Position")

# Delta freqs colored by PC2
delta_PC2 <- Delta_freqs_whole_genome %>%
  ggplot() +
  geom_point(aes(Delta_freq_France, Delta_freq_Sweden, color = Comp2 %>% abs), alpha = 0.1, size = 3) +
  scale_color_gradientn(name = "Contribution to PC2\n(absolute value)",
                        colors = c("olivedrab4", "#f28e2b", "brown4"), 
                        limits = c(min(pca$co$Comp2 %>% abs, na.rm=TRUE) - 0.01, 
                                 max(pca$co$Comp2 %>% abs, na.rm=TRUE) + 0.01),
                        breaks = c(0.025, 0.5, 0.75)) +
  labs(x = expression(Delta * "freq_France"),
       y = expression(Delta * "freq_Sweden"),
       tag = "(A)") +
  my_theme

# Delta freqs colored by PC3
delta_PC3 <- Delta_freqs_whole_genome %>%
  ggplot() +
  geom_point(aes(Delta_freq_France, Delta_freq_Sweden, color = Comp3 %>% abs), alpha = 0.1, size = 3) +
  scale_color_gradientn(name = "Contribution to PC3\n(absolute value)",
                        colors = c("deepskyblue", "deeppink", "darkred"), 
                        limits = c(min(pca$co$Comp3 %>% abs, na.rm=TRUE) - 0.01, 
                                   max(pca$co$Comp3 %>% abs, na.rm=TRUE) + 0.01),
                        breaks = c(0.05, 0.5, 1)) +
  labs(x = expression(Delta * "freq_France"),
       y = expression(Delta * "freq_Sweden"),
       tag = "(B)") +
  my_theme


delta_PC2 + delta_PC3 +
  plot_layout(guides = "collect")


