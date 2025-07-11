
# Stage 1 - load data and packages: ------------------------------
library(WDI)
library(tidyverse)
use_cache <- T
most_recent_year_with_data <- 2024

# Load WDI data:
if(!use_cache){
  wdi_dat <- WDI(country = c('all'),
              indicator = c('pop' = 'SP.POP.TOTL',
                            'labor_force' = 'SL.TLF.TOTL.IN',
                            'gdp_ppp_c' = 'NY.GDP.MKTP.PP.KD',
                            'gdp_ppp' = 'NY.GDP.MKTP.PP.CD',
                            'gdp' = 'NY.GDP.MKTP.CD',
                            'gdp_c'= 'NY.GDP.MKTP.KD',
                            'unemployment_r' = 'SL.UEM.TOTL.ZS',
                            'pop_over_65' = 'SP.POP.65UP.TO.ZS'),
              start = 1980)
  
  # For a small number of countries, the most recent (currently 2023) data remains missing. For these, we manually added data using estimated growth rates (from the IMF https://www.imf.org/external/datamapper/NGDP_RPCH@WEO/PER), where available:
  missing_gdp_countries <- intersect(wdi_dat$country[is.na(wdi_dat$gdp) & wdi_dat$year == most_recent_year_with_data],
                                 wdi_dat$country[!is.na(wdi_dat$gdp) & wdi_dat$year == most_recent_year_with_data-1])
  
  # For posterity, these countries were:
  # missing_gdp_countries 
  # [1] "Afghanistan"          "Aruba"                "Bhutan"               "Cayman Islands"       "Channel Islands"     
  # [6] "Curacao"              "Faroe Islands"        "French Polynesia"     "Greenland"            "Korea, Rep."         
  # [11] "Lebanon"              "Liechtenstein"        "Monaco"               "Palau"                "Syrian Arab Republic"
  # [16] "Tonga"                "Tuvalu"
  
  missing_gdp <- data.frame(country = missing_gdp_countries,
                            gdp_growth = c(NA, # Afghanistan
                                           2.2, # Aruba
                                           7, # Bhutan
                                           NA, # Cayman Islands
                                           NA, # Channel Islands
                                           NA, # Curacao
                                           NA, # Faroe Islands
                                           NA, # French Polynesia
                                           NA, # Greenland
                                           1, # Korea, Rep.
                                           NA, # Lebanon
                                           NA, # Liechtenstein
                                           NA, # Monaco
                                           5.7, # Palau
                                           NA, # Syrian Arab Republic
                                           2.7, # Tonga
                                           2.8 # Tuvalu
                                           ))
  
  for(i in missing_gdp$country){
    for(j in c('gdp', 'gdp_c', 'gdp_ppp_c', 'gdp_ppp')){
      if(is.na(wdi_dat[wdi_dat$country == i & wdi_dat$year == max(wdi_dat$year, na.rm = T), j])){
        wdi_dat[wdi_dat$country == i & wdi_dat$year == max(wdi_dat$year, na.rm = T), j] <- wdi_dat[wdi_dat$country == i & wdi_dat$year == max(wdi_dat$year, na.rm = T) - 1, j]*(1+missing_gdp$gdp_growth[missing_gdp$country == i]/100)
        }
      }
  }
  write_csv(wdi_dat, 'source-data/wdi_cache.csv')
  
  }
wdi_dat <- read_csv('source-data/wdi_cache.csv')

# Get OECD data:
# devtools::install_github("expersso/OECD")
library(OECD)

