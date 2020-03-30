
/*****************************************************************************************************************
Demographics SMM
*****************************************************************************************************************/

libname xw "D:\xw";
libname e "D:\Medicaid Data\Eligibility";
*eligibility;
proc sql;
create table mothers.eligibility
	as select 
	a.*, b.*
	from
	mothers.births06to17 as a
	left join e.Together_all_ev_18_final b
	on a.member_id = b.member_id;
 quit;
 * 716342 2012-2016 + 726092 2006-2011 in previous run;
 
 proc sql;
create table mothers.eligibility_count as
select distinct member_id,birth_stay_st
from  mothers.eligibility ;
quit;
* 716342;
data mothers.mcaid_pl2;
set mothers.eligibility;
array onmcaid(*) mcaid_cd73-mcaid_cd228; * jan 2006 - dec 2018;
array_start_date = birth_datemo -72;
 	mcaid_month_0 = onmcaid(array_start_date);
array zip(*) zip73-zip228; * jan 2005 - dec 2018;
	array_start_date = birth_datemo -72;
	zip_month_0 = zip(array_start_date);
* 716,342;
run;

proc sql;
create table mothers.city
	as select distinct
	a.*, b.*, c.*, d.*
	from
	mothers.mcaid_pl2 (keep = member_id birth_stay_st birth_datemo zip_month_0 mcaid_month_0) as a
	left join xw.zipcw b
	on a.zip_month_0 eq b.zip
left join xw.regions c
on b.county = c.FIPS_county_code
left join xw.popdensity d
on c.County_name = d.County;
quit; 
* 716342;
proc sql;
create table mothers.city_count as
select distinct member_id,birth_stay_st
from  mothers.city ;
quit;
* 716342;

 proc format;
value $race
"native american" = "other"
"other" = "other"
"unknown" = "unknown"
"white" = "White, non-Hispanic"
"black" = "Black, non-Hispanic"
"asian" = "Asian / Pacific Islander"
"hispanic" = "Hispanic / Latino"
;
run;

 proc format;
value $smmage
0-19 = "<20"
20-34 = "20-34"
34-39 = "34-39"
40-44 = "40-44"
>=45 = "45+"
;
run;
data mothers.elig ;
set mothers.eligibility;
if mbr_birth_dt>&date. or mbr_birth_dt=. then delete;
run;
*716342 -->  713931 due to missing age data;

 %let date = birth_stay_st;
data mothers.elig(drop=mbr_id--mcaid_cd228);
set mothers.elig;
birth_year=year(birth_stay_st);
birth_datemo = intck('month','31dec1999'd,birth_stay_st);
birthcaldate = birth_stay_st ;
format birthcaldate birth_stay_st date9.;

format age 8.1;
format race $race.;
format race2 $8.;
format male 8.0;
format agecat4 $16.;
format agecat7 $16.;

***age***;

age= floor(yrdif(mbr_birth_dt, &date.));
***death***;
label died_when = "If died - how many months after birth"
died_when= 0;
if (mbr_death_dt = .) or (mbr_death_dt<&date. and mbr_death_dt ne .) then died_when = .;
died_when= yrdif(mbr_death_dt, &date.);
death42=0;
if died_when le 42 ge &date. then death42 = 1;

***race***;
if substr(mbr_ethnic_cd,6,1) eq 'Y' then mbr_race_cd = '5'; * hispanic;
 White = (mbr_race_cd eq '1');
 Hispanic = (mbr_race_cd eq '5');
 Black = (mbr_race_cd eq '2');
 Asian = (mbr_race_cd eq '3');
 Other_race = (mbr_race_cd in('4','9'));
 Unknown_race = (mbr_race_cd eq '0');
 Female = (mbr_sex_cd eq 'F');
if hispanic_or_latino_ethnic_cd = "Y" then race = "hispanic";
else if mbr_race_cd = "1" then race = "white";
else if mbr_race_cd = "2" then race = "black";
else if mbr_race_cd = "3" then race = "asian";
else if mbr_race_cd = "4" or mbr_race_cd = "9" then race = "other";
else if mbr_race_cd = "0" then race = "unknown";
else if mbr_race_cd = "5" then race = "hispanic";
if hispanic_or_latino_ethnic_cd = "Y" then race2 = "hispanic";
else if mbr_race_cd = "1" then race2 = "white";
else if mbr_race_cd = "2" then race2 = "black";
else race2 = "other/unknown";

***sex***;
Female = (mbr_sex_cd eq 'F');

**agecat1**;
if 0<=age<15 then agecat4= "01 Age 0-14";
else if 15<=age<20 then agecat4 ="02 Age 15-19";
else if 20<=age<24 then agecat4= "03 Age 20-24";
else if 24<=age<35 then agecat4= "04 Age 25-34";
else if 35<=age<40 then agecat4= "05 Age 35-39";
else if 40<=age   then agecat4= "06 Age 40 and above";
else if age=. then agecat4 ="07 Age missing";
***agecat7 code**;
if 0<=age<1 then agecat7= "01 Age 0";
else if 1<=age<6 then agecat7 = "02 Age 1-5";
else if 6<=age<18 then agecat7= "03 Age 6-17";
else if 18<=age<40 then agecat7= "04 Age 18-39";
else if 40<=age <65 then agecat7= "05 Age 40-64";
else if 65<=age <75 then agecat7="06 Age 65-74";
else if 75<=age then agecat7 ="07 Age 75 +";
**agecat4**;
if 0<=age<18 then agecat4= "01 Age 0-17";
else if 18<=age<40 then agecat4 = "02 Age 18-39";
else if 40<=age<50 then agecat4= "03 Age 40-50";
else if 50<=age<65 then agecat4= "03 Age 51-64";
else if 65<=age   then agecat4= "04 Age 65 and above";
else if age=. then agecat4 ="05 Age missing";
**agegrp**;
agegrp = "Age Group NA";
if 18 gt age then agegrp = " <18";
if 18 le age le 29 then agegrp = "18-29";
if 30 le age le 39 then agegrp = "30-39";
if 40 le age le 49 then agegrp = "40-49";
if 50 le age le 59 then agegrp = "50-59";
if 60 le age then agegrp = "60+";
if age = . then agegrp = .;
dual = 0;
***dual flag**;
 if mcare_start_mo ^=. and mcare_start_mo < birth_datemo then dual=1;
else dual=0;
if mcare_start_dt le &date. then dual = 1;
run;
* 713931;

proc sql;
create table mothers.awho1 
as select distinct member_id, birth_stay_st from mothers.elig;
quit;
* 713931;
proc sql;
create table mothers.awho2 
as select distinct member_id, birth_stay_st from mothers.smm_pl;
quit;
* 716342;
*difference due to due to missing age data or
birth dates of mothers that are clearly errors (are after or
equal to birth of child) - these are dropped;

proc sql;
create table mothers.tables
	as select distinct
	a.*, b.*,c.*
	from
	mothers.elig as a
	left join mothers.smm_pl b
	on a.member_id eq b.member_id
	and a.birth_stay_st = b.birth_stay_st
left join mothers.city c
on a.member_id eq c.member_id
and a.birth_stay_st = c.birth_stay_st;
	quit;
* 713931;

data mothers.smm_demographics;
set mothers.tables;
pregnancy_id = cat(of member_Id, birth_stay_st);
run;
