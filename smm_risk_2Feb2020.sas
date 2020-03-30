*smm_risk;

libname def "D:\ProjectData\Exportable";
libname xw "D:\xw";
libname risk "D:\ProjectData\Intermediate\smm-data\risk";
libname mothers "D:\ProjectData\Intermediate\smm-data";
libname m3 "D:\ProjectData\Intermediate\smm-data";
*###########################################################################################################;
*####                             ##########################################################################;
*#### Create Risk Crosswalk 	  ##########################################################################;
*####                             ##########################################################################;
*###########################################################################################################;

************************************************************************************************************;
****************************** icd10 version ****************************************************************;
************************************************************************************************************;

%macro definecategory(sheet = , category_name =);

*note changes to excel consists of:
 - deleting the first row
 - copying column C icd codes underneath other codes
	(not deleting these in column C);

proc import datafile = "D:\Project Code\smm-Code\Comorbidity DXs v2_cleaned1" out= def.&category_name. dbms = xlsx replace; 
	getnames = yes;
	sheet  = &sheet.;
run;
data def.&category_name.;
	set def.&category_name.;
	length icd10 $10.;
	icd10 = compress(icd_code,".XXX");
	icd10 = compress(icd10,".XX");
	icd10 = compress(icd10,".X");
	icd10 = compress(icd10,".");
	&category_name.=1;
	label &category_name = &sheet.;
run;


data def.&category_name.;
set def.&category_name.(keep = icd10 &category_name.);
if icd10="" then delete;
run;
proc sort data=def.&category_name. nodupkey dupout=def.dupes&category_name.; by icd10; run;
%mend;

%definecategory(sheet = "Chronic Heart Disease", category_name =chronicheart );
%definecategory(sheet = "Congential Heart Disease", category_name =congenitalheart );
%definecategory(sheet = "Autoimmune Disorders", category_name =autoimmune );
%definecategory(sheet = "Diabetes", category_name =diabetes );

%definecategory(sheet = "Hypertension", category_name =hypertension );
%definecategory(sheet = "Hematologic Disease", category_name =hematologic );
%definecategory(sheet = "CV and Neurologic Disease", category_name =cvneurological );
%definecategory(sheet = "Kidney Disease", category_name =kidney );

%definecategory(sheet = "HIV", category_name =hiv );
%definecategory(sheet = "Sleep Apnea", category_name =apnea );
%definecategory(sheet = "Obesity", category_name =obesity );
%definecategory(sheet = "Drug Abuse", category_name =drugabuse );

%definecategory(sheet = "Previous Preg Complications", category_name =prevpregcomp);
%definecategory(sheet = "Organ Transplant", category_name =transplant );
%definecategory(sheet = "Mental or Behavioral Disorder", category_name =mentalbehavioral );
%definecategory(sheet = "Malignant Neoplasm", category_name =maligneoplasm );

/*
Exclude this category to avoid duplicate icd code issues
%definecategory(sheet = "Other Personal History Concerns", category_name =other ); 
*/

*let's do this a better way;
libname claims10 "D:\Medicaid Data\2010";
data def.icd10riskxwalk;
length icd10 $10.;
set 
def.chronicheart
def.congenitalheart
def.autoimmune
def.diabetes
def.hypertension
def.hematologic
def.cvneurological
def.kidney
def.hiv
def.apnea
def.obesity
def.drugabuse
def.prevpregcomp
def.transplant
def.mentalbehavioral
def.maligneoplasm;
run;

proc sort data=def.icd10riskxwalk; by icd10; run;

proc sort data=def.icd10riskxwalk nodupkey dupout=def.dupes_icd10; by icd10; run;

data def.icd10riskxwalk; 
	set def.icd10riskxwalk; 
	array change _numeric_;
	do over change;
		if change = . then change = 0;
	end;
run;

proc sort data=def.icd10riskxwalk; by icd10; run;



************************************************************************************************************;
****************************** icd9 version ****************************************************************;
************************************************************************************************************;

%macro definecategory2(sheet = , category_name =);

*note changes to excel consists of:
 - deleting the first row
 - extending the icd group name down to fill all lines and convert to crosswalk
 - copying column C icd codes underneath other codes
	(not deleting these in column C);

