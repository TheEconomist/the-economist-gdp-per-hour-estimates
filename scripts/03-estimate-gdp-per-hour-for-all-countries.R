# This script provides country-year estimates of hours worked for all countries
library(tidyverse)
library(anytime)
library(readxl)
library(countrycode)

# Step 1: Load data ------------------------------------

# Get extra WDI data:
library(WDI)
use_wdi_extra_cache <- T
if(!use_wdi_extra_cache){
  wdi_extra <- WDI(country = c('all'),
                   indicator = c('pop_wdi' = 'SP.POP.TOTL', 
                                 'pop_0_to_14' = 'SP.POP.0014.TO.ZS',
                                 'pop_15_to_64' = 'SP.POP.1564.TO',
                                 'labor_force_partic_ILO_female' = 'SL.TLF.CACT.FE.ZS',
                                 'labor_force_partic_ILO' = 'SL.TLF.CACT.ZS',
                                 'pop_percent_male' = 'SP.POP.TOTL.MA.ZS'),
                   start = 2012)
  wdi_extra <- wdi_extra[, c('iso3c', 'year', 'pop_wdi', 'pop_0_to_14', 'pop_15_to_64', 'labor_force_partic_ILO',
                             'labor_force_partic_ILO_female', 'pop_percent_male')]
  write_csv(wdi_extra, 'source-data/wdi_extra_cache.csv')} else {
  wdi_extra <- read_csv('source-data/wdi_extra_cache.csv')
}


# Load base data:
wdi_dat <- read_csv('output-data/gdp_over_hours_worked.csv')
wdi_dat$continent <- countrycode(wdi_dat$iso3c, 'iso3c', 'continent')
wdi_dat$region <- countrycode(wdi_dat$iso3c, 'iso3c', 'region')

# Exclude dependencies (non-UN countries) with less than 0.5m population
un_countries <- countrycode::codelist %>%
  filter(!is.na(iso3c), !is.na(un.name.en)) %>%
  pull(iso3c)
wdi_dat <- wdi_dat[!(wdi_dat$country %in% 
                     unique(wdi_dat$country[wdi_dat$iso3c %in% 
                                              setdiff(wdi_dat$iso3c, un_countries) & 
                                              wdi_dat$pop < 500000 & wdi_dat$year == 2023])), ] 
# These are:
# [1] "Aruba"                     "American Samoa"            "Bermuda"                   "Channel Islands"          
# [5] "Curacao"                   "Cayman Islands"            "Faroe Islands"             "Gibraltar"                
# [9] "Greenland"                 "Guam"                      "Isle of Man"               "St. Martin (French part)" 
# [13] "Northern Mariana Islands"  "New Caledonia"             "French Polynesia"          "Sint Maarten (Dutch part)"
# [17] "Turks and Caicos Islands"  "British Virgin Islands"    "Virgin Islands (U.S.)" 

# Also exclude non-countries
non_countries <- c(
  "Africa Eastern and Southern", "Africa Western and Central", "Arab World", 
  "Central Europe and the Baltics", "Caribbean small states", "East Asia & Pacific (excluding high income)", 
  "Early-demographic dividend", "East Asia & Pacific", "Europe & Central Asia (excluding high income)", 
  "Europe & Central Asia", "Euro area",
  "Fragile and conflict affected situations", "Heavily indebted poor countries (HIPC)", 
  "IBRD only", "IDA & IBRD total", "IDA total", "IDA blend", 
  "IDA only", "Latin America & Caribbean (excluding high income)", 
  "Latin America & Caribbean", "Least developed countries: UN classification", 
  "Low & middle income", "Late-demographic dividend", "Middle East & North Africa", 
  "Middle income", "Middle East & North Africa (excluding high income)", 
  "North America", "OECD members", "Other small states", 
  "Pre-demographic dividend", "Pacific island small states", "Post-demographic dividend", 
  "South Asia", "Sub-Saharan Africa (excluding high income)", 
  "Sub-Saharan Africa", "Small states", "East Asia & Pacific (IDA & IBRD countries)", 
  "Europe & Central Asia (IDA & IBRD countries)", 
  "Latin America & the Caribbean (IDA & IBRD countries)", 
  "Middle East & North Africa (IDA & IBRD countries)", "South Asia (IDA & IBRD)", 
  "Sub-Saharan Africa (IDA & IBRD countries)", "World", 
  "Upper middle income", "High income", "Lower middle income", 
  "Low income", "Not classified"
)
wdi_dat <- wdi_dat[!wdi_dat$country %in% non_countries, ]