# Get working-age population
# https://data-explorer.oecd.org/vis?lc=en&fs[0]=Topic%2C1%7CSociety%23SOC%23%7CDemography%23SOC_DEM%23&pg=0&fc=Topic&bp=true&snb=2&df[ds]=dsDisseminateFinalDMZ&df[id]=DSD_POPULATION%40DF_POP_HIST&df[ag]=OECD.ELS.SAE&df[vs]=1.0&dq=..PT_POP._T.Y15T64.&pd=1950%2C2024&to[TIME_PERIOD]=false
working_age_pop <- get_dataset(
     dataset = "OECD.ELS.SAE,DSD_POPULATION@DF_POP_HIST,1.0",
     filter = "..PT_POP._T.Y15T64.",
     start_time = 1950,
     end_time = 2024,
     pre_formatted = TRUE) %>% 
  mutate(
    year = as.numeric(TIME_PERIOD),
    iso3c = REF_AREA,
    working_age_pop_pct = as.numeric(ObsValue)) %>% 
  select(year, iso3c, working_age_pop_pct) %>% na.omit() %>% unique()
write_csv(working_age_pop, 'source-data/working_age_pop_oecd_2025.csv')
wdi_dat <- merge(wdi_dat, working_age_pop, all.x = T)

# Data from 2024 update, for reference:
#oecd <- read_csv('source-data/working_age_pop_oecd.csv')
# library(countrycode)
# oecd$iso3c <- oecd$LOCATION
# oecd <- na.omit(oecd[, c('TIME', 'iso3c', 'Value')])
# colnames(oecd) <- c('year', 'iso3c', 'working_age_pop_pct')
# wdi_dat <- merge(wdi_dat, oecd, all.x = T)

# Get employment rate
employment_rate <- get_dataset(
  dataset = "DSD_LFS@DF_IALFS_EMP_WAP_Q",
  filter = ".EMP_WAP.._Z.Y._T.Y15T64..A",
  start_time = 1950,
  end_time = 2024,
  pre_formatted = TRUE) %>%
  mutate(year = as.numeric(TIME_PERIOD),
         employment_rate = as.numeric(ObsValue),
         iso3c = REF_AREA) %>%
  select(year, iso3c, employment_rate) %>% unique()
write_csv(employment_rate, 'source-data/employment_rate_oecd_2025.csv')
wdi_dat <- merge(wdi_dat, employment_rate, all.x = T)

# Data from 2024 update, for reference:
# oecd <- read_csv('source-data/employment_rate_oecd.csv')
# oecd <- oecd[oecd$SUBJECT == 'TOT' &  oecd$MEASURE == "PC_WKGPOP" & oecd$FREQUENCY == 'A', ]
# library(countrycode)
# oecd$iso3c <- oecd$LOCATION
# oecd <- na.omit(oecd[, c('TIME', 'iso3c', 'Value')])
# colnames(oecd) <- c('year', 'iso3c', 'employment_rate')
# wdi_dat <- merge(wdi_dat, oecd, all.x = T)

# Get hours worked
hours_worked <- get_dataset(
  dataset = "OECD.ELS.SAE/DSD_HW@DF_AVG_ANN_HRS_WKD/1.0",
  start_time = 1950,
  end_time = 2024,
  pre_formatted = TRUE) %>%
  filter(WORKER_STATUS == '_T') %>%
  mutate(year=TIME_PERIOD,
         hours_worked = as.numeric(ObsValue),
         iso3c = REF_AREA) %>%
  select(year, hours_worked, iso3c) %>% unique()
write_csv(hours_worked, 'source-data/hours_worked_alternative_oecd_2025.csv')
wdi_dat <- merge(wdi_dat, hours_worked, all.x = T)

# Data from 2024 update. New data on the site turns out not to be consisten:
# oecd <- read_csv('source-data/hours_worked_oecd.csv')
# library(countrycode)
# oecd$iso3c <- oecd$LOCATION
# oecd <- na.omit(oecd[, c('TIME', 'iso3c', 'Value')])
# colnames(oecd) <- c('year', 'iso3c', 'hours_worked')
# wdi_dat <- merge(wdi_dat, oecd, all.x = T)

# Get hours worked (alternative way, recommended by the OECD)
df_annual <- get_dataset(
  dataset = "OECD.SDD.NAD/DSD_NAMAIN10@DF_TABLE3_EMPDC/2.0",
  start_time = 1980,
  end_time = 2024,
  pre_formatted = TRUE) 

