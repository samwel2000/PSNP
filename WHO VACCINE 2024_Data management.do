********************************************************************************
*               AIM: MR DATA MANAGEMENT
*         CREATED: JUNE 2024, BY: slwambura@ihi.or.tz/+255652068080
********************************************************************************

* Directories
global gpath "C:\Users\slwambura\OneDrive\Work files\IHI\PROJECTS\MEASLE RUBELLA\2024\DM and Analysis"
global pathdict "$gpath\Tools"
global pathdo "$gpath\Dofiles"
global pathraw "$gpath\Raw"
global pathproc "$gpath\Processed"
global pathout "$gpath\Outputs"


**** Code for creating data labelling do-files from ODK
*declare name for the choice and survey file
local surveyname  survey  
local choicesname choices 
local nameproject _label 

************************************************
*THE CODE BELOW CREATE DO FILES FOR LABELLING VARIABLES
************************************************
cd "$pathdict"

	// READ IN THE SURVEY FILE
import delimited "`surveyname'.csv", delimiter(comma) varnames(1) clear 
keep type name label

drop if name=="" |type=="note" | type=="begin group"  | type=="end group" | type=="begin repeat"  | type=="calculate"  ///
| type=="name" | type=="start" | type=="end" | type=="deviceid" |type=="gps"
compress
replace name=lower(name)
drop if label==""

*create a statement for labelling variables
gen varlabel_command_1 = "capture label variable " + name + `" ""' + label + `"""' 

cd "$pathdos"
// WRITE IT ALL OUT TO A DO FILE
file open handle using "$pathdo\Lvariable_`nameproject'.do", write text replace
forvalues i = 1/`=_N' {
 file write handle (varlabel_command_[`i']) _n
}
file close handle

                       
			
*************************************************
*THE CODE BELOW CREATE DO FILES FOR LABELING VALUES OF VARIABLES
*************************************************
cd "$pathdict"
import delimited "`surveyname'.csv", delimiter(comma) varnames(1) clear 

keep if index(type,"select_one")
split type
keep type2 name
rename type2 label_name
replace label_name=trim(label_name)
replace name=lower(name)
rename name varname
tempfile choices
save `choices'

// READ IN THE CHOICES FILE
import delimited "`choicesname'.csv", delimiter(comma) varnames(1) clear bindquote(strict)
destring name, replace


// CREATE MNEMONIC VARIABLE NAMES
rename list_name label_name
rename name value
rename label value_label
keep  value_label value label_name

// BUILD UP THE VALUE LABELS
tostring value, replace
by label_name (value), sort: gen label_command_1 = "capture label define " + label_name ///
 + " " +(value) + `" ""' + value_label + `"""' if _n == 1
by label_name (value): replace label_command_1 = label_command_1[_n-1] ///
 + " " +(value) + `" ""' + value_label + `"""' if _n > 1
by label_name (value): keep if _n == _N
keep label_name label_command_1

*get variable names
merge 1:m label_name using `choices'
keep if _merge==3

// AND COMMANDS TO APPLY THE VALUES TO THE VARIABLES
gen label_command_2 = "capture label values " + varname + " " + label_name

// RESHAPE LONG TO LOOK LIKE A FILE OF COMMANDS ON SEPARATE LINES OF A DO FILE
keep label_name  varname label_command*
duplicates drop varname,force
reshape long label_command_, i(varname) j(_j)


// WRITE IT ALL OUT TO A DO FILE
file open handle using "$pathdo\Lvalues`nameproject'.do", write text replace
forvalues i = 1/`=_N' {
 file write handle (label_command[`i']) _n
} 
file close handle


***************************************************************
*THE CODE BELOW CREATE DO FILES FOR REMOVING GROUPS IN VARIABLE NAMES
***************************************************************
// READ IN THE SURVEY FILE
import delimited "`surveyname'.csv", delimiter(comma) varnames(1) bindquote(strict) clear 
keep if index(type,"begin")
keep name 
replace name=lower(name)

count 
local novariables `r(N)'
cap ssc inst sxpose
sxpose,clear 

egen allvar=concat(_var1-_var`novariables'), punct(" ")
keep allvar
gen foreachcode = "foreach varname in " + allvar + " {" 
gen label_command_1 = "renpfix " + "`" + "varname" + "'"
gen label_command_2 = "}"

// RESHAPE LONG TO LOOK LIKE A FILE OF COMMANDS ON SEPARATE LINES OF A DO FILE
keep foreachcode label_command*
reshape long label_command_, i(foreachcode) j(_j)

file open handle using "$pathdo\removegroup`nameproject'.do", write text replace
file write handle (foreachcode) _n

forvalues i = 1/`=_N' {
 file write handle (label_command[`i']) _n
  } 
file close handle



******************************************************************
* THE CODE BELOW CREATES DO FILE FOR LABELLING MULTIPLE SELECT QUESTIONS
******************************************************************
* Code to label multiple select questions (Arleady run)
import delimited "`surveyname'.csv", delimiter(comma) varnames(1) bindquote(strict) clear

keep if index(lower(type), "multiple")
// Check incase select were used without underscore
split type, p(" ")
rename (type2 name) (list_name  varname)
keep list_name varname

tempfile survey
save `survey', replace

import delimited "`choicesname'.csv", delimiter(comma) varnames(1) clear bindquote(strict)
keep if !missing(list_name)
keep list_name name label

merge m:m list_name using `survey'
keep if _merge == 3
drop _merge

gen variable = varname + name
gen label_command_ = "cap lab var " + variable + `" ""' + label + `"""' 
gen label_command_2_ = "capture label values " + variable + " mnoyes" 
expand 2 if  _n==_N
replace label_command_ = "label define mnoyes 0 " + `"""' + "No" + `"""' + " 1 " + `"""'  + "Yes" +`"""' + ", modify" if _n==_N
keep label_command_ label_command_2_


// WRITE IT ALL OUT TO A DO FILE
file open handle using "$pathdo\LMvariable`nameproject'.do", write text replace
forvalues i = 1/`=_N' {
 file write handle (label_command_[`i']) _n
}
file close handle


file open handle using "$pathdo\LMvariable`nameproject'.do", write text append
forvalues i = 1/`=_N' {
 file write handle (label_command_2_[`i']) _n
}
file close handle


*==========================> DATA CLEANING STARTS HERE <======================
** Import raw main data
import delimited "$pathraw\WHO_VACCINE_2024.csv", bindquote(strict) delimiter(comma) varnames(1) clear 

** Remove ODK specific vars
drop name1-age25

** number of eligible housheolds (have under 5)
gen has_u5 = (sum_child4 > 0)
label var has_u5 "Eligible HH (Has eligible child for either RI or MR)"

