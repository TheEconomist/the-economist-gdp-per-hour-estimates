# GDP per hour worked

This repo contains data and code behind our analysis of GDP and productivity. The resulting article can be found [here.](https://www.economist.com/graphic-detail/2023/10/04/productivity-has-grown-faster-in-western-europe-than-in-america). To replicate the analysis, please run ['scripts/01-data-setup.R'](scripts/01-data-setup.R) and ['scripts/02-charts.R'](scripts/02-charts.R) in that order. 

It also contains the data and code behind our ranking of the world's richest countries, which can be found [here.](https://www.economist.com). To replicate the analysis for this, please run the two aforementioned scripts, then ['scripts/03-estimate-gdp-per-hour-for-all-countries.R'](scripts/03-estimate-gdp-per-hour-for-all-countries.R).

For any questions about this work, please email: sondresolstad@economist.com

Our latest data can be downloaded [here](https://github.com/TheEconomist/the-economist-gdp-per-hour-estimates/blob/main/output-data/gdp_over_hours_worked_with_estimated_hours_worked.csv).

## Estimation of hours worked
For OECD countries, we followed guidance from OECD statisticians on how to use their data to calculate total hours worked. This data was not available for all countries. When missing, we first turned to the Penn World Table. If this had data available on this metric from 2015 or later, we used this value (we first checked that with the exception of a temporary dip during the early stages of the covid-19 pandemic, values were stable for the countries were we had data). If not such data was available, we estimated it. We here relied on gradient boosted trees, and data on countries demography and economics (including known oil reserves). These estimates are uncertain, as we acknowledge, and especially so for poor countries. While our method held up well in cross-validation, our estimates for the very poorest countries, for instance, could be systematically off, and should be approached with care (this should however not greatly affect their rankings). Those interested can inspect our calibration plots, other tests, and all the code [here](https://github.com/TheEconomist/the-economist-gdp-per-hour-estimates/blob/main/output-data/gdp_over_hours_worked_with_estimated_hours_worked.csv).

## Sources
[OECD](https://data.oecd.org/), [World Bank](https://data.worldbank.org/), [UN](https://population.un.org/dataportal/), [Penn World Table](https://www.rug.nl/ggdc/productivity/pwt/?lang=en)

## Suggested citation
The Economist and Solstad, Sondre (corresponding author), 2023. "All work and no play", The Economist, October 4th issue, 2023.

