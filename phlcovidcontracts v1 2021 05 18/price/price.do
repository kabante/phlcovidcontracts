global path_proc "" // insert path of folder where the original XLSX is

* Internal
import excel "$path_proc/price_raw.xlsx", first sheet(PriceAnalytics_Internal) clear

missings dropobs, force
ds, has(type string) 
format `r(varlist)' %15s

replace UnitPrice = subinstr(UnitPrice, ",", "", .)
gen price = real(UnitPrice)
gen qty = real(Quantity)
gen amount = real(Amount)
drop if price == . // 20 observations dropped

bysort TransactionID: gen num_trans = _n
egen num_item = max(num_trans), by(TransactionID)

** No Conversion (as is)
gen count = 1
egen count_total = sum(count), by(ProductSKUIDexact)
tab count_total // number of items excluded is if count_total = 1
tab ProductSKUIDexact if regexm(ProductSKUIDex, "UNKNOWN") == 1 // 314 observations
tab ProductSKUIDexact if count_total == 1 & regexm(ProductSKUIDex, "UNKNOWN") == 0 // 194 observations

egen price_min = min(price), by(ProductSKUIDexact)
egen price_mean = mean(price), by(ProductSKUIDexact)
egen price_med = median(price), by(ProductSKUIDexact)
gen price_med10 = price_med*1.1

gen price_dev_mean = (price - price_mean)/price_mean
gen price_dev_min = (price - price_min)/price_min
gen price_dev_med = (price - price_med)/price_med
gen price_dev_med10 = (price - price_med10)/price_med10

egen trans_totamt = sum(amount), by(TransactionID)

foreach x in med med10 {
gen price_high_`x' = 1 if price_dev_`x' > 0 & price_dev_`x' != .
replace price_high_`x' = 0 if price_dev_`x' <= 0 & price_dev_`x' != .

egen trans_numhigh_`x' = sum(price_high_`x'), by(TransactionID)
egen trans_tothigh_`x' = count(price_high_`x'), by(TransactionID)
gen trans_pcthigh_`x' = trans_numhigh_`x'/trans_tothigh_`x'

gen amount_`x' = qty*price_`x'
gen dev_`x'_amount = amount - amount_`x'

egen trans_totamt`x' = sum(amount_`x'), by(TransactionID)
gen trans_totamtdev_`x' = (trans_totamt-trans_totamt`x')
gen trans_totpctdev_`x' = (trans_totamt-trans_totamt`x')/trans_totamt`x'
}

egen total_saving_med = sum(dev_med_amount), by(price_high_med)
sum total_saving_med if price_high_med == 1 & dev_med_amount >= 0
disp "`r(mean)'" // 190M

egen total_saving_med10 = sum(dev_med10_amount), by(price_high_med10)
sum total_saving_med10 if price_high_med10 == 1 & dev_med10_amount >= 0
disp "`r(mean)'" // 71M

tab ProductSKUIDexact if count_total > 1, sort
gen ID_new = "Rice" if ProductSKUIDexact == "RICE_50KG"
replace ID_new = "Sardines" if ProductSKUIDexact == "CAN_SARDINES_100CANS_155G"
replace ID_new = "N95" if ProductSKUIDexact == "MASK_N95_1PC"
replace ID_new = "Coverall" if ProductSKUIDexact == "COVERALL_1PC"
replace ID_new = "Alcohol" if ProductSKUIDexact == "ALCOHOL_1BTL_1GAL"
replace ID_new = "Noodles" if ProductSKUIDexact == "NOODLES_1PC"
replace ID_new = "Face Shield" if ProductSKUIDexact == "SHIELD_FACE_1PC"
replace ID_new = "Gloves" if ProductSKUIDexact == "GLOVES_SURG_50PCS"
replace ID_new = "Thermometer" if ProductSKUIDexact == "THERMAL_SCANNER_1PC"
replace ID_new = "Goggles" if ProductSKUIDexact == "GOGGLES_1PC"
replace ID_new = "Gown" if ProductSKUIDexact == "GOWN_1PC"

bysort ID_new: sum price, det

egen mean_var = mean(price), by(ID_new)
egen sd_var = sd(price), by(ID_new)
gen norm_price = (price - mean_var)/sd_var

graph box norm_price, over(ID_new, label(angle(45))) ytitle("Normalized Price") graphregion(color(white)) title("Internal Price Distribution of Procured Items")
graph export "$path_proc/price_internal.png", replace

save "$path_proc/price_internal_analytics.dta", replace

* External
import excel "$path_proc/price_raw.xlsx", first sheet(PriceAnalytics_External) clear
replace ProductSKUIDconvert = "" if ProductSKUIDconvert == "0"
replace Conversion = . if Conversion == 0