** Clean Ra names
replace submittername = "SALUM MRISHO MGALLAH" if deviceid=="collect:5CGBJtfXrcHmNPd2"
replace submittername = "ARAFA HUSSEIN MASOUD" if deviceid=="collect:EdLs7fST1orYkUCZ"
replace submittername = "EMMANUEL MASHAMO" if deviceid=="collect:NiPlDC3BclcmxclQ"
replace submittername = "YONA MWAIGOMBE" if deviceid=="collect:kmGsOmmlsGCs1RtT"
replace submittername = "SADA MKELEMI"  if deviceid=="collect:iTXtadfqo4PlZbnj"


// Change status of test records into rejected. these will be droped
replace reviewstate = "rejected" if instanceid=="uuid:59f44568-0ab1-4d39-b3ab-ba9f0ac0036a"
replace reviewstate = "rejected" if instanceid=="uuid:ab758de0-dbd8-44a4-a330-649603511057"
replace reviewstate = "rejected" if instanceid == "uuid:7ce6e675-f45d-4cdf-96b5-c7da0246a85a"

replace region = strproper(region)
replace today = hm13 if date(today,"YMD") < d(1june2024)


* Household size categorization
ta hh_count
recode hh_count (2/5 = 0 "2-5") (6/8 = 1 "6-8") (9/max = 2 "9+"), gen(hh_countcat)

** Occupation recategorization
recode hm_ses1 (1 = 0 "Farmer") (2 5 6 7 = 1 "Employed") (3/4 = 2 "Business") (0 96 = 96 "Other"), gen(hm_ses1b)
rename hm_ses1 hm_ses1a
rename hm_ses1b hm_ses1

* Wealth quintiles
gen ses1 = (hm_ses2==2)  //own house
gen ses2 = (hm_ses4==1)  //has mosquito net
gen ses31 = (hm_ses61==1) //Bicycle
gen ses32 = (hm_ses62==1) //Car
gen ses33 = (hm_ses63==1) //Motorcycle
gen ses34 = (hm_ses64==1) //Radio
gen ses35 = (hm_ses65==1) //Fridge
gen ses36 = (hm_ses66==1) //Television
gen ses37 = (hm_ses67==1) //Watch
gen ses39 = (hm_ses69==1) //Sofa
gen ses310 = (hm_ses610==1) //Bed
gen ses311 = (hm_ses611==1) //Iron
gen ses313 = (hm_ses613==1) //Matress
gen ses314 = (hm_ses614==1) //Wardrobe
gen ses315 = (hm_ses615==1) //Water pump
gen ses316 = (hm_ses616==1) //Sewing machine
gen ses318 = (hm_ses618==1) //Satellite dish
gen ses319 = (hm_ses619==1) //Fan
gen ses320 = (hm_ses620==1) //Cellphone
gen ses41 = (hm_ses71==1) //Cow
gen ses42 = (hm_ses72==1) //Donkey
gen ses43 = (hm_ses73==1) //Goat
gen ses44 = (hm_ses74==1) //Sheep
gen ses45 = (hm_ses75==1) //Hen or duck
gen ses46 = (hm_ses76==1) //Pig
gen ses5 = ( hm_ses8 == 1 ) //farm
gen ses6 = (hm_ses91==1 | hm_ses92==1) //Tiles, concrete, cement,Tin, asbestos
gen ses7 = (hm_ses11 ==1 | hm_ses11==2) //Electricity, gas, sun,Kerosene, biogas (gas from animal waste), charcoal 
gen ses8 = (hm_ses12==1) //Electricity
gen ses82 = (hm_ses12==1) //Solar
gen ses9 = (hm_ses13==1 | hm_ses13==2) //Tap (inside the house),Well (private. Owned by the household)
gen ses10 = (hm_ses15==1 | hm_ses15==3) //Toilet type (modern and owned by housheold)
gen ses11 = (hm_ses16 == 1 | hm_ses16 == 2 | hm_ses16 == 3) //Housewalls
gen ses12 = (hm_ses17 == 4 ) // floor material
gen ses13 = (hm_ses18 == 1) // pension beneficiary

** Create wealth quintiles
pca ses1-ses13

predict pc1

xtile quint= pc1, nq(5) 
label def quint 1 "Lowest" 2 "Second" 3 "Middle" 4 "Fourth" 5 "Highest"
label val quint quint


rename key hhkey
tempfile main
save `main', replace

import delimited "$pathproc/Sampling.csv", bindquote(strict) clear
replace region = strproper(region)
merge 1:m region district ward village ea using `main'
keep if _merge > 1
drop _merge

** Generate starata and EA identifiers
gen psustrata = region+ "_" + residence
replace psustrata = region+"_"+district if region=="Dar Es Salaam"
gen eaid = region + "_" + district + "_" + ward + "_" + village + "_" + ea

save "$pathproc/WHO_VACCINE_2024_main.dta", replace


********************************************************************************
* Combine household roster with household information
********************************************************************************
import delimited "$pathraw\WHO_VACCINE_2024-member.csv", bindquote(strict) delimiter(comma) varnames(1) clear 

rename parent_key hhkey

gen names = hm23 + " - " + string(ageinyears)
replace names = subinstr(names,"- .", "- 0.",.)

* Categorize age
recode ageinyears (min/24 = 0 "18 - 24") (24.1/34 = 1 "25 - 34") (34.1/max = 2 "34+"), gen(magecat)

* Education level 
recode hm35 (0 = 0 "No formal education") (1/2 = 1 "Primary education") (3/6 = 2 "Secondary education and more") (96 = 96 "Dont know"), gen(meduc)
replace meduc = 0 if hm34 == 2  // never attended to no formal education

* Marital status
recode hm33 (6 = 0 "Single/Not in  union") (4/5 = 1 "Married/Cohabited") (2/3 = 2 "Separated/Divorced") (1 = 3 "Widowed"), gen(mmarital)

duplicates drop hhkey names, force  //remove duplicate members entered

merge m:1 hhkey using "$pathproc/WHO_VACCINE_2024_main.dta"

*drop if _merge != 3   // remove hhmembers from households with no under 5 and households with no members (rejected hh)
rename _merge hhrostermmerge

save "$pathproc/WHO_VACCINE_2024_members.dta", replace


*******************************************************************************
* Combine eligible mothers with roster to get mothers demographic and hh info
*******************************************************************************
import delimited "$pathraw\WHO_VACCINE_2024-eligible_mothers.csv", bindquote(strict) delimiter(comma) varnames(1) clear 
 
** Replace values of incorrect entries
replace permission = 2 if noeligible_child == 0
replace noeligible_child = . if noeligible_child == 0