# Source: https://www.rug.nl/ggdc/productivity/pwt/
penn <- read_xlsx('source-data/pwt1001.xlsx', skip = 0, sheet = 3)

# Oil reserves:
oil <- read_csv('source-data/oil-proved-reserves.csv')
oil$year <- oil$Year
oil$iso3c <- oil$Code
oil$oil <- oil$`Oil proved reserves - BBL`

# Assume oil reserves in 2021-2023 = those in 2020
for(i in 2021:2023){
temp <- oil[oil$year == 2020, ]
temp$year <- i
oil <- rbind(oil, temp)
}
oil <- unique(oil[, c('year', 'iso3c', 'oil')])

# Step 2: Merge data ------------------------------------
penn$penn_employment <- penn$emp
penn$penn_average_hours_worked <- penn$avh
penn$penn_pop <- penn$pop
penn$iso3c <- penn$countrycode

penn <- penn[, c('iso3c', 'year', 'penn_pop', 'penn_employment', 'penn_average_hours_worked')]
penn$penn_employment_prop <- penn$penn_employment / penn$penn_pop
penn$penn_hours_worked_over_pop <- penn$penn_average_hours_worked*penn$penn_employment/penn$penn_pop

dat <- merge(wdi_dat, penn, by = c('year', 'iso3c'), all = T)
dat <- merge(dat, wdi_extra, by = c('year', 'iso3c'), all.x = T)
dat <- merge(dat, oil, by = c('year', 'iso3c'), all.x = T)
dat <- dat[!is.na(dat$iso3c), ]

# Fix to missing population estimates
dat$pop[is.na(dat$pop)] <- dat$pop_wdi[is.na(dat$pop)] 
dat$pop[is.na(dat$pop)] <- 1000*dat$penn_pop[is.na(dat$pop)]
dat$pop_15_to_64 <- dat$pop_15_to_64 / dat$pop

dat$oil <- dat$oil / dat$pop
dat$oil[is.na(dat$oil)] <- 0

# Step 3: Model hours worked: ------------------------------------
dat$hours_worked_over_pop <- dat$total_hours / dat$pop

# First check that the two measures are comparable:
check <- dat[dat$iso3c %in% dat$iso3c[!is.na(dat$hours_worked_over_pop)] &
             dat$year >= 2010, c('penn_hours_worked_over_pop',
                                 'hours_worked_over_pop')]
check$diff <- check$penn_hours_worked_over_pop - check$hours_worked_over_pop
summary(check) # Appear comparable.

# Combine the two data sources to get as many countries as possible, defaulting to OECD data where available
dat$hours_worked_over_pop_combined <- dat$hours_worked_over_pop
dat$hours_worked_over_pop_combined[is.na(dat$hours_worked_over_pop_combined)] <- dat$penn_hours_worked_over_pop[is.na(dat$hours_worked_over_pop_combined)]
summary(dat$hours_worked_over_pop_combined)

# Convert region and continent to numeric
if('continent' %in% colnames(dat)){
  dat$continent <- as.numeric(as.factor(dat$continent))
}

if('region' %in% colnames(dat)){
  dat$region <- as.numeric(as.factor(dat$region))
}

# Impute out-of-range value for missing (allows splits)
NA_impute_vars <- c("pop_0_to_14", "pop_15_to_64", "pop_over_65", 'gdp_ppp_over_pop', 'labor_force_partic_ILO', 'labor_force_partic_ILO_female', 'pop_percent_male')
for(i in NA_impute_vars){
  dat[, paste0(i, '_is_NA')] <- as.numeric(is.na(dat[, i]))
  dat[is.na(dat[, i]), i] <- -1
}

# Generate matricies and split into test and training data
train <- dat[!is.na(dat$hours_worked_over_pop_combined), ]

train <- na.omit(dat[dat$year >= 2000, c("hours_worked_over_pop_combined", "year", "pop_0_to_14", "pop_15_to_64", "pop_over_65", 'oil', 'gdp_ppp_over_pop', 'iso3c', 'continent', 'region', 'pop', 'pop_percent_male', paste0(NA_impute_vars, '_is_NA'))])
isos <- train$iso3c
train$iso3c <- NULL
years <- train$year
pop <- train$pop
train$pop <- NULL

countries <- unique(isos)

# Number of categories in cross-validation
num_categories <- 10

# Create a data frame with the countries and their counts
country_counts <- data.frame(country = unique(isos), count = table(isos)[unique(isos)])

# Order the countries by count in descending order
ordered_countries <- country_counts[order(country_counts$count.Freq, decreasing = T), "country"]