proc import datafile = "D:\Project Code\smm-Code\Comorbidity DXs v2_ICD 9 codes added_cleaned1" out= def.&category_name._icd9 dbms = xlsx replace; 
	getnames = yes;
	sheet  = &sheet.;
run;
data def.&category_name._icd9(keep = icd9 &category_name.);
	set def.&category_name._icd9;
	length icd9 $10.;
	icd9 = strip(compress(icd_code));
	&category_name.=1;
	label &category_name = &sheet.;
	if icd9="" then delete;
run;
proc sort data=def.&category_name._icd9 nodupkey dupout=def.dupes&category_name._icd9; by icd9; run;

run;
%mend;

%definecategory2(sheet = "Chronic Heart Disease", category_name =chronicheart );
%definecategory2(sheet = "Congential Heart Disease", category_name =congenitalheart );
%definecategory2(sheet = "Autoimmune Disorders", category_name =autoimmune );
%definecategory2(sheet = "Diabetes", category_name =diabetes );

%definecategory2(sheet = "Hypertension", category_name =hypertension );
%definecategory2(sheet = "Hematologic Disease", category_name =hematologic );
%definecategory2(sheet = "CV and Neurologic Disease", category_name =cvneurological );
%definecategory2(sheet = "Kidney Disease", category_name =kidney );

%definecategory2(sheet = "HIV", category_name =hiv );
%definecategory2(sheet = "Sleep Apnea", category_name =apnea );
%definecategory2(sheet = "Obesity", category_name =obesity );
%definecategory2(sheet = "Drug Abuse", category_name =drugabuse );

%definecategory2(sheet = "Previous Preg Complications", category_name =prevpregcomp);
%definecategory2(sheet = "Organ Transplant", category_name =transplant );
%definecategory2(sheet = "Mental or Behavioral Disorder", category_name =mentalbehavioral );
%definecategory2(sheet = "Malignant Neoplasm", category_name =maligneoplasm );

*%definecategory2(sheet = "Other Personal History Concerns", category_name =other );

data def.icd9riskxwalk;
length icd9 $10.;
set 
def.chronicheart_icd9
def.congenitalheart_icd9
def.autoimmune_icd9
def.diabetes_icd9
def.hypertension_icd9
def.hematologic_icd9
def.cvneurological_icd9
def.kidney_icd9
def.hiv_icd9
def.apnea_icd9
def.obesity_icd9
def.drugabuse_icd9
def.prevpregcomp_icd9
def.transplant_icd9
def.mentalbehavioral_icd9
def.maligneoplasm_icd9;
run;


proc sort data=def.icd9riskxwalk; by icd9; run;

proc sort data=def.icd9riskxwalk nodupkey dupout=def.dupes_icd9; by icd9; run;
*this removes two erroneous codes that were in immune system category (error) as well as chronic heart (correct) -
removal is correct, proceed;


data def.icd9riskxwalk; 
	set def.icd9riskxwalk; 
	array change _numeric_;
	do over change;
		if change = . then change = 0;
	end;
run;

proc sort data=def.icd9riskxwalk; by icd9; run;

/*proc export data = def.icd9riskxwalk 
	outfile= "D:\ProjectData\Exportable\smm\icd9riskxwalkqc.xlsx"
   dbms=xlsx replace;
  run;
*/
************************************************************************************************************;
****************************** merge icd9/10 ***************************************************************;
************************************************************************************************************;

  data def.icdriskxwalk;
set  def.icd9riskxwalk
		def.icd10riskxwalk;
dx_cd = icd9;
if icd9="" then dx_cd = icd10;
		run;
proc sort data=def.icdriskxwalk nodupkey dupout=def.dupes_icd; by dx_cd; run;
*check for dupes- ok none.;


*###########################################################################################################;
*####                             ##########################################################################;
*#### Label DX files with risk 	  ##########################################################################;
*####                             ##########################################################################;
*###########################################################################################################;

*note that by using an event_dt filter, this join drops all births that do not have any diagnostic histories.
*will merge whole list of births to resulting dx claims ltaer;
%macro dxrisklabel_icd10 (yr=17);