** Clean sources of MR campign from other text
*** criers or mobilizers
replace sia185 = 1 if index(lower(sia19),"gari") | index(lower(sia19),"nduru")  | index(lower(sia19),"mbiu") | index(lower(sia19),"matangazo") | index(lower(sia19),"tangaz") | index(lower(sia19),"vipaza")
replace sia1896 = 0 if index(lower(sia19),"gari") | index(lower(sia19),"nduru") | index(lower(sia19),"mbiu") | index(lower(sia19),"matangazo") | index(lower(sia19),"tangaz") | index(lower(sia19),"vipaza")
replace sia19 = "." if index(lower(sia19),"gari") | index(lower(sia19),"nduru") | index(lower(sia19),"mbiu") | index(lower(sia19),"matangazo") | index(lower(sia19),"tangaz") | index(lower(sia19),"vipaza")

* Church
replace sia1811 = 1 if index(lower(sia19),"kanisa")
replace sia1896 = 0 if index(lower(sia19),"kanisa")
replace sia19 = "." if index(lower(sia19),"kanisa")

* School
replace sia187 = 1 if index(lower(sia19),"shule")
replace sia1896 = 0 if index(lower(sia19),"shule")
replace sia19 = "." if index(lower(sia19),"shule")

* Radio
replace sia182 = 1 if index(lower(sia19),"radio")
replace sia1896 = 0 if index(lower(sia19),"radio")
replace sia19 = "." if index(lower(sia19),"radio")

* Village leader
replace sia1810 = 1 if index(lower(sia19),"mjumbe") | index(lower(sia19),"balozi") | index(lower(sia19),"mwenyeki")
replace sia1896 = 0 if index(lower(sia19),"mjumbe") | index(lower(sia19),"balozi") | index(lower(sia19),"mwenyeki")
replace sia19 = "." if index(lower(sia19),"mjumbe") | index(lower(sia19),"balozi") | index(lower(sia19),"mwenyeki")

rename parent_key hhkey
rename key motherkey
rename mothername names

do "$pathdo/_Clean_caretakers_names.do"

merge m:1 hhkey names using "$pathproc/WHO_VACCINE_2024_members.dta"

** Keep caregivers only
keep if _merge == 3

rename _merge eligiblemerge
save "$pathproc/WHO_VACCINE_2024_eligible_mothers.dta", replace



********************************************************************************
* Combine with child vaccination information
********************************************************************************
import delimited "$pathraw\WHO_VACCINE_2024-vaccination.csv", bindquote(strict) delimiter(comma) varnames(1) clear 
do "$pathdo/LMvariable_label.do"
do "$pathdo/Lvalues_label.do"
do "$pathdo/Lvariable__label.do"
do "$pathdo/removenote_label.do"

rename parent_key motherkey

gen age12_23 = ageinmonths>= 12 & ageinmonths < 24  // At the time of the survey
gen age9_59 = ageinmonths2>= 9 & ageinmonths2 < 60 // At the time of the campaign
gen age9_36 = ageinmonths>= 9 & ageinmonths < 36 // At the time of the survey

** Clean reasons for no mr vaccination from other text
// Did not know about the campaign
replace sia252 = 1 if index(lower(sia26),"sikia") | index(lower(sia26),"taarifa")
replace sia2596 = 0 if index(lower(sia26),"sikia") | index(lower(sia26),"taarifa")
replace sia26 = "" if index(lower(sia26),"sikia") | index(lower(sia26),"taarifa")


// Mother busy
replace sia2520 = 1 if (index(lower(sia26),"mama") & (index(lower(sia26),"safiri")|index(lower(sia26),"safar"))) | (index(lower(sia26),"nilisafir")) | (index(lower(sia26),"shamba")) | (index(lower(sia26),"shaba"))
replace sia2596 = 0 if (index(lower(sia26),"mama") & (index(lower(sia26),"safiri")|index(lower(sia26),"safar"))) | (index(lower(sia26),"nilisafir")) | (index(lower(sia26),"shamba")) | (index(lower(sia26),"shaba"))
replace sia26 = "" if (index(lower(sia26),"mama") & (index(lower(sia26),"safiri")|index(lower(sia26),"safar"))) | (index(lower(sia26),"nilisafir")) | (index(lower(sia26),"shamba")) | (index(lower(sia26),"shaba"))

* child not living in this household
replace sia2527 = 1 if index(lower(sia26),"akiishi na mama yake sehemu nyingine")
replace sia2596 = 0 if index(lower(sia26),"akiishi na mama yake sehemu nyingine")
replace sia26 = "." if index(lower(sia26),"akiishi na mama yake sehemu nyingine")

*Confused with vaccines
replace sia251 = 1 if index(lower(sia26),"ameshapata chanjo") | index(lower(sia26),"alishapata chanjo") | index(lower(sia26),"ametoka kupata chanjo wiki iliyopita") | index(lower(sia26),"alijua chanjo zote mtoto kamaliza") | index(lower(sia26),"amwtoka kuchanja juma") | index(lower(sia26),"chanjo zote mtoto kamaliza") | index(lower(sia26),"chanjo ya surua tayari")
replace sia2596 = 0 if index(lower(sia26),"ameshapata chanjo") | index(lower(sia26),"alishapata chanjo") | index(lower(sia26),"ametoka kupata chanjo wiki iliyopita") | index(lower(sia26),"alijua chanjo zote mtoto kamaliza") | index(lower(sia26),"amwtoka kuchanja juma") | index(lower(sia26),"chanjo zote mtoto kamaliza") | index(lower(sia26),"chanjo ya surua tayari")
replace sia26 = "." if index(lower(sia26),"ameshapata chanjo") | index(lower(sia26),"alishapata chanjo") | index(lower(sia26),"ametoka kupata chanjo wiki iliyopita") | index(lower(sia26),"alijua chanjo zote mtoto kamaliza") | index(lower(sia26),"amwtoka kuchanja juma") | index(lower(sia26),"chanjo zote mtoto kamaliza") | index(lower(sia26),"chanjo ya surua tayari")

*Long waiting time
replace sia2524 = 1 if index(lower(sia26),"foleni ilikuwa")
replace sia2596 = 0 if index(lower(sia26),"foleni ilikuwa")
replace sia26 = "." if index(lower(sia26),"foleni ilikuwa")


