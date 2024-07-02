
# Stage 1 - load data and packages: ------------------------------
library(WDI)
library(tidyverse)
use_cache <- T

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
  missing_gdp_countries <- intersect(wdi_dat$country[is.na(wdi_dat$gdp) & wdi_dat$year == 2023],
                                 wdi_dat$country[!is.na(wdi_dat$gdp) & wdi_dat$year == 2022])
  
  # For posterity, these countries were:
  # missing_gdp_countries <- c(
  # "Afghanistan" ,     "American Samoa"  , "Aruba"          ,  "Bermuda"  ,       
  # "Bhutan"      ,     "Cayman Islands"  , "Channel Islands",  "Curacao"  ,       
  # "Faroe Islands" ,   "French Polynesia", "Guam"          ,   "Liechtenstein" ,  
  # "Monaco"       ,    "New Caledonia"   , "Qatar"         ,   "Tonga")    
  
  missing_gdp <- data.frame(country = missing_gdp_countries,
                            gdp_growth = c(NA, # Afghanistan
                                           NA, # American Samoa
                                           1.053, # Aruba
                                           NA, # Bermuda
                                           1.046, # Bhutan
                                           NA, # Cayman Islands
                                           NA, # Channel Islands
                                           NA, # Curacao
                                           NA, # Faraoe Islands
                                           NA, # French Polynesia
                                           NA, # Guam
                                           NA, # Liechtenstein
                                           NA, # Monaco
                                           NA, # New Caledonia
                                           1.016, # Qatar
                                           1.026 # Tonga
                                           ))
  
  for(i in missing_gdp$country){
    for(j in c('gdp', 'gdp_c', 'gdp_ppp_c', 'gdp_ppp')){
      if(is.na(wdi_dat[wdi_dat$country == i & wdi_dat$year == 2023, j])){
        wdi_dat[wdi_dat$country == i & wdi_dat$year == 2023, j] <- wdi_dat[wdi_dat$country == i & wdi_dat$year == 2022, j]*missing_gdp$gdp_growth[missing_gdp$country == i]
        }
      }
  }
  
  write_csv(wdi_dat, 'source-data/wdi_cache.csv')
  }
wdi_dat <- read_csv('source-data/wdi_cache.csv')

# Get OECD data:

# Get working-age population
oecd <- read_csv('source-data/working_age_pop_oecd.csv')
library(countrycode)
oecd$iso3c <- oecd$LOCATION
oecd <- na.omit(oecd[, c('TIME', 'iso3c', 'Value')])
colnames(oecd) <- c('year', 'iso3c', 'working_age_pop_pct')
wdi_dat <- merge(wdi_dat, oecd, all.x = T)

# Get employment rate
oecd <- read_csv('source-data/employment_rate_oecd.csv')
oecd <- oecd[oecd$SUBJECT == 'TOT' &  oecd$MEASURE == "PC_WKGPOP" & oecd$FREQUENCY == 'A', ]
library(countrycode)
oecd$iso3c <- oecd$LOCATION
oecd <- na.omit(oecd[, c('TIME', 'iso3c', 'Value')])
colnames(oecd) <- c('year', 'iso3c', 'employment_rate')
wdi_dat <- merge(wdi_dat, oecd, all.x = T)

# Get hours worked 
oecd <- read_csv('source-data/hours_worked_oecd.csv')
library(countrycode)
oecd$iso3c <- oecd$LOCATION
oecd <- na.omit(oecd[, c('TIME', 'iso3c', 'Value')])
colnames(oecd) <- c('year', 'iso3c', 'hours_worked')
wdi_dat <- merge(wdi_dat, oecd, all.x = T)

# Get hours worked (alternative way, recommended by the OECD)
oecd <- read_csv('source-data/oecd_national_accounts.csv')
employed <- oecd[oecd$Subject == "Total employment (number of persons employed); thousands", ]
employed$year <- employed$Time
employed$employed <- employed$Value*1000
hours <- oecd[oecd$Subject == "Average hours worked per person employed", ]
hours$year <- hours$Time
hours$hours_per_employed <- hours$Value
hours <- merge(hours[, c('year', 'Country', 'hours_per_employed')], employed[, c('year', 'Country', 'employed')])
hours$iso3c <- countrycode(hours$Country, 'country.name', 'iso3c')
hours$total_hours <- hours$hours_per_employed*hours$employed

wdi_dat <- merge(wdi_dat, hours[, c('iso3c', 'year', 'total_hours', 'hours_per_employed', 'employed')], all.x=T)
wdi_dat <- wdi_dat[!is.na(wdi_dat$year), ]

# Carry forward total hours and hours worked if missing for recent years, skipping 2020 as abnormal year: 
# (Beyond 2023, this affects Russia and South Africa)
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