************************************************************************************************************;
****************************** icd10 version ****************************************************************;
************************************************************************************************************;

proc sql;
	create table mothers.b_3dx&yr.risk_icd10 as 
		select distinct a.*
		, b.*
		,event_dt - birth_stay_st as days_since_birth
	from mothers.b_3dx&yr. (where =(event_dt ge '01Oct2015'd or event_dt = .))  a 
		left join def.icd10riskxwalk b
			on a.dx_cd eqt strip(b.icd10);
quit;

*NOTE Eqt is used. There is a Hot Fix issue with some version of SAS that returns
a match if the dx_cd is missing. Earlier step sets pregnancy_ids where mother had no dx 
claims to "NOdxclaims";
%mend dxrisklabel_icd10;

%macro dxrisklabel_icd9(yr=17);
************************************************************************************************************;
****************************** icd9 version ****************************************************************;
************************************************************************************************************;
proc sql;

create table mothers.b_3dx&yr.risk_icd9 as 
				select distinct a.*
					, b.*
					,event_dt - birth_stay_st as days_since_birth
				from mothers.b_3dx&yr. (where =(event_dt lt '01Oct2015'd or event_dt = .))  a 
				left join def.icd9riskxwalk b
					on a.dx_cd = strip(b.icd9);
				quit;
%mend dxrisklabel_icd9;

%macro combinerisksdxs(yr=15);
************************************************************************************************************;
****************************** merge icd9/10 ***************************************************************;
************************************************************************************************************;
*the following years will have both icd9 and icd10:
2014-2018
2014 (because looks forward 1 year after birth)
2015
2016
2017
2018...if we ran it in the future (because looks back 3 years pre into pre oct 1 2015);
data mothers.b_3dx&yr.riskv/ view =mothers.b_3dx&yr.riskv;
set mothers.b_3dx&yr.risk_icd9 
mothers.b_3dx&yr.risk_icd10;
run;
%mend combinerisksdxs;

%macro riskdxsicd9(yr=06);
*the following years will have only icd9:
so make your views just the same as the dataset
2006-2013;
data mothers.b_3dx&yr.riskv/ view =mothers.b_3dx&yr.riskv ;
set mothers.b_3dx&yr.risk_icd9;
run;
%mend riskdxsicd9;



*****2014 through 2018 require restacking icd9 and icd10 labeled dx files;

%dxrisklabel_icd9(yr=14); *17602792; * 6880773;
%dxrisklabel_icd10(yr=14); *127960; * 1981;
%combinerisksdxs(yr=14);

%dxrisklabel_icd9(yr=15); *14815007;
%dxrisklabel_icd10(yr=15); *3655595;
%combinerisksdxs(yr=15);

%dxrisklabel_icd9(yr=16); * 16534792;
%dxrisklabel_icd10(yr=16); *12654214;
%combinerisksdxs(yr=16);


proc freq data = mothers.b_3dx17;
table event_dt;
format event_dt monyy.;
run;

%dxrisklabel_icd9(yr=17); * 11509494;
%dxrisklabel_icd10(yr=17); * *** FIXING IN PROGRESS *** *;
%combinerisksdxs(yr=17);



*****2006-2013 require just icd9 files so we rename for consistency in subsequent macro steps;
%dxrisklabel_icd9(yr=06); *5798776;
%riskdxsicd9(yr=06);

%dxrisklabel_icd9(yr=07); *  8383459;
%riskdxsicd9(yr=07);

%dxrisklabel_icd9(yr=08); *  10576305;
%riskdxsicd9(yr=08);

%dxrisklabel_icd9(yr=09); *  10856780;
%riskdxsicd9(yr=09);

%dxrisklabel_icd9(yr=10); * 13308760;
%riskdxsicd9(yr=10);

%dxrisklabel_icd9(yr=11); * 14383269;
%riskdxsicd9(yr=11);

%dxrisklabel_icd9(yr=12); *  15720108;
%riskdxsicd9(yr=12);

%dxrisklabel_icd9(yr=13); *  16534792; 
%riskdxsicd9(yr=13); 
*427947;

