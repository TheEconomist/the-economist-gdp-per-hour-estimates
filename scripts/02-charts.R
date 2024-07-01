# 1. Load data and packages: -----------------------------------
library(tidyverse)
wdi_dat <- read_csv('output-data/gdp_over_hours_worked.csv')

# 2. Select countries to plot: -----------------------------------
pdat <- wdi_dat[order(wdi_dat$year) & wdi_dat$country %in% wdi_dat$country[!is.na(wdi_dat$hours_worked) & wdi_dat$gdp_over_k_hours_worked > 5000] & wdi_dat$year >= 2012 & !is.na(wdi_dat$country) & wdi_dat$country != 'Ireland', ]

# 3. Generate plotting data frames: -----------------------------------
lpdat <- pdat %>%
  pivot_longer(
    cols = c(gdp_ppp_over_k_hours_worked_c,
             # gdp_ppp_over_pop_c,
             gdp_over_pop_c,
             gdp_ppp_over_k_hours_worked,
             # gdp_ppp_over_pop_c,
             gdp_over_pop
             ),
    names_to = "type",
    values_to = "value"
  )

lpdat <- lpdat %>%
  group_by(country, type) %>%
  mutate(index = value / value[year == min(year)])

lpdat$index_diff_to_US <- NA
for(i in unique(lpdat$year)){
  for(j in unique(lpdat$type)){
    lpdat$index_diff_to_us[lpdat$year == i & lpdat$type == j] <- lpdat$index[lpdat$year == i & lpdat$type == j] - lpdat$index[lpdat$type == j & lpdat$year == i & lpdat$country == 'United States']
  }
}

# 4. Chart in GGPLOT: -----------------------------------
ggplot(lpdat[lpdat$type %in% c('gdp_ppp_over_k_hours_worked', 'gdp_over_pop'), ], 
       aes(x=year, y=index_diff_to_us, col=country, group=country))+geom_line(col='gray', alpha = 0.5)+
  geom_line(data=lpdat[lpdat$country %in% c('Germany', 'United States', 'France', 'Germany', 'Korea, Rep.', 'Austria') & lpdat$type %in% c('gdp_ppp_over_k_hours_worked', 'gdp_over_pop'), ], 
            aes(col=country))+facet_grid(type~.)+
  ggtitle('GDP, 2012-2023, % growth compared to US, cumulative')+ylab('')+xlab('')


# 5. Generate decomposition: -----------------------------------
wdi_dat <- read_csv('output-data/gdp_over_hours_worked.csv')
pdat <- wdi_dat[wdi_dat$year == 2023, ]

# Intermediate step: Calculate employment rate using national accounts data (as recommended by OECD, to maintain consistency with hours worked per employed)
pdat$employment_rate_consistent <- pdat$employed/(pdat$working_age_pop_pct*pdat$pop) 

# Add US values for comparison
us <- pdat[pdat$country == 'United States', ]
us <- us[, setdiff(colnames(us), c('iso2c', 'country', 'iso3c'))]
colnames(us)[2:ncol(us)] <- paste0(colnames(us)[2:ncol(us)], '_USA')
pdat <- merge(pdat, us, by = 'year', all.x = T)

# Calculate adjustments
pdat$gdp_over_pop_adjust_prices <- pdat$gdp_ppp_over_pop
pdat$gdp_over_pop_adjust_prices_working_age <- pdat$gdp_ppp_over_pop*(pdat$working_age_pop_pct_USA/pdat$working_age_pop_pct)
# pdat$gdp_over_pop_adjust_prices_working_age_unemp_or_emp <- pdat$gdp_over_pop_adjust_prices_working_age*((pdat$unemployment_r_USA+pdat$employment_rate_consistent_USA)/(pdat$unemployment_r+pdat$employment_rate))
pdat$gdp_over_pop_adjust_prices_working_age_emp_only <- pdat$gdp_over_pop_adjust_prices_working_age*((pdat$employment_rate_consistent_USA)/(pdat$employment_rate_consistent))
pdat$gdp_over_pop_adjust_prices_working_age_emp_hours_worked <- pdat$gdp_over_pop_adjust_prices_working_age_emp_only*((pdat$hours_worked_USA)/(pdat$hours_worked))