df_annual <- df_annual_raw %>% 
  filter(TRANSACTION == "EMP",
         ACTIVITY == "_T") %>%
  pivot_wider(
    names_from   = UNIT_MEASURE,
    values_from  = ObsValue
  ) %>%
  mutate(year = as.numeric(TIME_PERIOD),
         iso3c= REF_AREA,
         employed= as.numeric(PS)*1e3,
         total_hours=as.numeric(H)*1e6) %>%
  filter(!is.na(year)) %>%
  select(year, iso3c, employed, total_hours) %>%
  group_by(year, iso3c) %>%
  mutate(employed=first(na.omit(employed)),
         total_hours=first(na.omit(total_hours))) %>% unique()   
write_csv(df_annual, 'source-data/national_accounts_oecd_2025.csv')
wdi_dat <- merge(wdi_dat, df_annual, all.x=T)

# 2024 data for reference
# oecd <- read_csv('source-data/oecd_national_accounts.csv')
# employed <- oecd[oecd$Subject == "Total employment (number of persons employed); thousands", ]
# employed$year <- employed$Time
# employed$employed <- employed$Value*1000
# hours <- oecd[oecd$Subject == "Average hours worked per person employed", ]
# hours$year <- hours$Time
# hours$hours_per_employed <- hours$Value
# hours <- merge(hours[, c('year', 'Country', 'hours_per_employed')], employed[, c('year', 'Country', 'employed')])
# hours$iso3c <- countrycode(hours$Country, 'country.name', 'iso3c')
# hours$total_hours <- hours$hours_per_employed*hours$employed
# ggplot(df_annual_raw %>% filter(REF_AREA == 'USA', TRANSACTION == 'EMP', ACTIVITY == "_T"), 
#        aes(x=as.numeric(TIME_PERIOD), y=as.numeric(ObsValue), col=UNIT_MEASURE))+geom_point()+
#   geom_line(data=hours %>% filter(iso3c == 'USA'), aes(x=year, y=total_hours/1e6, col='total_hours'))+
#   geom_line(data=employed %>% filter(LOCATION == 'USA'), aes(x=year, y=employed/1e3, col='employed'))


wdi_dat <- wdi_dat[!is.na(wdi_dat$year), ]

# Carry forward total hours and hours worked if missing for recent years, skipping 2020 as abnormal year: 
# 
for(i in unique(wdi_dat$iso3c[!is.na(wdi_dat$hours_worked)])){
  if(is.na(wdi_dat$hours_worked[wdi_dat$iso3c == i & wdi_dat$year == 2021 & !is.na(wdi_dat$iso3c)])){
    wdi_dat$hours_worked[wdi_dat$iso3c == i & wdi_dat$year == 2021 & !is.na(wdi_dat$iso3c)] <- wdi_dat$hours_worked[wdi_dat$iso3c == i & wdi_dat$year == 2019 & !is.na(wdi_dat$iso3c)]
  }
  if(is.na(wdi_dat$hours_worked[wdi_dat$iso3c == i & wdi_dat$year == 2022 & !is.na(wdi_dat$iso3c)])){
    wdi_dat$hours_worked[wdi_dat$iso3c == i & wdi_dat$year == 2022 & !is.na(wdi_dat$iso3c)] <- wdi_dat$hours_worked[wdi_dat$iso3c == i & wdi_dat$year == 2021 & !is.na(wdi_dat$iso3c)]
  }
  if(is.na(wdi_dat$hours_worked[wdi_dat$iso3c == i & wdi_dat$year == 2023 & !is.na(wdi_dat$iso3c)])){
    wdi_dat$hours_worked[wdi_dat$iso3c == i & wdi_dat$year == 2023 & !is.na(wdi_dat$iso3c)] <- wdi_dat$hours_worked[wdi_dat$iso3c == i & wdi_dat$year == 2022 & !is.na(wdi_dat$iso3c)]
  }
  if(is.na(wdi_dat$hours_worked[wdi_dat$iso3c == i & wdi_dat$year == 2024 & !is.na(wdi_dat$iso3c)])){
    wdi_dat$hours_worked[wdi_dat$iso3c == i & wdi_dat$year == 2024 & !is.na(wdi_dat$iso3c)] <- wdi_dat$hours_worked[wdi_dat$iso3c == i & wdi_dat$year == 2023 & !is.na(wdi_dat$iso3c)]
  }
}