proc means data = mothers.b_3dx15riskv; run;
proc means data = mothers.b_3dx14riskv; run;
proc means data = mothers.b_3dx13riskv; run;

*###########################################################################################################;
*###########################################################################################################;

title ; 

%macro maketimepds(yr=17);
data mothers.b_3dx&yr.risk;
set mothers.b_3dx&yr.riskv;
pre_3yr=0;
if -1095 le days_since_birth lt 0 then pre_3yr= 1; 

pre_22mo= 0;
if -669 le days_since_birth lt 0 then pre_22mo= 1; 

pre_10mo= 0;
if -280 le days_since_birth lt 0 then pre_10mo= 1; 

post_42d= 0;
if 0 le days_since_birth lt 43 then post_42d= 1;

post_1yr = 0;
if 0 le days_since_birth lt 365 then post_1yr = 1;

pregnancy_id = cat(of member_Id, birth_stay_st);

*we set births that have no claims during this period
to 1 for any time period because we want them to remain 
in the denominator for future summary stats that reflect
rate of x y z thing over different time periods;

if days_since_birth = . then pre_3yr= 1;
if days_since_birth = . then pre_22mo= 1;
if days_since_birth = . then pre_10mo= 1; 
if days_since_birth = . then post_42d= 1; 
if days_since_birth = . then post_1yr = 1; 

/*array change _numeric_;
	do over change;
		if change = . then change = 0;
	end;*/

run;

%mend maketimepds;

%maketimepds(yr=17);
%maketimepds(yr=16);
%maketimepds(yr=15);

/*%maketimepds(yr=14);
%maketimepds(yr=13);
%maketimepds(yr=12);

%maketimepds(yr=11);
%maketimepds(yr=10);
%maketimepds(yr=09);

%maketimepds(yr=08);
%maketimepds(yr=07);
%maketimepds(yr=06);
*/

%macro linktosmm(yr=12);

*link to SMM indicators;
*at this stage, all births are introduced back 
into the data (including those that did not have a  
dx during the time period);

data mothers.smm&yr._plv /view = mothers.smm&yr._plv;
	set mothers.smm_pl;
pregnancy_id = cat(of member_Id, birth_stay_st);
if year(birth_stay_st) ne 20&yr. then delete;
run;

proc sql;
create table risk.b&yr._risk_smm_cl 
as select a.*, b.*
from mothers.smm&yr._plv a 
	left join mothers.b_3dx&yr.risk b
	on a.pregnancy_id = b.pregnancy_id;
quit;
data risk.b&yr._risk_smm_cl;
 set risk.b&yr._risk_smm_cl ;
if days_since_birth = . then pre_3yr= 1;
if days_since_birth = . then pre_22mo= 1;
if days_since_birth = . then pre_10mo= 1; 
if days_since_birth = . then post_42d= 1; 
if days_since_birth = . then post_1yr = 1;

	array change _numeric_;
	do over change;
		if change = . then change = 0;
	end; 
run;
%mend;

%linktosmm(yr=12);
%linktosmm(yr=13);
%linktosmm(yr=14);
%linktosmm(yr=15);
%linktosmm(yr=16);
%linktosmm(yr=17);

%linktosmm(yr=06);
%linktosmm(yr=07);
%linktosmm(yr=08);
%linktosmm(yr=09);
%linktosmm(yr=10);
%linktosmm(yr=11);

/*
proc freq data =  risk.b12_risk_smm_cl;
table pre_22mo/missing;
run;
proc freq data =  risk.b12_risk_smm_cl;
table pre_3yr/missing;
run;
proc freq data =  risk.b12_risk_smm_cl;
table pre_10mo/missing;
run;*/

%macro risktime(yr = 15, time=22mo, preorpost=pre);

