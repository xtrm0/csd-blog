+++
# The title of your blogpost. No sub-titles are allowed, nor are line-breaks.
title = "Cases2Beds: A Case Study in Actionable Intelligence Highlights"
# Date must be written in YYYY-MM-DD format. This should be updated right before the final PR is made.
date = 2022-01-06

[taxonomies]
# Keep any areas that apply, removing ones that don't. Do not add new areas!
areas = ["Artificial Intelligence"]
# Tags can be set to a collection of a few keywords specific to your blogpost.
# Consider these similar to keywords specified for a research paper.
tags = ["COVID-19", "Actionable Intelligence"]

[extra]
# For the author field, you can decide to not have a url.
# If so, simply replace the set of author fields with the name string.
# For example:
#   author = "Harry Bovik"
# However, adding a URL is strongly preferred
author = {name = "Ananya Joshi", url = "https://csd.cmu.edu/people/graduate-student/ananya-joshi" }
# The committee specification is simply a list of strings.
# However, you can also make an object with fields like in the author.
committee = [
    "Ryan Tibshirani",
    "Zico Kolter",
    "Pallavi Koppol"
]
+++






*This blog post is adapted from the [Delphi blog](https://delphi.cmu.edu/blog/2021/03/10/cases2beds-a-case-study-in-actionable-intelligence/), originally published on March 10th, 2021. Again, thank you to the Allegheny County Health Department, the DELPHI Group, Chris Scott, and Roni Rosenfeld.*



One of the [Delphi Group](https://delphi.cmu.edu/)’s goals is to create informative tools for healthcare organizations. Tools are only useful if the insights they provide can inform concrete actions. That is to say, these tools must provide actionable intelligence. In early November 2020, as COVID case rates in Allegheny County continued to rise, the Delphi Group partnered with ACHD to create such tools for investigating if hospitals located in the county would run out of hospital beds for COVID patients <a href="#f1">(Fig. 1)</a>.

<div id="f1"></div>

![Image of the hospitalizations due to COVID-19 and new cases from positive PCR tests in Allegheny County](./WPRDC-1.svg)
**Fig. 1:** Hospitalizations Due to COVID-19 and New Cases from Positive PCR Tests in Allegheny County (WPRDC Data <sup>[1](#WPRDCLink)</sup>)


Based on its planning, the ACHD needed at least a week to open emergency COVID facilities. If the emergency space wasn’t open and hospital beds ran out, mortality rates could soar. But, if we didn’t need the facility, that decision would have stretched already thin resources. Many of the hospitals in Allegheny County were in contact, but each hospital system only had visibility into its own facilities. We wondered if we could offer a higher-level view for ACHD to assist in its planning.


## A probabilistic approach

To provide county-level intelligence on hospital bed usage, we developed Cases2Beds<sup>[2](#Cases2BedsLink)</sup>.


To extrapolate beds utilization 1-2 weeks in the future, we needed to estimate:

1. The probability that a person who tested positive for COVID-19 would require hospitalization
2. How many days after testing a person would be hospitalized
3. How long a person with COVID would stay in the hospital
4. The current number of positive COVID tests

These values vary by demographic factors, most notably age (<a href="#f2">Fig. 2</a>), and to a lesser extent, sex and race.

<div id="f2"></div>


![Age Group Comparisons based on the Allegheny County COVID-19 Tableau](./C2B-1.svg)
**Fig. 2:** Age Group Comparisons based on the Allegheny County COVID-19 Tableau <sup>[3](#ACHDDashboardLink)</sup>


We used public data from Allegheny County about the number of people tested, test positivity rate, and hospitalization rate, broken down by the aforementioned demographic factors.
We also acquired information for two critical parameters: 

- Offset: Offset is the number of days between the day of testing (called specimen collection date) and the first day of hospitalization. For example, if the test date were 5 days before hospitalization, the offset would be 5 days. Also, if the test date is the hospital admit date, the offset would be 0 days (or sometimes -1 or +1 days). Notably, the offset can be negative, meaning a person may have been tested some days or weeks after admission.
- Length of Stay: The length of stay is approximately how many days a person uses a bed in the hospital (± 1 day).

Given the hospitalization rate, the offset distribution, and the length of stay distribution, we can simulate multiple futures for any given set of positive cases and their testing dates. Estimating the future given a set of probabilities is a common problem and a possible approach is called a Monte Carlo simulation. This process ultimately shows the expected distribution of the number of beds needed each day.

Monte Carlo simulations involve running a huge number of scenarios based on a set of probabilities. The more scenarios run, the more accurate the model tends to be. For example, if you gave 1000 people one dart to throw at a dartboard, even though each throw may not be very good, you’d still be able to get a pretty good idea of where the bull’s eye is after 1000 throws. This is the same principle we applied for Cases2Beds – after many simulations, we had a good idea of how many beds might be needed in the next two weeks.

Our prototype Monte Carlo simulation was written in Python and had a runtime of a few minutes. However, because the simulation works best with probabilities derived from Protected Health Information (PHI), ACHD needed to run it privately and offline so there would be no data transmission. Thus, any type of web application (which would transmit data to our servers) was ruled out. Even asking ACHD to run our Python software on their machines fell into a grey area. However, Microsoft Excel was easy to use and supported by ACHD. So we converted Cases2Beds into a spreadsheet.

It is relatively straightforward to port the Python application to VBScript macros for Microsoft Excel. However, those macros aren’t designed to run large simulations, and we saw that the time required to generate a model was far worse, bordering on unusable.

## An alternative to Monte Carlo: the analytical model

As an alternative, we developed an analytical model for Microsoft Excel that offered a much faster run time than the full Monte Carlo simulation. The sheet has two tabs of inputs: constant parameters (first tab, static), and case counts (second tab, dynamic). 

The analytical model had the same idea as the Monte Carlo simulation. Some fraction of individuals who test positive today will be hospitalized after a varying offset (from test date to admit date) and variable duration (from admit date to discharge date) based on their characteristics. In the spreadsheet tab 1, anyone can change these parameters to fit their region.

The characteristics are:

1.  Age Group: (Most important) [unspecified, 0-9, 10-19, 20-29 … 70-79, 80+]
2.  Sex: [unspecified, M, F]
3.  Race: [unspecified, Black, White, Hispanic, Asian]

And the parameters are:

1.  Hospitalization Rate
2.  Offset Distribution Parameter Set: Parameters describing the number of days before someone who tests positive is hospitalized
3.  Duration Distribution Parameter Set: Parameters describing the number of days someone will be in the hospital

The second types of inputs are the daily positive cases split by their traits. This is the input that the user actively changes on their end.

Behind the scenes, we take these parameters (first input tab) and generate Offset Fractions, which is the probability that a patient with given traits will occupy a bed for a duration k days after the specimen testing date. These Offset Fractions and the daily positive case breakdown (second input) give us the expected mean and variance up to 1 month in the future of the number of patients in the hospital per day based on the cases already seen. This information can be used to generate plots like <a href="#f3">(Fig. 3)</a>. This graph isn’t to suggest that there won’t be any need for beds after February! It is just that based on the cases we know, very few people will be hospitalized for more than a month.

<div id="f3"></div>

![Output of Cases2Beds using historical data until January 21st for Allegheny County Using Public Parameters](./rates-1.svg)
**Fig. 3:**  Output of Cases2Beds using historical data until January 21st for Allegheny County Using Public Parameters

If we assume independence between patients, the mean and variance calculations are exact. However, our quantile estimates are based on approximating the sum of independent binary variables, which is inaccurate near the tails. So the accuracy of the more extreme quantiles (95%+) depends on the number of cases present, which in practice makes them less trustworthy.


## Cases2Beds in Action

By the end of November 2020, we had a viable prototype Cases2Beds spreadsheet used by ACHD. Over the following months, we made various modifications with their feedback. For example, the ACHD staff did not have time to manually input case numbers. So, we were able to use the granular public data to give them estimates of future hospital utilization without any additional work on their end. 
At the peak of bed utilization, hospital systems themselves increased their COVID beds utilization to 6x more than in October 2020 <a href="#f4">(Fig. 4)</a>. Fortunately, in Allegheny County, we never reached a point where demand for beds exceeded a somewhat elastic supply. By early January 2021, multiple organizations told us that the pandemic’s most acute problem had changed to vaccine distribution and the number of COVID-19 beds needed dropped. Cases2Beds continues to act as an early warning system if the number of cases rise quickly.

<div id="f4"></div>


![Numbers of staffed COVID beds over time vs. capacity from the HHS Protect Data](./HHS-1.svg)
**Fig. 4:** Numbers of staffed COVID beds over time vs. capacity from the HHS Protect Data <sup>[5](#HHSLink)</sup>.


We were also able to show the efficacy of the spreadsheet to other health departments and hospitals by generating tailored, public parameters for offset and length of stay from different national public resources, like the Florida line-level COVID dataset <sup>[4](#FloridaLineLevelLink)</sup>. Based on these organizations' feedback that they needed projections more than 2 weeks out, we started to use Cases2Beds as an input to hospital utilization forecasting models. Other inputs to the hospital forecasting model included current hospital bed utilization (from HHS Protect<sup>[5](#HHSLink)</sup>), how long current patients are likely to continue to be hospitalized, and how many new cases there will be in the near future. A preliminary evaluation of such a method shows decent predictive power when parameters are tailored to a location.




## Conclusion

At the peak of bed utilization, hospital systems themselves increased their COVID beds utilization to 6x more than in October 2020. Fortunately, in Allegheny County, we never reached a point where demand for beds exceeded a somewhat elastic supply. By early January, multiple organizations told us that the pandemic’s most acute problem had changed to vaccine distribution and the number of COVID-19 beds needed dropped. Cases2Beds continues to act as an early warning system if the number of cases rise quickly. 




## Finale {#finale}

Cases2Beds was a case study about the realities of research institutions offering actionable intelligence in healthcare. While the Cases2Beds tool demonstrated reasonable predictive power, it was difficult to deploy it in a timely and actionable way. Our most significant challenges were data access and bureaucratic limitations to develop solutions at the granularity needed. 
Research institutions can be effective partners to health organizations, but the next set of challenges of this pandemic–or the next–will require quick action. The tools we build now can set the stage for the future. 
Thank you to the Allegheny County Health Department (especially Antony Gnalian, Dr. LuAnn Brink, and Dr. Debra Bogen) for their invaluable feedback, efforts, and shared interest in actionable intelligence.
Many members of the Delphi Group, including Sumit Agrawal, Katie Mazaitis, and Phil McGuinness, met regularly with the Allegheny County Health Department, provided data, edited this blog post, and investigated various solutions other than Cases2Beds.


## Resources

Please check out the [Cases2Beds Github Repo](https://github.com/cmu-delphi/cases-to-beds-public)

<a id="WPRDCLink">1.</a>  [WPRDC Allegheny County COVID dataset](https://data.wprdc.org/dataset/allegheny-county-covid-19-tests-cases-and-deaths)

<a id="Cases2BedsLink">2.</a> [Cases2Beds Worksheet](https://www.cmu.edu/delphi-web/cases2beds-v0.2.3.xlsm)

<a id="ACHDDashboardLink">3.</a>  [ACHD COVID-19 Dashboard](https://tableau.alleghenycounty.us/t/PublicSite/views/AlleghenyCountyCOVID-19Information_15912788131180/Landingpage?iframeSizedToWindow=true&%3Aembed=y&%3AshowAppBanner=false&%3Adisplay_count=no&%3AshowVizHome=no&%3Aorigin=viz_share_link)

<a id="FloridaLineLevelLink">4.</a>  [Florida line-level COVID dataset](https://experience.arcgis.com/experience/96dd742462124fa0b38ddedb9b25e429)

<a id="HHSLink">5.</a>  [HHS Protect Hospital Utilization Data](https://healthdata.gov/Hospital/COVID-19-Reported-Patient-Impact-and-Hospital-Capa/anag-cw7u)