*mother too busy
replace sia2520 = 1 if index(lower(sia26),"mama haku") | index(lower(sia26),"sikuwe") | index(lower(sia26),"sikue") | index(lower(sia26),"alikuwa kazini") | index(lower(sia26),"alikuwa kazini") | index(lower(sia26),"nimesafi") | index(lower(sia26),"alisafiri") | index(lower(sia26),"hakuwe") | index(lower(sia26),"kilim") | index(lower(sia26),"singi") | index(lower(sia26),"mama yake ha") | index(lower(sia26),"visiwani") | index(lower(sia26),"visiwani") | index(lower(sia26),"safarin")  | index(lower(sia26),"safir")   | index(lower(sia26),"safil") | index(lower(sia26),"nilikuwa sipo")  | index(lower(sia26),"wzlinikosa nyum")  | index(lower(sia26),"hakuwep")  | index(lower(sia26),"alisafir")  | index(lower(sia26),"kazi")  | index(lower(sia26),"hayup")  | index(lower(sia26),"hakuwep")   | index(lower(sia26),"nilikuwa mbali")  | index(lower(sia26),"hakuwap")  | index(lower(sia26),"sijaku")  | index(lower(sia26),"sikuwe")  | index(lower(sia26),"kuwep")
replace sia2596 = 0 if index(lower(sia26),"mama haku") | index(lower(sia26),"sikuwe") | index(lower(sia26),"sikue") | index(lower(sia26),"alikuwa kazini") | index(lower(sia26),"alikuwa kazini") | index(lower(sia26),"nimesafi") | index(lower(sia26),"alisafiri") | index(lower(sia26),"hakuwe") | index(lower(sia26),"kilim") | index(lower(sia26),"singi") | index(lower(sia26),"mama yake ha") | index(lower(sia26),"visiwani") | index(lower(sia26),"visiwani") | index(lower(sia26),"safarin")  | index(lower(sia26),"safir")   | index(lower(sia26),"safil") | index(lower(sia26),"nilikuwa sipo")  | index(lower(sia26),"wzlinikosa nyum")  | index(lower(sia26),"hakuwep")  | index(lower(sia26),"alisafir")  | index(lower(sia26),"kazi")  | index(lower(sia26),"hayup")  | index(lower(sia26),"hakuwep")   | index(lower(sia26),"nilikuwa mbali")  | index(lower(sia26),"hakuwap")  | index(lower(sia26),"sijaku")  | index(lower(sia26),"sikuwe")  | index(lower(sia26),"kuwep")
replace sia26 = "." if index(lower(sia26),"mama haku") | index(lower(sia26),"sikuwe") | index(lower(sia26),"sikue") | index(lower(sia26),"alikuwa kazini") | index(lower(sia26),"alikuwa kazini") | index(lower(sia26),"nimesafi") | index(lower(sia26),"alisafiri") | index(lower(sia26),"hakuwe") | index(lower(sia26),"kilim") | index(lower(sia26),"singi") | index(lower(sia26),"mama yake ha") | index(lower(sia26),"visiwani") | index(lower(sia26),"visiwani") | index(lower(sia26),"safarin")  | index(lower(sia26),"safir")   | index(lower(sia26),"safil") | index(lower(sia26),"nilikuwa sipo")  | index(lower(sia26),"wzlinikosa nyum")  | index(lower(sia26),"hakuwep")  | index(lower(sia26),"alisafir")  | index(lower(sia26),"kazi")  | index(lower(sia26),"hayup")  | index(lower(sia26),"hakuwep")   | index(lower(sia26),"nilikuwa mbali")  | index(lower(sia26),"hakuwap")  | index(lower(sia26),"sijaku")  | index(lower(sia26),"sikuwe")  | index(lower(sia26),"kuwep")


*immunization place unknown
replace sia257 = 1 if index(lower(sia26),"chanjo haikupita mtaani")
replace sia2596 = 0 if index(lower(sia26),"chanjo haikupita mtaani")
replace sia26 = "." if index(lower(sia26),"chanjo haikupita mtaani")

*session time inconvinient
replace sia2515 = 1 if index(lower(sia26),"nilichel") | index(lower(sia26),"chelew")
replace sia2596 = 0 if index(lower(sia26),"nilichel") | index(lower(sia26),"chelew")
replace sia26 = "." if index(lower(sia26),"nilichel") | index(lower(sia26),"chelew")

*too ill not given
replace sia2523 = 1 if index(lower(sia26),"mtoto walilazwa hospital")
replace sia2596 = 0 if index(lower(sia26),"mtoto walilazwa hospital")
replace sia26 = "." if index(lower(sia26),"mtoto walilazwa hospital")


*too ill not brought
replace sia2522 = 1 if index(lower(sia26),"anaumwa") | index(lower(sia26),"aliugua") | index(lower(sia26),"ameungua") | index(lower(sia26),"mgonjwa") | index(lower(sia26),"wanaumwa") | index(lower(sia26),"anaumwa")
replace sia2596 = 0 if index(lower(sia26),"anaumwa") | index(lower(sia26),"aliugua") | index(lower(sia26),"ameungua") | index(lower(sia26),"mgonjwa") | index(lower(sia26),"wanaumwa") | index(lower(sia26),"anaumwa")
replace sia26 = "." if index(lower(sia26),"anaumwa") | index(lower(sia26),"aliugua") | index(lower(sia26),"ameungua") | index(lower(sia26),"mgonjwa") | index(lower(sia26),"wanaumwa") | index(lower(sia26),"anaumwa")

*unaware of need
replace sia254 = 1 if index(lower(sia26),"sikuona umu") 
replace sia2596 = 0 if index(lower(sia26),"sikuona umu")
replace sia26 = "." if index(lower(sia26),"sikuona umu") 

*unaware of vaccination time
replace sia258 = 1 if index(lower(sia26),"sahau") | index(lower(sia26),"saau") | index(lower(sia26),"ikuelewa ni wakati gani  wa kumpe") 
replace sia2596 = 0 if index(lower(sia26),"sahau") | index(lower(sia26),"saau") | index(lower(sia26),"ikuelewa ni wakati gani  wa kumpe") 
replace sia26 = "." if index(lower(sia26),"sahau") | index(lower(sia26),"saau") | index(lower(sia26),"ikuelewa ni wakati gani  wa kumpe") 