proc sql;
create table risk.b&yr._risk&time._pl
	as select
		distinct
		member_id
		,birth_stay_st
		,pregnancy_id
		,max(chronicheart*(&preorpost._&time.=1)) as chronicheart_&time.
		,max(congenitalheart*(&preorpost._&time.=1)) as congenitalheart_&time.
		,max(autoimmune*(&preorpost._&time.=1)) as autoimmune_&time.
		,max(diabetes*(&preorpost._&time.=1)) as diabetes_&time.
		,max(hypertension*(&preorpost._&time.=1)) as hypertension_&time.
		,max(hematologic*(&preorpost._&time.=1)) as hematologic_&time.
		,max(cvneurological*(&preorpost._&time.=1)) as cvneurological_&time.
		,max(kidney*(&preorpost._&time.=1)) as kidney_&time.
		,max(hiv*(&preorpost._&time.=1)) as hiv_&time.
		,max(apnea*(&preorpost._&time.=1)) as apnea_&time.
		,max(obesity*(&preorpost._&time.=1)) as obesity_&time.
		,max(drugabuse*(&preorpost._&time.=1)) as drugabuse_&time.
		,max(prevpregcomp*(&preorpost._&time.=1)) as prevpregcomp_&time.
		,max(transplant*(&preorpost._&time.=1)) as transplant_&time.
		,max(mentalbehavioral*(&preorpost._&time.=1)) as mentalbehavioral_&time.
		,max(maligneoplasm*(&preorpost._&time.=1)) as maligneoplasm_&time.
		,max(any_smm) as any_smm
	from risk.b&yr._risk_smm_cl
	group by pregnancy_id;
quit;

data risk.b&yr._risk&time._pl;
	set risk.b&yr._risk&time._pl;
	array change _numeric_;
	do over change;
		if change = . then change = 0;
	end;
run;



%mend;


%risktime(yr = 17, time=22mo, preorpost=pre);
%risktime(yr = 16, time=22mo, preorpost=pre);
%risktime(yr = 15, time=22mo, preorpost=pre);

%risktime(yr = 14, time=22mo, preorpost=pre);
%risktime(yr = 13, time=22mo, preorpost=pre);
%risktime(yr = 12, time=22mo, preorpost=pre);

%risktime(yr = 11, time=22mo, preorpost=pre);
%risktime(yr = 10, time=22mo, preorpost=pre);
%risktime(yr = 09, time=22mo, preorpost=pre);

%risktime(yr = 08, time=22mo, preorpost=pre);
%risktime(yr = 07, time=22mo, preorpost=pre);
%risktime(yr = 06, time=22mo, preorpost=pre);


%macro countids(yr = 15, time=22mo, preorpost=pre);

	/*title "means 20&yr.";
proc means data = risk.b&yr._risk&time._pl;
run;

	title "count unique births 20&yr.";
proc sql;

select 
	count(*) as count_labeledclaimspid
from (select distinct pregnancy_id from mothers.b_3dx&yr.risk_icd9); 

select 
	count(*) as count_labeledclaimsmb
from (select distinct member_id, birth_stay_st from mothers.b_3dx&yr.risk_icd9); 

select 
	count(*) as count_labeledclaimspidv
from (select distinct pregnancy_id from mothers.b_3dx&yr.riskv); 

select 
	count(*) as count_labeledclaimsmbv
from (select distinct member_id, birth_stay_st from mothers.b_3dx&yr.riskv); 

select 
	count(*) as count_labeledcwTimeid
from (select distinct pregnancy_id from mothers.b_3dx&yr.risk); 
select 
	count(*) as count_labeledcwTimemb
from (select distinct member_id, birth_stay_st from mothers.b_3dx&yr.risk); 
*/

title "means 20&yr.";

proc sql;
select 
	count(*) as count_smmdata_plid
from (select distinct pregnancy_id from mothers.smm&yr._plv); 
select 
	count(*) as count_smmdata_plbv
from (select distinct member_id, birth_stay_st from mothers.smm&yr._plv); 

select
	count(*) as count_riskratesplid
from (select distinct pregnancy_id  from risk.b&yr._risk&time._pl);

select
	count(*) as count_riskratesplmb
from (select distinct  member_id, birth_stay_st from risk.b&yr._risk&time._pl);
quit;


%mend countids;


%countids(yr = 17, time=22mo, preorpost=pre);
%countids(yr = 16, time=22mo, preorpost=pre);
%countids(yr = 15, time=22mo, preorpost=pre);

%countids(yr = 14, time=22mo, preorpost=pre);
%countids(yr = 13, time=22mo, preorpost=pre);
%countids(yr = 12, time=22mo, preorpost=pre);

