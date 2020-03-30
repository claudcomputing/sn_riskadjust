*npijoin.sas;
libname m3 "D:\ProjectData\Intermediate\smm-data";
*first try to join to the deliveries12to17 data that feeds into IDID from TM library;
*join on mbr_id to member_id and srv_dt_adj;
*if this isn't enough to get an NPI on every person - pull the bill_npi from another hosp claim;

data hosps/view=hosps;
  set y12.allhospsb_final_cleaned_110116
      y13.allhospsb_final_cleaned_110116
      y14.allhospsb_final_cleaned_110116
      y15.allhospsb_final_cleaned_110116
      y16.allhospsb_final_cleaned_110116
      y17.allhospsb_final_cleaned_110116;
run;
data mothers2.births12to17/view = mothers2.births12to17;
set 
mothers2.births12
mothers2.births13
mothers2.births14
mothers2.births15
mothers1.births16
mothers1.births17;

birth_datemo = intck('month','31dec1999'd,birth_stay_st);
run;
*join the CSR older 3m births to hosps on member_id and srv_dt_adj;
*keep all unique combinations of member_id srv_dt_adj and bill_npi;
proc sql;
create table m3.births1217_allipnpis
	as select distinct a.*, b.bill_npi
		from mothers2.births12to17 a 
			left join hosps b
	on a.member_id eq b.member_id
	and a.birth_stay_st = b.srv_dt_adj;
quit;

* 1322241 ;
	*side step - take a quick max bill_npi by member_id and srv_dt_adj - how many have missing NPI now? should be less than 1 %; 
proc sql;
create table births1217_anynpi
as select distinct
	member_id
	,birth_stay_st
	,max(bill_npi) as anynpi
	,count(distinct(bill_npi)) as howmanynpis
from m3.births1217_allipnpis
group by 
 	member_id
	,birth_stay_st;
	quit;

	proc freq data = births1217_anynpi;
	table howmanynpis;
	quit;

*join that to the AHA NPI xwalk now on Box (after keeping only the matches) to get AHA_ID and whatever else;
proc import out = work.ahaj datafile = "D:\Project Code\smm-Code\npi aha join\AHA_NPI_joined_csr7Feb2020.xlsx" 
	dbms=xlsx replace;
	sheet = "Raw";
	getnames = yes;
run;
data ahaj;
set ahaj;
format npi $10.;
npi=put(bill_npi, $10.);
run;

proc sql;
create table m3.births1217_ahaid
as select a.*, b.*
from m3.births1217_allipnpis a left join ahaj b
on a.bill_npi eq b.npi;
quit;
*eyeball that;

*keep only the max match of AHA_ID per birth - return to birth level;
proc sql;
create table m3.births1217_ahaid_unique
as select distinct
	member_id
	,birth_stay_st
	,max(aha_id) as aha_id
	,count(distinct(aha_id)) as howmanyahaids
from m3.births1217_ahaid
group by 
 	member_id
	,birth_stay_st;
	quit;


*look at frequency (number of births) by AHA_ID;
*look at frequency (number of births) for no match AHA_ID Bill_NPIs;
	proc freq data = m3.births1217_ahaid_unique;
	table howmanyahaids;
	quit;
*proceed to match by AHA_ID to rest of the AHA NPI join data to get those variables we need.;
	*get AHAID;
	proc import out = work.ahawide datafile = "D:\Project Code\smm-Code\npi aha join\SMM AHA 2013_2016_csr7Feb2020.xlsx" 
	dbms=xlsx replace;
	sheet = "AHA2013_2016";
	getnames = yes;
run;
proc print data = work.ahawide (obs=4); run;
data m3.ahawide;
set ahawide(keep = AHA_ID Perinatal_LEVEL_NYS--Neonatal_care_FTE13);
run;

proc sql;
create table m3.b1217_aha
	as select a.*, b.*
	from m3.births1217_ahaid_unique a
	left join m3.ahawide b
	on a.aha_id = b.aha_id;
quit;

*Go to end of SMM_flag program and make sure it's pulling from new 2013 and old 2014;
*Go to start of risk category creation and make sure 2013 and 2014 are pulling on the right births 
(the old smm 3m IP drgs, or check bottom of 3m Person Level program to make sure it is doing that 
when it splits things) --- basically you want the mothers2 (after x Jan21 date) births for 2013
and mothers1 for everything else.
*run basic table of deliveries by SMM flag, and SMM no vent no transfusion;
*look fine now? how weird does old 2014 look next to new 2013?;
*Pull the Dxs again. go through the risk creation;
*output the desc stats for teh risk categories again - are they showing up now?;

*shape up the CMS code and figure it out;