*Wrong ideas about contraindications
replace sia2510 = 1 if index(lower(sia26),"alielewa vibaya") ///
 | index(lower(sia26),"wanahitajika kuchanjwa watu wazima tu") ///
 | index(lower(sia26),"meshamaliza chanjo ya mwaka mmoja na nusu asipelekwe") ///
 | index(lower(sia26),"haina haja kwani ashapata ya miezi 18") ///
 | index(lower(sia26),"likuwa amepata ya miez 9") ///
 | index(lower(sia26),"hajafikisha miaka 9") ///
 | index(lower(sia26),"umri wake bado") ///
 | index(lower(sia26),"sababu ameshapata chanjo surua 1") ///
 | index(lower(sia26),"liona amesha kua tayari") ///
 | index(lower(sia26),"wake wa kupata chanjo ilikuwa bado") ///
 | index(lower(sia26),"hajafikisha umri wa kupata") ///
 | index(lower(sia26),"ilijua ameshamaliza chanjo") ///
 | index(lower(sia26),"mtoto kwenye hudhurio la kawaida la mwaka na nusu yaani") ///
 | index(lower(sia26),"ameshawahi kupata kwahiyo hakupewa tena") ///
 | index(lower(sia26),"alionekana tayari ameshapata chanjo hiyo") ///
 | index(lower(sia26),"watoto waliokwishapata chanjo ya miezi 9") ///
 | index(lower(sia26),"likuwa ameshapata chanjo") ///
 | index(lower(sia26),"alike wa hajafikisha umri wakati wa") ///
 | index(lower(sia26),"likuwa hajafikisha umri") ///
 | index(lower(sia26),"likuwa mdogo") ///
 | index(lower(sia26),"mpeleka nikaambiwa yeye bado ni mdogo") ///
 | index(lower(sia26),"iki kabla alikuwa  amepata chanjo ya surua") ///
 | index(lower(sia26),"dina aliniambia mtoto bado ni mdogo") ///
 | index(lower(sia26),"muambia tayari ameshapata chanjo") ///
 | index(lower(sia26),"uwa ameshapata chanjo") ///
 | index(lower(sia26),"amepita umri wa chanjo") ///
 | index(lower(sia26),"alinirudisha akanambia nimemaliza mtoto hafai kuchanjwao") ///
 | index(lower(sia26),"wake wa chanjo ulikuwa haujafika") ///
 | index(lower(sia26),"liangalia kadi wakamwambia alishapata kwahiyo hakuchanjwa") ///
 | index(lower(sia26),"ajatimiza umri") ///
 | index(lower(sia26),"lishapatiwa chanjo") ///
 | index(lower(sia26),"rehe yake ya chanjo ya pili ilikuwa") ///
 | index(lower(sia26),"kama amefikisha umri wa kupewa") ///
 | index(lower(sia26),"achakidhi umri") ///
 | index(lower(sia26),"nesi akasema mtotot bado hajafikisha  miezi 9") ///
 | index(lower(sia26),"amepita umri wa chanjo") 	 
replace sia2596 = 0 if index(lower(sia26),"alielewa vibaya") ///
 | index(lower(sia26),"wanahitajika kuchanjwa watu wazima tu") ///
 | index(lower(sia26),"meshamaliza chanjo ya mwaka mmoja na nusu asipelekwe") ///
 | index(lower(sia26),"haina haja kwani ashapata ya miezi 18") ///
 | index(lower(sia26),"likuwa amepata ya miez 9") ///
 | index(lower(sia26),"hajafikisha miaka 9") ///
 | index(lower(sia26),"umri wake bado") ///
 | index(lower(sia26),"sababu ameshapata chanjo surua 1") ///
 | index(lower(sia26),"liona amesha kua tayari") ///
 | index(lower(sia26),"wake wa kupata chanjo ilikuwa bado") ///
 | index(lower(sia26),"hajafikisha umri wa kupata") ///
 | index(lower(sia26),"ilijua ameshamaliza chanjo") ///
 | index(lower(sia26),"mtoto kwenye hudhurio la kawaida la mwaka na nusu yaani") ///
 | index(lower(sia26),"ameshawahi kupata kwahiyo hakupewa tena") ///
 | index(lower(sia26),"alionekana tayari ameshapata chanjo hiyo") ///
 | index(lower(sia26),"watoto waliokwishapata chanjo ya miezi 9") ///
 | index(lower(sia26),"likuwa ameshapata chanjo") ///
 | index(lower(sia26),"alike wa hajafikisha umri wakati wa") ///
 | index(lower(sia26),"likuwa hajafikisha umri") ///
 | index(lower(sia26),"likuwa mdogo") ///
 | index(lower(sia26),"mpeleka nikaambiwa yeye bado ni mdogo") ///
 | index(lower(sia26),"iki kabla alikuwa  amepata chanjo ya surua") ///
 | index(lower(sia26),"dina aliniambia mtoto bado ni mdogo") ///
 | index(lower(sia26),"muambia tayari ameshapata chanjo") ///
 | index(lower(sia26),"uwa ameshapata chanjo") ///
 | index(lower(sia26),"amepita umri wa chanjo") ///
 | index(lower(sia26),"alinirudisha akanambia nimemaliza mtoto hafai kuchanjwao") ///
 | index(lower(sia26),"wake wa chanjo ulikuwa haujafika") ///
 | index(lower(sia26),"liangalia kadi wakamwambia alishapata kwahiyo hakuchanjwa") ///
 | index(lower(sia26),"ajatimiza umri") ///
 | index(lower(sia26),"lishapatiwa chanjo") ///
 | index(lower(sia26),"rehe yake ya chanjo ya pili ilikuwa") ///
 | index(lower(sia26),"kama amefikisha umri wa kupewa") ///
 | index(lower(sia26),"achakidhi umri") ///
 | index(lower(sia26),"nesi akasema mtotot bado hajafikisha  miezi 9") ///
 | index(lower(sia26),"amepita umri wa chanjo") 
replace sia26 = "." if index(lower(sia26),"alielewa vibaya") ///
 | index(lower(sia26),"wanahitajika kuchanjwa watu wazima tu") ///
 | index(lower(sia26),"meshamaliza chanjo ya mwaka mmoja na nusu asipelekwe") ///
 | index(lower(sia26),"haina haja kwani ashapata ya miezi 18") ///
 | index(lower(sia26),"likuwa amepata ya miez 9") ///
 | index(lower(sia26),"hajafikisha miaka 9") ///
 | index(lower(sia26),"umri wake bado") ///
 | index(lower(sia26),"sababu ameshapata chanjo surua 1") ///
 | index(lower(sia26),"liona amesha kua tayari") ///
 | index(lower(sia26),"wake wa kupata chanjo ilikuwa bado") ///
 | index(lower(sia26),"hajafikisha umri wa kupata") ///
 | index(lower(sia26),"ilijua ameshamaliza chanjo") ///
 | index(lower(sia26),"mtoto kwenye hudhurio la kawaida la mwaka na nusu yaani") ///
 | index(lower(sia26),"ameshawahi kupata kwahiyo hakupewa tena") ///
 | index(lower(sia26),"alionekana tayari ameshapata chanjo hiyo") ///
 | index(lower(sia26),"watoto waliokwishapata chanjo ya miezi 9") ///
 | index(lower(sia26),"likuwa ameshapata chanjo") ///
 | index(lower(sia26),"alike wa hajafikisha umri wakati wa") ///
 | index(lower(sia26),"likuwa hajafikisha umri") ///
 | index(lower(sia26),"likuwa mdogo") ///
 | index(lower(sia26),"mpeleka nikaambiwa yeye bado ni mdogo") ///
 | index(lower(sia26),"iki kabla alikuwa  amepata chanjo ya surua") ///
 | index(lower(sia26),"dina aliniambia mtoto bado ni mdogo") ///
 | index(lower(sia26),"muambia tayari ameshapata chanjo") ///
 | index(lower(sia26),"uwa ameshapata chanjo") ///
 | index(lower(sia26),"amepita umri wa chanjo") ///
 | index(lower(sia26),"alinirudisha akanambia nimemaliza mtoto hafai kuchanjwao") ///
 | index(lower(sia26),"wake wa chanjo ulikuwa haujafika") ///
 | index(lower(sia26),"liangalia kadi wakamwambia alishapata kwahiyo hakuchanjwa") ///
 | index(lower(sia26),"ajatimiza umri") ///
 | index(lower(sia26),"lishapatiwa chanjo") ///
 | index(lower(sia26),"rehe yake ya chanjo ya pili ilikuwa") ///
 | index(lower(sia26),"kama amefikisha umri wa kupewa") ///
 | index(lower(sia26),"achakidhi umri") ///
 | index(lower(sia26),"nesi akasema mtotot bado hajafikisha  miezi 9") ///
 | index(lower(sia26),"amepita umri wa chanjo") 