%countids(yr = 11, time=22mo, preorpost=pre);
%countids(yr = 10, time=22mo, preorpost=pre);
%countids(yr = 09, time=22mo, preorpost=pre);

%countids(yr = 08, time=22mo, preorpost=pre);
%countids(yr = 07, time=22mo, preorpost=pre);
%countids(yr = 06, time=22mo, preorpost=pre);

*note that we would expect discrepancies 


*****VIEW MEANS;
%viewmeans(yr=12);
title "means by SMM 20&yr.";
proc means data = risk.b&yr._risk&time._pl;
class any_smm birth_stay_st;
format birth_stay_st YEAR.;
run;
%mend viewmeans;

*NOTE smm_pl only includes up to 2012 as of 11/22/2019;

proc freq data = mothers.smm_pl;
table birth_stay_st;
format birth_stay_st YEAR.;
run;

*ccs look at;

*risk.b&yr._risk&time._pl from risk.b&yr._risk_smm_cl;
%macro maxccs(yr=16, time=22mo, preorpost=pre);

proc sql;
create view risk.ccs_&yr._&preorpost._&time._cl
as select distinct 
	ccs_cat
	,any_smm
	,&preorpost._&time.
	,count(distinct pregnancy_id) as count_births
from risk.b&yr._risk_smm_cl 
group by ccs_cat, any_smm,&preorpost._&time.
/*order by &preorpost._&time., ccs_cat, any_smm*/;
quit;

proc transpose data = risk.ccs_&yr._&preorpost._&time._cl(where=(&preorpost._&time.=1)) out = risk.ccs_&yr._&preorpost._&time._ccsl prefix= SMM;
by ccs_cat;
var count_births;
id any_smm;
run;

title "20&yr. Birth Count Macromake";
proc sql;
select 
	count(*) as count_totalb&yr. into:total_births
from (select distinct pregnancy_id from risk.b&yr._risk&time._pl); 
select 
	count(*) as count_smm_b&yr. into:smm_births
from (select distinct pregnancy_id from risk.b&yr._risk&time._pl(where=(any_smm=1)) ); 
select 
	count(*) as count_nosmm_b&yr. into:nosmm_births
from (select distinct pregnancy_id from risk.b&yr._risk&time._pl(where=(any_smm=0)));
quit;

data risk.ccs_&yr._&preorpost._&time._ccsl(drop = _NAME_ /*total_births smm_births nosmm_births*/); 
	set risk.ccs_&yr._&preorpost._&time._ccsl; 
	array change _numeric_;
	do over change;
		if change = . then change = 0;
	end;
format SMM0_pct SMM1_pct pct_births percent8.2;
format SMM0 SMM1 total_births smm_births nosmm_births births_w_ccscat comma10.0;
total_births = &total_births.;
smm_births=&smm_births.;
nosmm_births=&nosmm_births.;
births_w_ccscat=SMM0+SMM1;
SMM0_pct = SMM0/&nosmm_births.;
SMM1_pct = SMM1/&smm_births.;
pct_births=births_w_ccscat/&total_births.;
run;


proc sql;
create table risk.ccs_&yr._&preorpost._&time._ccsl
as select distinct 
	a.ccs_cat
	,a.ccs_desc
	,b.*
from xw.ccs_cw a
	left join risk.ccs_&yr._&preorpost._&time._ccsl b
on a.ccs_cat = b.ccs_cat;
quit;

%mend;


%maxccs(yr=16, time=22mo, preorpost=pre);
%maxccs(yr=15, time=22mo, preorpost=pre);
%maxccs(yr=14, time=22mo, preorpost=pre);
%maxccs(yr=13, time=22mo, preorpost=pre);
%maxccs(yr=12, time=22mo, preorpost=pre);


%maxccs(yr=11, time=22mo, preorpost=pre);
%maxccs(yr=10, time=22mo, preorpost=pre);
%maxccs(yr=09, time=22mo, preorpost=pre);
%maxccs(yr=08, time=22mo, preorpost=pre);
%maxccs(yr=07, time=22mo, preorpost=pre);
%maxccs(yr=06, time=22mo, preorpost=pre);