# Average over Western Europe (uses UN definition)
pdat <- pdat[pdat$country %in% c('Austria', 'Belgium', 'France', 'Germany', 
                                 # 'Liechtenstein', -- excluded due to lack of data
                                 'Luxembourg', 
                                 # 'Monaco', -- excluded due to lack of data
                                 'Netherlands', 'Switzerland'), ]

# Generate population-weighted average
for(i in c('gdp_over_pop', 
           'gdp_over_pop_adjust_prices',
           'gdp_over_pop_adjust_prices_working_age',
           'gdp_over_pop_adjust_prices_working_age_emp_only',
           'gdp_over_pop_adjust_prices_working_age_emp_hours_worked')){
  pdat[, paste0(i, '_pop_weighted_average')] <- sum(pdat[, i]*pdat$pop)/sum(pdat$pop)
}

# Show for a few countries
ggplot(pdat, aes(y=country))+
  geom_point(aes(x=gdp_over_pop, col = 'GDP per capita'))+
  geom_point(aes(x=gdp_over_pop_adjust_prices, col='Adjusting for prices'))+
  geom_point(aes(x=gdp_over_pop_adjust_prices_working_age, col = 'Adjusting for prices + working age pop'))+
  # geom_point(aes(x=gdp_over_pop_adjust_prices_working_age_unemp_or_emp, col = 'Adjusting for prices + working age pop + employed/unemployed'))+
  geom_point(aes(x=gdp_over_pop_adjust_prices_working_age_emp_only, col = 'Adjusting for prices + working age pop + employement'))+
  geom_point(aes(x=gdp_over_pop_adjust_prices_working_age_emp_hours_worked, col = 'Adjusting for prices + working age pop + employment + hours worked per employee'))+
  xlim(c(0, max(pdat$gdp_over_pop*3)))+
  geom_point(data = pdat[pdat$country == 'United States', ], aes(x=gdp_over_pop, col = 'GDP per capita'))+ggtitle("GDP - countries v USA\nAdjusting other countries to US numbers")+theme_minimal()

# Show with pop-weighted average
ggplot(pdat, aes(y=paste0('Population-weighted average')))+
  geom_point(aes(x=gdp_over_pop_pop_weighted_average, col = 'GDP per capita'))+
  geom_point(aes(x=gdp_over_pop_adjust_prices_pop_weighted_average, col='Adjusting for prices'))+
  geom_point(aes(x=gdp_over_pop_adjust_prices_working_age_pop_weighted_average, col = 'Adjusting for prices + working age pop'))+
  # geom_point(aes(x=gdp_over_pop_adjust_prices_working_age_unemp_or_emp, col = 'Adjusting for prices + working age pop + employed/unemployed'))+
  geom_point(aes(x=gdp_over_pop_adjust_prices_working_age_emp_only_pop_weighted_average, col = 'Adjusting for prices + working age pop + employement'))+
  geom_point(aes(x=gdp_over_pop_adjust_prices_working_age_emp_hours_worked_pop_weighted_average, col = 'Adjusting for prices + working age pop + employment + hours worked per employee'))+
  xlim(c(0, max(pdat$gdp_over_pop*1.5)))+geom_vline(aes(xintercept=gdp_over_pop_USA, col = 'GDP per Capita (USA)'))+ggtitle(paste0("GDP - countries  v USA\nAdjusting ", paste0(pdat$country, collapse =', '), " to US numbers"))+theme_minimal()+ylab('')

# Export for chart:
write_csv(unique(pdat[, c('year',
                   'gdp_over_pop_pop_weighted_average', 
                   'gdp_over_pop_adjust_prices_pop_weighted_average',
                   'gdp_over_pop_adjust_prices_working_age_pop_weighted_average',
                   'gdp_over_pop_adjust_prices_working_age_emp_only_pop_weighted_average',
                   'gdp_over_pop_adjust_prices_working_age_emp_hours_worked_pop_weighted_average',
                   'gdp_over_pop_USA')]), 'output-data/gdp_decomposition_pop_weighted_average.csv')

pdat <- read_csv('output-data/gdp_decomposition_pop_weighted_average.csv')

