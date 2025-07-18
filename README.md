# GDP: Per capita, per capita PPP and per hour worked

This repo contains the data and code of _The Economist's_ annual ranking of the world's richest countries. To replicate the analysis, please run ['scripts/01-data-setup.R'](scripts/01-data-setup.R), ['scripts/02-charts.R'](scripts/02-charts.R) and ['scripts/03-estimate-gdp-per-hour-for-all-countries.R'](scripts/03-estimate-gdp-per-hour-for-all-countries.R), in that order. 

We exclude Ireland from our analysis and data due to issues with its GDP figures explained [here](https://www.economist.com/the-economist-explains/2023/10/31/whats-weird-about-irelands-gdp), and as of 2025, Luxembourg, as it benefits disproportionally from people who commute into the country to work. We also exclude small island states affiliated with other countries (those with population below 500,000 and which are not members of the UN).

Our latest data can be downloaded [here](https://github.com/TheEconomist/the-economist-gdp-per-hour-estimates/blob/main/output-data/gdp_over_hours_worked_with_estimated_hours_worked.csv).

## Methodology: Estimating GDP per hour worked
For OECD countries, we followed guidance from OECD statisticians on how to use their data to calculate total hours worked. 

The relevant OECD data was not available for all countries. When missing, we first turned to the Penn World Table. If this source had data available for a country from 2015 or later, we used the most recent value. (We first checked that this was permissible using our OECD data: with the exception of a temporary dip during the early stages of the covid-19 pandemic, values were stable in this interval.) 

If no such data was available from either source, we estimated it. We here relied on gradient-boosted trees as our modelling approach, and used data on countries' demography and economics (including known oil reserves) to train our models. These estimates are uncertain, especially for poor countries. While our method held up reasonably well in cross-validation, that exercise is limited by less data from the very poorest countries. These could be systematically off, and should be approached with care. This would however not greatly affect their rankings. 

GDP PPP per hour worked was then calculated by dividing countries' total GDP PPP by their hours worked. GDP adjusted for hours worked (and costs) was calculated by adjusting GDP PPP in a given country by the ratio of their estimated hours worked per person to the average for the world as a whole (i.e. mean of all countries, weighted by population). 

Those interested can replicate and inspect our calibration plots, other tests, and view all the code [here](https://github.com/TheEconomist/the-economist-gdp-per-hour-estimates/blob/main/output-data/gdp_over_hours_worked_with_estimated_hours_worked.csv).

## Notes
This work shows the latest data available, which at the time of publication, were estimates of 2024 values made in 2025. This means that economic change during 2025 are not captured in the data. Our data also only shows country averages, and does not consider the distribution of income within countries. In some countries high savings rates or other factors may make GDP estimates less reliable as a guide to living standards. Finally, we rely on GDP estimates which are themselves uncertain, and, research suggests, may be especially unreliable for authoritarian countries.  

For Aruba, Bhutan, South Korea, Palau, Tonga and Tuvalu, we used 2023 GDP values from the World Bank coupled with 2024 growth estimates from the IMF, as World Bank values for 2024 were missing.

## Data sources
[OECD](https://data.oecd.org/), [World Bank](https://data.worldbank.org/), [UN](https://population.un.org/dataportal/), [Penn World Table](https://www.rug.nl/ggdc/productivity/pwt/?lang=en), [IMF](https://www.imf.org/external/datamapper/NGDP_RPCH@WEO/PER)

## Suggested academic citation
The Economist and Solstad, Sondre, 2025. GDP per hour estimates [dataset]. The Economist. Available at: https://github.com/TheEconomist/the-economist-gdp-per-hour-estimates.