for(i in na.omit(unique(wdi_dat$iso3c[!is.na(wdi_dat$total_hours)]))){
  if(is.na(wdi_dat$total_hours[wdi_dat$iso3c == i & wdi_dat$year == 2021 & !is.na(wdi_dat$iso3c)])){
    wdi_dat$total_hours[wdi_dat$iso3c == i & wdi_dat$year == 2021 & !is.na(wdi_dat$iso3c)] <- wdi_dat$total_hours[wdi_dat$iso3c == i & wdi_dat$year == 2019 & !is.na(wdi_dat$iso3c)]
  }
  if(is.na(wdi_dat$total_hours[wdi_dat$iso3c == i & wdi_dat$year == 2022 & !is.na(wdi_dat$iso3c)])){
    wdi_dat$total_hours[wdi_dat$iso3c == i & wdi_dat$year == 2022 & !is.na(wdi_dat$iso3c)] <- wdi_dat$total_hours[wdi_dat$iso3c == i & wdi_dat$year == 2021 & !is.na(wdi_dat$iso3c)]
  }
  if(is.na(wdi_dat$total_hours[wdi_dat$iso3c == i & wdi_dat$year == 2023 & !is.na(wdi_dat$iso3c)])){
    wdi_dat$total_hours[wdi_dat$iso3c == i & wdi_dat$year == 2023 & !is.na(wdi_dat$iso3c)] <- wdi_dat$total_hours[wdi_dat$iso3c == i & wdi_dat$year == 2022 & !is.na(wdi_dat$iso3c)]
  }
  if(is.na(wdi_dat$total_hours[wdi_dat$iso3c == i & wdi_dat$year == 2024 & !is.na(wdi_dat$iso3c)])){
    wdi_dat$total_hours[wdi_dat$iso3c == i & wdi_dat$year == 2024 & !is.na(wdi_dat$iso3c)] <- wdi_dat$total_hours[wdi_dat$iso3c == i & wdi_dat$year == 2023 & !is.na(wdi_dat$iso3c)]
  }
}

# Stage 2: Define features

# Get total hours worked per country (alternative)
wdi_dat$total_hours_alternative <- wdi_dat$pop*(wdi_dat$working_age_pop_pct/100)*(wdi_dat$employment_rate/100)*wdi_dat$hours_worked

wdi_dat$gdp_over_k_hours_worked <- 1000*wdi_dat$gdp/wdi_dat$total_hours
wdi_dat$gdp_ppp_over_k_hours_worked <- 1000*wdi_dat$gdp_ppp/wdi_dat$total_hours
wdi_dat$gdp_over_pop <- wdi_dat$gdp/wdi_dat$pop
wdi_dat$gdp_ppp_over_pop <- wdi_dat$gdp_ppp/wdi_dat$pop
wdi_dat$gdp_ppp_over_labor_force <- wdi_dat$gdp_ppp/wdi_dat$labor_force

wdi_dat$gdp_ppp_over_pop_c <- wdi_dat$gdp_ppp_c/wdi_dat$pop
wdi_dat$gdp_over_pop_c <- wdi_dat$gdp_c/wdi_dat$pop
wdi_dat$gdp_ppp_over_k_hours_worked_c <- 1000*wdi_dat$gdp_ppp_c/wdi_dat$total_hours

# Export to file
write_csv(wdi_dat, 'output-data/gdp_over_hours_worked.csv')