# Initialize the categories list
categories <- vector("list", num_categories)

# Assign each country to a category ensuring all observations of a country are in the same category
for (i in seq_along(ordered_countries)) {
  cat_index <- (i - 1) %% num_categories + 1
  categories[[cat_index]] <- c(categories[[cat_index]], ordered_countries[i])
}

# We next test our modelling approach using 10-fold cross validation

# Run 10-fold CV:
res <- data.frame()
for(i in categories){
  test <- unlist(i)

  # Fit LM model
  summary(lm_fit <- lm(hours_worked_over_pop_combined ~ year*pop_0_to_14+pop_15_to_64+pop_over_65+gdp_ppp_over_pop, data=train[!isos %in% test, ], weights = log(pop[!isos %in% test])))
  
  # Fit GBT model
  library(agtboost)
  gbt_fit <- gbt.train(y=train$hours_worked_over_pop_combined[!isos %in% test],
                       x=as.matrix(train[!isos %in% test, setdiff(colnames(train), "hours_worked_over_pop_combined")]),
                       learning_rate = 0.001,
                       verbose = 1000,
                       weights = log(pop))
  
  # Generate predictions on training set:
  preds <- data.frame(preds=predict(lm_fit, newdata=train), actual= train$hours_worked_over_pop_combined,
                      preds_gbt=predict(gbt_fit, newdata = as.matrix(train[, setdiff(colnames(train), "hours_worked_over_pop_combined")])),
                      iso3c = isos,
                      year = years,
                      gdp_ppp_over_pop = train$gdp_ppp_over_pop,
                      pop = pop)
  
  # Predictions v actual, test 1:
  ggplot(preds, aes(x=preds_gbt, y=actual, col=isos %in% test))+
    geom_point()+
    geom_abline(aes(intercept=0, slope=1))
  
  Sys.sleep(1)
  
  # Predictions v actual, test 2:
  ggplot(preds, aes(x=train$gdp_ppp_over_pop, y=actual-preds_gbt, col=isos %in% test))+
    geom_point()
  
  res <- rbind(res, preds[isos %in% test, ])
}

# Plot result of 10-fold cv
ggplot(res, aes(x=preds_gbt, y=actual, size = pop, col=iso3c))+geom_point()+
  geom_abline(aes(intercept=0, slope=1))+
  geom_smooth(method = 'lm', aes(group = '1'), weights = preds$pop) 

ggplot(res, aes(y=actual-preds_gbt, x=gdp_ppp_over_pop, size = pop, col=iso3c))+geom_point()+
  geom_abline(aes(intercept=0, slope=0))+
  geom_smooth(method = 'lm', aes(group = '1'), weights = res$pop) 

# Suggests calibrated out-of-sample-predictions and acceptable / well-behaved errors. This suggest using this modelling approach is appropriate and we can use it for our main model.

# Fit main model
gbt_fit <- gbt.train(y=train$hours_worked_over_pop_combined,
                     x=as.matrix(train[, setdiff(colnames(train), "hours_worked_over_pop_combined")]),
                     learning_rate = 0.001,
                     verbose = 1000,
                     weights = log(pop))

preds <- data.frame(preds=predict(lm_fit, newdata=train), actual= train$hours_worked_over_pop_combined,
                    preds_gbt=predict(gbt_fit, newdata = as.matrix(train[, setdiff(colnames(train), "hours_worked_over_pop_combined")])),
                    iso3c = isos,
                    year = years,
                    gdp_ppp_over_pop = train$gdp_ppp_over_pop,
                    pop = pop)

ggplot(preds, aes(x=preds_gbt, y=actual, size = pop, col=iso3c))+geom_point()+
  geom_abline(aes(intercept=0, slope=1))+
  geom_smooth(method = 'lm', aes(group = '1'), weights = preds$pop) 

# Fit predictions:
dat$hours_worked_over_pop_predicted <- predict(gbt_fit, newdata = as.matrix(dat[, setdiff(colnames(train), "hours_worked_over_pop_combined")]))

# Generate target column: ------------------------------------

# Add known values from PWT and OECD:
dat$hours_worked_over_pop_modelled <- dat$hours_worked_over_pop_combined

# If known value in 2015 or later, use this for future values. (Over-time changes with the exception of temporary decline during pandemic typically very slight)
for(i in 2016:2023){
  for(j in unique(dat$iso3c)){
    if(length(dat$hours_worked_over_pop_combined[dat$year == i & dat$iso3c == j]) > 0){
      if(is.na(dat$hours_worked_over_pop_combined[dat$year == i & dat$iso3c == j])){
        dat$hours_worked_over_pop_combined[dat$year == i & dat$iso3c == j] <- dat$hours_worked_over_pop_combined[dat$year == i-1 & dat$iso3c == j]
      }
    }
  }
}