missings dropobs, force
ds, has(type string) 
format `r(varlist)' %15s

drop if ProductSKUIDexact == "RICE_1KG" & SourceofPriceData != "PSA" & SourceofPriceData != "DA"

preserve

gen ext_price = real(UnitPrice)
replace ext_price = ext_price*34.84 if Currency == "AUD"
replace ext_price = ext_price*56.87 if Currency == "EUR"
replace ext_price = ext_price*61.87 if Currency == "GBP"
replace ext_price = ext_price*6.25 if Currency == "HKD"
replace ext_price = ext_price*11.72 if Currency == "MYR"
replace ext_price = ext_price*35.52 if Currency == "SGD"
replace ext_price = ext_price*48.46 if Currency == "USD"

drop if ext_price == .

expand 2 if regexm(ProductSKUIDexact, "RICE") == 1, gen(dupindicator)
replace ext_price = ext_price*50 if dupindicator == 0 & regexm(ProductSKUIDexact, "RICE") == 1
replace ProductSKUIDexact = "RICE_50KG" if dupindicator == 0 & regexm(ProductSKUIDexact, "RICE") == 1
replace ext_price = ext_price*25 if dupindicator == 1 & regexm(ProductSKUIDexact, "RICE") == 1
replace ProductSKUIDexact = "RICE_25KG" if dupindicator == 1 & regexm(ProductSKUIDexact, "RICE") == 1

egen ext_price_min = min(ext_price), by(ProductSKUIDexact)
egen ext_price_med = median(ext_price), by(ProductSKUIDexact)
egen ext_price_mean = mean(ext_price), by(ProductSKUIDexact)
egen ext_price_max = max(ext_price), by(ProductSKUIDexact)
gen ext_price_med10 = ext_price_med*1.1

bysort ProductSKUIDexact: gen order = _n
egen ext_count = max(order), by(ProductSKUIDexact)
keep if order == 1
keep SourceofPriceData ProductSKUIDexact ext_price_min ext_price_med ext_price_mean ext_price_max ext_price_med10 ext_count

save "$path_proc/price_external_analytics.dta", replace
restore 

* Merge datasets
use "$path_proc/price_internal_analytics.dta", clear
merge m:1 ProductSKUIDexact using "$path_proc/price_external_analytics.dta", force gen(merge_orig)
drop if merge_orig == 2

tab ProductSKUIDexact if regexm(ProductSKUIDex, "UNKNOWN") == 1 & merge_orig == 1 // 312 observations
tab ProductSKUIDexact if regexm(ProductSKUIDex, "UNKNOWN") == 0 & merge_orig == 1 // 431 observations

egen ext_totamt = sum(amount), by(TransactionID)

** No Conversion (as is)
foreach x in med med10 {
gen ext_dev_`x' = (price - ext_price_`x')/ext_price_`x' if merge_orig == 3

gen ext_price_high_`x' = 1 if ext_dev_`x' > 0 & ext_dev_`x' != . & merge_orig == 3
replace ext_price_high_`x' = 0 if ext_dev_`x' <= 0 & ext_dev_`x' != . & merge_orig == 3

egen ext_numhigh_`x' = sum(ext_price_high_`x'), by(TransactionID)
egen ext_tothigh_`x' = count(ext_price_high_`x'), by(TransactionID)
gen ext_pcthigh_`x' = ext_numhigh_`x'/ext_tothigh_`x'

gen ext_amount_`x' = qty*ext_price_`x' if merge_orig == 3
gen ext_dev_`x'_amount = amount - ext_amount_`x' if merge_orig == 3

egen ext_totamt`x' = sum(ext_dev_`x'_amount), by(TransactionID)
gen ext_totamtdev_`x' = ext_totamt-ext_totamt`x' if merge_orig == 3
gen ext_totpctdev_`x' = (ext_totamt-ext_totamt`x')/ext_totamt`x' if merge_orig == 3
}

egen ext_total_saving_med = sum(ext_dev_med_amount), by(ext_price_high_med merge_orig)
sum ext_total_saving_med if ext_price_high_med == 1 & merge_orig == 3 & ext_dev_med_amount >= 0
disp "`r(mean)'" // 550M

egen ext_total_saving_med10 = sum(ext_dev_med10_amount), by(ext_price_high_med10 merge_orig)
sum ext_total_saving_med10 if ext_price_high_med10 == 1 & merge_orig == 3 & ext_dev_med10_amount >= 0
disp "`r(mean)'" // 319M

merge m:1 TransactionID using "$path_proc/procurement_info.dta", gen(merge_pe)
drop if merge_pe == 2

export excel using "$path_proc/Price_Analytics_Items.xlsx", replace first(var)