**** CLEANING REASONS FOR NOT COMPLETING RI immunization
*Child ill was not brought for Immunization
replace ri8915 = 1 if index(lower(ri90),"toto kuumwa") | index(lower(ri90),"toto alikuwa anaumwa") | index(lower(ri90),"likuwa mgonjwa wa tumbo") | index(lower(ri90),"alikuwa mgonjwa")
replace ri8996 = 0 if index(lower(ri90),"toto kuumwa") | index(lower(ri90),"toto alikuwa anaumwa") | index(lower(ri90),"likuwa mgonjwa wa tumbo") | index(lower(ri90),"alikuwa mgonjwa")
replace ri90 = "" if index(lower(ri90),"toto kuumwa") | index(lower(ri90),"toto alikuwa anaumwa") | index(lower(ri90),"likuwa mgonjwa wa tumbo") | index(lower(ri90),"alikuwa mgonjwa")


*Family problem including illness of mother 
replace ri8914 = 1 if index(lower(ri90),"nilikuwa naumwa") | index(lower(ri90),"chanjo ya surua ya pili nilisafiri msibani") | index(lower(ri90),"likuwa mgonjwa wa tumbo") | index(lower(ri90),"alikuwa mgonjwa")
replace ri8996 = 0 if index(lower(ri90),"nilikuwa naumwa") | index(lower(ri90),"chanjo ya surua ya pili nilisafiri msibani") | index(lower(ri90),"likuwa mgonjwa wa tumbo") | index(lower(ri90),"alikuwa mgonjwa")
replace ri90 = "" if index(lower(ri90),"nilikuwa naumwa") | index(lower(ri90),"chanjo ya surua ya pili nilisafiri msibani") | index(lower(ri90),"likuwa mgonjwa wa tumbo") | index(lower(ri90),"alikuwa mgonjwa")


*Fear of side reaction
replace ri894 = 1 if index(lower(ri90),"ofu kutokana na madhara aliyopata")
replace ri8996 = 0 if index(lower(ri90),"ofu kutokana na madhara aliyopata")
replace ri90 = "" if index(lower(ri90),"ofu kutokana na madhara aliyopata")


*Mother busy
replace ri8913 = 1 if index(lower(ri90),"busy") | index(lower(ri90),"shambani") | index(lower(ri90),"yasurua sikumpeleka") | index(lower(ri90),"alikuwa hayupo") | index(lower(ri90),"ama hakuwepo") | index(lower(ri90),"ujisahau") | index(lower(ri90),"ziwani nahangaikia") | index(lower(ri90),"amesafiri") | index(lower(ri90),"majukumu ya nyumbani") | index(lower(ri90),"sikuepo") | index(lower(ri90),"muda") | index(lower(ri90),"shamba") | index(lower(ri90),"hakuepo") | index(lower(ri90),"nilisafi") | index(lower(ri90),"muda")
replace ri8996 = 0 if index(lower(ri90),"busy") | index(lower(ri90),"shambani") | index(lower(ri90),"yasurua sikumpeleka") | index(lower(ri90),"alikuwa hayupo") | index(lower(ri90),"ama hakuwepo") | index(lower(ri90),"ujisahau") | index(lower(ri90),"ziwani nahangaikia") | index(lower(ri90),"amesafiri") | index(lower(ri90),"majukumu ya nyumbani") | index(lower(ri90),"sikuepo") | index(lower(ri90),"muda") | index(lower(ri90),"shamba") | index(lower(ri90),"hakuepo") | index(lower(ri90),"nilisafi") | index(lower(ri90),"muda")
replace ri90 = "" if index(lower(ri90),"busy") | index(lower(ri90),"shambani") | index(lower(ri90),"yasurua sikumpeleka") | index(lower(ri90),"alikuwa hayupo") | index(lower(ri90),"ama hakuwepo") | index(lower(ri90),"ujisahau") | index(lower(ri90),"ziwani nahangaikia") | index(lower(ri90),"amesafiri") | index(lower(ri90),"majukumu ya nyumbani") | index(lower(ri90),"sikuepo") | index(lower(ri90),"muda") | index(lower(ri90),"shamba") | index(lower(ri90),"hakuepo") | index(lower(ri90),"nilisafi") | index(lower(ri90),"muda")


*Place & or time of  immunization unknown 
replace ri893 = 1 if index(lower(ri90),"nasubiri waniam") | index(lower(ri90),"utokujua tarehe") | index(lower(ri90),"wakaniambia watanijulisha siku ya kuchanja") | index(lower(ri90),"arehe ya kupata chanjo")
replace ri8996 = 0 if index(lower(ri90),"ofu kutokana na madhara aliyopata")
replace ri90 = "" if index(lower(ri90),"ofu kutokana na madhara aliyopata")


*Place of immunization too far 
replace ri899 = 1 if index(lower(ri90),"mbali")
replace ri8996 = 0 if index(lower(ri90),"mbali")
replace ri90 = "" if index(lower(ri90),"mbali")


*Postponed until another time
replace ri896 = 1 if index(lower(ri90),"haiwezi kufunguliwa mkiwa") | index(lower(ri90),"alisema tupo wachache") | index(lower(ri90),"akienda zahanati anaambiwa chanjo,mara vifaa vya chanjo hamna") | index(lower(ri90),"ya watu aijatimia kukidhi kutoa chanjo") | index(lower(ri90),"ulikua wachache wakasema twende siku nyingine") 
replace ri8996 = 0 if index(lower(ri90),"haiwezi kufunguliwa mkiwa") | index(lower(ri90),"alisema tupo wachache") | index(lower(ri90),"akienda zahanati anaambiwa chanjo,mara vifaa vya chanjo hamna") | index(lower(ri90),"ya watu aijatimia kukidhi kutoa chanjo") | index(lower(ri90),"ulikua wachache wakasema twende siku nyingine") 
replace ri90 = "" if index(lower(ri90),"haiwezi kufunguliwa mkiwa") | index(lower(ri90),"alisema tupo wachache") | index(lower(ri90),"akienda zahanati anaambiwa chanjo,mara vifaa vya chanjo hamna") | index(lower(ri90),"ya watu aijatimia kukidhi kutoa chanjo") | index(lower(ri90),"ulikua wachache wakasema twende siku nyingine") 