# If unknown, use prediction from model based on demography and gdppcppp:
dat$use_model <- is.na(dat$hours_worked_over_pop_combined)
dat$estimated_using_past_value <- is.na(dat$hours_worked_over_pop) & !is.na(dat$hours_worked_over_pop)
dat$estimated_using_model <- is.na(dat$hours_worked_over_pop_combined)
dat$hours_worked_over_pop_combined[is.na(dat$hours_worked_over_pop_combined)] <- dat$hours_worked_over_pop_predicted[is.na(dat$hours_worked_over_pop_combined)]

# Inspect the results to check if appropriate:
ggplot(dat[dat$year >= 2010, ], aes(x=year, y=hours_worked_over_pop_combined, size = pop, col=iso3c, alpha = ifelse(use_model, 1, 0.2)))+geom_line()+theme(legend.pos ='none')

# Exclude a few countries which have entered major conflict since 2015 and remained in it:
dat$hours_worked_over_pop_combined[dat$country %in% c('Ukraine', 'Myanmar') & dat$year > 2021] <- NA
dat$hours_worked_over_pop_combined[dat$country %in% c("Sudan", "West Bank and Gaza") & dat$year > 2022] <- NA

# Generate target column: ------------------------------------
dat$is_grouping <- is.na(countrycode(dat$iso3c, 'iso3c', 'country.name'))
dat$hours_worked_KNOWN_PLUS_ESTIMATED <- dat$hours_worked_over_pop_combined*dat$pop

dat$hours_worked_adjustment <- NA
for(i in 2015:2023){
  dat$hours_worked_adjustment[dat$year == i] <- 1/(dat$hours_worked_over_pop_combined[dat$year == i] / weighted.mean(dat$hours_worked_over_pop_combined[dat$year == i], w = dat$pop[dat$year == i], na.rm = T))
}

# Inspect:
ggplot(dat[!dat$is_grouping & dat$year == 2023 & !is.na(dat$country), ], aes(y=reorder(country, gdp_ppp_over_pop), col=use_model, x=hours_worked_adjustment))+geom_point()

# Clean data:
for(i in NA_impute_vars){
  dat[dat[, paste0(i, '_is_NA')] == 1, i] <- NA
  dat[, paste0(i, '_is_NA')] <- NULL
}

# Check for missing data:
# missing_data_isos <- dat$iso3c[is.na(dat$gdp) & dat$year == max(dat$year)]
# View(dat[dat$iso3c %in% missing_data_isos & dat$year >= max(dat$year-1), ])

# Save:
dat$gdp_ppp_over_pop_adjusted_for_hours <- dat$gdp_ppp_over_pop*dat$hours_worked_adjustment
dat$gdp_ppp_over_population_15_to_65 <- dat$gdp_ppp / (dat$pop*dat$pop_15_to_64)

write_csv(dat, "output-data/gdp_over_hours_worked_with_estimated_hours_worked.csv")
write_csv(dat[dat$year == 2023 & !dat$is_grouping, c('year', 'country', 'iso3c', 'pop', 'gdp_over_pop', 'gdp_ppp_over_pop', 'gdp_ppp_over_population_15_to_65', 'gdp_ppp_over_pop_adjusted_for_hours', 'estimated_using_past_value', "estimated_using_model")], 
          "output-data/gdp_2023_for_interactive.csv")

# Add ranks:
dat <- na.omit(dat[dat$year == 2023 & dat$country != 'Ireland' & !dat$is_grouping, c('year', 'country', 'iso3c', 'pop', 'gdp_over_pop', 'gdp_ppp_over_pop', 'gdp_ppp_over_population_15_to_65', 'gdp_ppp_over_pop_adjusted_for_hours')])

# Add rank columns
dat$gdp_over_pop_rank <- rank(-dat$gdp_over_pop, ties.method = "min")
dat$gdp_ppp_over_pop_rank <- rank(-dat$gdp_ppp_over_pop, ties.method = "min")
dat$gdp_ppp_over_population_15_to_65_rank <- rank(-dat$gdp_ppp_over_population_15_to_65, ties.method = "min")
dat$gdp_ppp_over_pop_adjusted_for_hours_rank <- rank(-dat$gdp_ppp_over_pop_adjusted_for_hours, ties.method = "min")
dat$source <- "The Economist"

write_csv(dat, 
          "output-data/the_economist_richest_countries_2024.csv")