*Unaware of need to return  for 2nd or 3rd dose 
replace ri892 = 1 if index(lower(ri90),"kutokuwa na ufahamu just ya dose ya 2 au 3")
replace ri8996 = 0 if index(lower(ri90),"mbali")
replace ri90 = "" if index(lower(ri90),"mbali")

*Vaccinator absent
replace ri8911 = 1 if index(lower(ri90),"watoaji wa chanjo siku hiya hawakufika")
replace ri8996 = 0 if index(lower(ri90),"mbali")
replace ri90 = "" if index(lower(ri90),"mbali")


*Vaccine not available 
replace ri8912 = 1 if index(lower(ri90),"chanjo kukosekana")
replace ri8996 = 0 if index(lower(ri90),"mbali")
replace ri90 = "" if index(lower(ri90),"mbali")


*Wrong ideas about contra indications  
replace ri895 = 1 if index(lower(ri90),"wa kaya hakubali kuhusu") | index(lower(ri90),"asipelekwe kwenye chanjo na nilijifungulia nyumbani")
replace ri8996 = 0 if index(lower(ri90),"wa kaya hakubali kuhusu") | index(lower(ri90),"asipelekwe kwenye chanjo na nilijifungulia nyumbani")
replace ri90 = "" if index(lower(ri90),"wa kaya hakubali kuhusu") | index(lower(ri90),"asipelekwe kwenye chanjo na nilijifungulia nyumbani")


*Remove from denomitor all those whose child did not receve mr 18 (RI evaluation takes into account mr 1 only) 
replace ri88 = 2 if index(lower(ri90),"18") | index(lower(ri90),"surua 2") | index(lower(ri90),"ya pili") | index(lower(ri90),"mwaka mmoja na") | index(lower(ri90),"mwaka na") | index(lower(ri90),"ya 2") | index(lower(ri90),"surua")
replace ri8996 = . if index(lower(ri90),"18") | index(lower(ri90),"surua 2") | index(lower(ri90),"ya pili") | index(lower(ri90),"mwaka mmoja na") | index(lower(ri90),"mwaka na") | index(lower(ri90),"ya 2") | index(lower(ri90),"surua")
replace ri90 = "" if index(lower(ri90),"18") | index(lower(ri90),"surua 2") | index(lower(ri90),"ya pili") | index(lower(ri90),"mwaka mmoja na") | index(lower(ri90),"mwaka na") | index(lower(ri90),"ya 2") | index(lower(ri90),"surua")

merge m:1 motherkey using "$pathproc/WHO_VACCINE_2024_eligible_mothers.dta"
rename _merge childmerge


** Recode multiple select items into missing if do not meet condition
foreach var of varlist sia182 sia183 sia184 sia185 sia186 sia187 sia188 sia189 sia1810 sia1811 sia1812 sia1896 {
	replace `var' = . if sia_check != 1
}

foreach var of varlist sia251  sia252  sia253  sia254  sia257  sia258  sia259  sia2510  sia2511  sia2512  sia2513  sia2514  sia2515  sia2516  sia2517  sia2520  sia2521  sia2522  sia2523  sia2524  sia2525  sia2527  sia2528  sia2596 {
	replace `var' = . if sia20 != 2
}

foreach var of varlist sia241 sia242 sia243 sia244 sia245 sia246 {
	replace `var' = . if sia23 != 1
}


* Routine immunization cleaning
*================= CARD ==============================
* By using card if date present/ tick mark on card will be grouped into 1
***BCG 
gen bcg_card = (ri34 == 1 | ri34b == 1 | !missing(ri33)) // Include those whom scar observed  
replace bcg_card = . if ri26 != 1  // Exclude those with no cards in the denominator
*** Polio at birth (OPV_0) _card
gen opv0_card = (ri38 == 1 | !missing(ri37)) 
replace opv0_card = . if ri26 != 1

****Polio 1 (OPV_1) _ card
gen opv1_card = (ri44 == 1 | !missing(ri43))
replace opv1_card = . if ri26 != 1 

***Polio 2 (OPV_2) _ Tick mark on card
gen opv2_card = (ri52 == 1 | !missing(ri51)) 
replace opv2_card = . if ri26 != 1

***Polio 3 (OPV3)_ card
gen opv3_card = (ri60 == 1 | !missing(ri59)) 
replace opv3_card = . if ri26 != 1

***Pneumococcal 1 (PCV_1)_ card
gen pcv1_card = (ri42 == 1 | !missing(ri41)) 
replace pcv1_card = . if ri26 != 1

***Pneumococcal 2 (PCV_2)_card
gen pcv2_card = (ri50 == 1 | !missing(ri49)) 
replace pcv2_card = . if ri26 != 1

***Pneumococcal 3 (PCV_3)_ card
gen pcv3_card = (ri58 == 1 | !missing(ri57)) 
replace pcv3_card = . if ri26 != 1

****Rotavirus 1 _ card
gen rota1_card = (ri46 == 1 | !missing(ri45)) 
replace rota1_card = . if ri26 != 1

***Rotavirus 2_card
gen rota2_card = (ri54 == 1 | !missing(ri53)) 
replace rota2_card = . if ri26 != 1

***Penta/DPT_Hib_Hep 1 _card
gen dpt1_card = (ri40 == 1 | !missing(ri39)) 
replace dpt1_card = . if ri26 != 1

***Penta/DPT_Hib_Hep 2_ card
gen dpt2_card = (ri48 == 1 | !missing(ri47))
replace dpt2_card = . if ri26 != 1 

***Penta/DPT_Hib_Hep 3 _ card
gen dpt3_card = (ri56 == 1 | !missing(ri55))
replace dpt3_card = . if ri26 != 1 

*** Measles (1st) _card
gen mr1_card = (ri66 == 1 | !missing(ri65)) 
replace mr1_card = . if ri26 != 1

// basic antigens
gen fully_vaccinated_card = (bcg_card==1 & opv0_card==1 & opv1_card==1 & opv2_card==1 & opv3_card==1 & dpt1_card==1 & dpt2_card==1 & dpt3_card==1 & mr1_card==1)
replace fully_vaccinated_card = . if ri26 != 1

//Fully vaccinated according to national schedule
gen fully_vaccinatedns_card = (bcg_card==1 & opv0_card==1 & opv1_card==1 & opv2_card==1 & opv3_card==1 & dpt1_card==1 & dpt2_card==1 & dpt3_card==1 & mr1_card==1 & pcv1_card==1 & pcv2_card==1 & pcv3_card==1 & rota1_card==1 & rota2_card==1)
replace fully_vaccinatedns_card = . if ri26 != 1


*=============== HISTORY ===================================
*Among individuals that had no cards
***BCG
gen bcg_recall = (ri71==1)
replace bcg_recall = . if ri26 != 2  // only keep those with no card

***Polio at birth (OPV_0) // How many times determines the opv number
gen opvtimes = ri74 + ri75   // facility and campaign
gen opv0_recall = (ri73==1 & opvtimes>=1)  // 1 time
replace opv0_recall = . if ri26 != 2
***Polio 1 (OPV_1)
gen opv1_recall = (ri73==1 & opvtimes>=2)  // two times
replace opv1_recall = . if ri26 != 2
***Polio 2 (OPV_2)
gen opv2_recall = (ri73==1 & opvtimes>=3)  // three times
replace opv2_recall = . if ri26 != 2
***Polio 3 (OPV3)
gen opv3_recall = (ri73==1 & opvtimes>=4)  // four times
replace opv3_recall = . if ri26 != 2

***Pneumococcal 1 (PCV_1)
gen pcv1_recall = (ri78==1 & ri79>=1)  // one times
replace pcv1_recall = . if ri26 != 2
***Pneumococcal 2 (PCV_2)
gen pcv2_recall = (ri78==1 & ri79>=2)  // two times
replace pcv2_recall = . if ri26 != 2
***Pneumococcal 3 (PCV_3)
gen pcv3_recall = (ri78==1 & ri79>=3)  // three times
replace pcv3_recall = . if ri26 != 2

***Rotavirus 1
gen rota1_recall = (ri86==1 & ri87>=1)  // one times
replace rota1_recall = . if ri26 != 2
***Rotavirus 2
gen rota2_recall = (ri86==1 & ri87>=2)  // two times
replace rota2_recall = . if ri26 != 2

***Penta/DPT_Hib_Hep 1
gen dpt1_recall = (ri76==1 & ri77>=1)  // one times
replace dpt1_recall = . if ri26 != 2
***Penta/DPT_Hib_Hep 2
gen dpt2_recall = (ri76==1 & ri77>=2)  // two times
replace dpt2_recall = . if ri26 != 2
***Penta/DPT_Hib_Hep 3 
gen dpt3_recall = (ri76==1 & ri77>=3)  // three times
replace dpt3_recall = . if ri26 != 2

*** Measles (1st)
gen mrtimes = ri84 + ri85   // facility and campaign
gen mr1_recall = (ri80==1 & mrtimes>=1)  // one times
replace mr1_recall = . if ri26 != 2


*=============== CARD + HISTORY ==========================
***BCG 
gen bcg_card_recall = (bcg_card == 1 | bcg_recall == 1) 
replace bcg_card_recall = . if age12_23 != 1    // Denominator are all child age12_23 --> changed to all those asked history + card rxcluding those who dont know
*** Polio at birth (OPV_0) _card
gen opv0_card_recall = (opv0_card == 1 | opv0_recall == 1) 
replace opv0_card_recall = . if age12_23 != 1 

****Polio 1 (OPV_1) _ card
gen opv1_card_recall = (opv1_card == 1 | opv1_recall == 1) 
replace opv1_card_recall = . if age12_23 != 1 

***Polio 2 (OPV_2) _ Tick mark on card
gen opv2_card_recall = (opv2_card == 1 | opv2_recall == 1) 
replace opv2_card_recall = . if age12_23 != 1 

***Polio 3 (OPV3)_ card
gen opv3_card_recall = (opv3_card == 1 | opv3_recall == 1) 
replace opv3_card_recall = . if age12_23 != 1 

***Pneumococcal 1 (PCV_1)_ card
gen pcv1_card_recall = (pcv1_card == 1 | pcv1_recall == 1) 
replace pcv1_card_recall = . if age12_23 != 1 

***Pneumococcal 2 (PCV_2)_card
gen pcv2_card_recall = (pcv2_card == 1 | pcv2_recall == 1) 
replace pcv2_card_recall = . if age12_23 != 1 

***Pneumococcal 3 (PCV_3)_ card
gen pcv3_card_recall = (pcv3_card == 1 | pcv3_recall == 1) 
replace pcv3_card_recall = . if age12_23 != 1

****Rotavirus 1 _ card
gen rota1_card_recall = (rota1_card == 1 | rota1_recall == 1) 
replace rota1_card_recall = . if age12_23 != 1

***Rotavirus 2_card
gen rota2_card_recall = (rota2_card == 1 | rota2_recall == 1) 
replace rota2_card_recall = . if age12_23 != 1

***Penta/DPT_Hib_Hep 1 _card
gen dpt1_card_recall = (dpt1_card == 1 | dpt1_recall == 1) 
replace dpt1_card_recall = . if age12_23 != 1

***Penta/DPT_Hib_Hep 2_ card
gen dpt2_card_recall = (dpt2_card == 1 | dpt2_recall == 1) 
replace dpt2_card_recall = . if age12_23 != 1

***Penta/DPT_Hib_Hep 3 _ card
gen dpt3_card_recall = (dpt3_card == 1 | dpt3_recall == 1) 
replace dpt3_card_recall = . if age12_23 != 1 

*** Measles (1st) _card
gen mr1_card_recall = (mr1_card == 1 | mr1_recall == 1) 
replace mr1_card_recall = . if age12_23 != 1

//===== REF TDHS 2022
/*
Fully vaccinated—basic antigens
Percentage of children who received specific vaccines at any time before the
survey (according to a vaccination card or the mother's report). To have
received all basic antigens, a child must receive at least:
▪ One dose of BCG vaccine, which protects against tuberculosis
▪ Three doses of polio vaccine given as oral polio vaccine (OPV),
inactivated polio vaccine (IPV), or a combination of OPV and IPV
▪ Three doses of DPT-containing vaccine, which protects against
diphtheria, pertussis (whooping cough), and tetanus
▪ One dose of measles-containing vaccine given as measles rubella (MR)
Sample: Children age 12–23 months

Fully vaccinated according to national schedule (age 12–23 months)
Percentage of children who received specific vaccines at any time before the
survey (according to a vaccination card or the mother's report). To be fully
vaccinated according to national schedule, a child must receive the following:
▪ One dose of BCG vaccine
▪ OPV (birth dose)
▪ Three doses of OPV and one dose of IPV
▪ Three doses of DPT-HepB-Hib
▪ Three doses of PCV
▪ Two doses of RV
▪ One dose of measles rubella (MR)
Sample: Children age 12–23 months

*/

// basic antigens
gen fully_vaccinated_card_recall = (fully_vaccinated_card==1 | ri88==1)
replace fully_vaccinated_card_recall = . if ri26 != 1 & ri26 != 2 

//Fully vaccinated according to national schedule
gen fully_vaccinatedns_card_recall = (fully_vaccinatedns_card==1 | ri88==1)
replace fully_vaccinatedns_card_recall = . if ri26 != 1 & ri26 != 2 


bysort hhkey: gen hhlevel = (_n=1)
bysort motherkey: gen caretakerlevel = (_n=1)
save "$pathproc/WHO_VACCINE_2024_vaccination.dta", replace

















