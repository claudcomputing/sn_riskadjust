*smm_output;

*smm Risk adjust mean;
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
proc genmod data =  mothers.smm_demographics;
class race   birth_year (ref='2006') /param=glm;
model any_smm = race   age  birth_year   /dist=bin;
lsmeans race /om cl exp;

run;

libname yr06 "D:\ProjectData\Intermediate\smm-data\3m-smm-data\06";
libname yr07 "D:\ProjectData\Intermediate\smm-data\3m-smm-data\07";
libname yr08 "D:\ProjectData\Intermediate\smm-data\3m-smm-data\08";
libname yr09 "D:\ProjectData\Intermediate\smm-data\3m-smm-data\09";
libname yr10 "D:\ProjectData\Intermediate\smm-data\3m-smm-data\10";
libname yr11 "D:\ProjectData\Intermediate\smm-data\3m-smm-data\11";
libname yr12 "D:\ProjectData\Intermediate\smm-data\3m-smm-data\12";
libname yr13 "D:\ProjectData\Intermediate\smm-data\3m-smm-data\13";
libname yr14 "D:\ProjectData\Intermediate\smm-data\3m-smm-data\14";
libname yr15 "D:\ProjectData\Intermediate\smm-data\3m-smm-data\15";
libname yr16 "D:\ProjectData\Intermediate\smm-data\3m-smm-data\16";
libname yr17 "D:\ProjectData\Intermediate\smm-data\3m-smm-data\17";
libname yr18 "D:\ProjectData\Intermediate\smm-data\3m-smm-data\18";

data mothers.ip_drg06to17v / view = mothers.ip_drg06to17v;
set yr06.ip_drg
yr07.ip_drg
yr08.ip_drg
yr09.ip_drg
yr10.ip_drg
yr11.ip_drg
yr12.ip_drg
yr13.ip_drg
yr14.ip_drg
yr15.ip_drg
yr16.ip_drg
yr17.ip_drg;
run;	
proc sql;
create table mothers.ip_drg_prov_npis_pb
as select distinct
bill_prov_id
,bill_npi
,srv_dt_adj
,member_id
from mothers.ip_drg06to17v (where =('01jan2006'd le srv_end_dt_adj le '31dec2017'd and 
  aprdrg in ('540','541','542','560')));
quit;
proc sort data = mothers.ip_drg_prov_npis_pb nodupkey; by member_id srv_dt_adj; run;

proc contents data = mothers.ip_drg06to17v ; run;

proc contents data = mothers.ip_drg_prov_npis;
run;
proc sql;
create table mothers.testsd
as select a.*, b.* from mothers.smm_demographics a, mothers.ip_drg_prov_npis_pb b
where a.member_id = b.member_id
and a.birth_stay_st = b.srv_dt_adj;
quit;
data risk.risk06to17_22mo;
set risk.b06_risk22mo_pl
risk.b07_risk22mo_pl
risk.b08_risk22mo_pl
risk.b09_risk22mo_pl
risk.b10_risk22mo_pl
risk.b11_risk22mo_pl
risk.b12_risk22mo_pl
risk.b13_risk22mo_pl
risk.b14_risk22mo_pl
risk.b15_risk22mo_pl
risk.b16_risk22mo_pl
risk.b17_risk22mo_pl;
run;
proc sort data =mothers.testsd nodupkey; by member_id birth_stay_st; run;

proc sql;
create table mothers.testsd
as select a.*, b.* from 
mothers.testsd a
left join risk.risk06to17_22mo b
on a.member_id eq b.member_id
and a.birth_stay_st eq b.birth_stay_st;
quit;
  


 
%let MODEL_VAR = race birth_year age;
%let EST = estmacro;
%let CONDITION= conditionmacro;
proc format;
value $smmage
0-19 = "<20"
20-34 = "20-34"
34-39 = "34-39"
40-44 = "40-44"
>=45 = "45+"
;
run;
data mothers.testsd;
set mothers.testsd;
agesmm = "MISSING";
if age<20 then agesmm = "<20";
if 35>age>=20 then agesmm = "20-34";
if 40>age>=35 then agesmm = "34-39";
if 45>age>=40 then agesmm = "40-44";
if age>=45 then agesmm = "45+";
racenum=5;
if race = "white" then racenum=1 ;
if race = "black" then racenum=2 ;
if race = "hispanic" then racenum=3;
if race = "asian" then racenum=4 ;
if race = "other" then racenum=5 ;
if race = "unknown" then racenum=6 ;
pregnancy_id = cat(of member_Id, birth_stay_st);
run;

proc freq data = mothers.testsd;
table race;
run;
*binaryvar.;
proc format;
value $binaryvar
0="No"
1="Yes";
run;

proc sql;
select count(*) into :numwithsmm
from mothers.testsd(where = (any_smm =1));
quit;
 proc print data = &numwithsmm;
 run;
proc surveyselect data = mothers.testsd(where = (any_smm =0)) out = mothers.testsd_short_0 method = SRS
sampsize= 26321 seed = 12345;
run;

data mothers.testsd2;
set mothers.testsd_short_0
mothers.testsd(where = (any_smm =1));
run;

libname new13 "D:\Medicaid Data\2013 new";
libname old13 "D:\Medicaid Data\2013";


libname mothers1 "D:\ProjectData\Intermediate\smm-data\before 21Jan2019";
libname mothers2 "D:\ProjectData\Intermediate\smm-data\after21Jan2019";

*regular OLS; *did not run on all data;
 *LEAVE OUT bill prov id & leave out ls means ;
proc genmod data =  mothers.testsd
		(keep=any_smm birth_year racenum agesmm chronicheart_22mo congenitalheart_22mo hypertension_22mo hematologic_22mo hiv_22mo obesity_22mo) 
		descending;
		*pregnancy_id bill_prov_id  ;
class 	any_smm   birth_year 
		racenum(ref='1') agesmm chronicheart_22mo 
		congenitalheart_22mo hypertension_22mo 
		hematologic_22mo hiv_22mo obesity_22mo/param=glm;
		*bill_prov_id pregnancy_id;
model 	any_smm =  racenum birth_year 
		racenum agesmm chronicheart_22mo 
		congenitalheart_22mo hypertension_22mo 
		hematologic_22mo hiv_22mo obesity_22mo; */dist=bin;
		*bill_prov_id pregnancy_id;
*lsmeans bill_prov_id ; */om cl exp;

*ods output  ParameterEstimates=mothers.ols1; *observed values; 

run;

*trying proc reg;
ods listing; run;
ods trace on;
ods show;

*OLS w/o shrinkage; 
proc genmod data =  mothers.testsd(keep=any_smm pregnancy_id bill_prov_id  birth_year racenum agesmm chronicheart_22mo congenitalheart_22mo hypertension_22mo hematologic_22mo hiv_22mo obesity_22mo) descending;
class any_smm bill_prov_id pregnancy_id birth_year racenum(ref='1') agesmm chronicheart_22mo congenitalheart_22mo hypertension_22mo hematologic_22mo hiv_22mo obesity_22mo/param=glm;
model any_smm = bill_prov_id pregnancy_id racenum birth_year agesmm chronicheart_22mo congenitalheart_22mo hypertension_22mo hematologic_22mo hiv_22mo obesity_22mo/dist=bin;
lsmeans bill_prov_id /om cl exp;
ods output  ParameterEstimates=mothers.ols1; *observed values; 
run;


ods _all_ close;
*remove lsmeans and eliminate bill_prov_id from model and class statement; 
proc genmod data =  mothers.testsd(keep=any_smm pregnancy_id  birth_year racenum agesmm chronicheart_22mo congenitalheart_22mo hypertension_22mo hematologic_22mo hiv_22mo obesity_22mo) descending;
class any_smm pregnancy_id birth_year racenum(ref='1') agesmm chronicheart_22mo congenitalheart_22mo hypertension_22mo hematologic_22mo hiv_22mo obesity_22mo/param=glm;
model any_smm =  pregnancy_id racenum birth_year agesmm chronicheart_22mo congenitalheart_22mo hypertension_22mo hematologic_22mo hiv_22mo obesity_22mo/dist=bin;
ods output  ParameterEstimates=mothers.ols2; *predicted values;
run;
ods _all_ close;

proc genmod data =  mothers.testsd(keep=any_smm bill_prov_id  birth_year racenum agesmm chronicheart_22mo congenitalheart_22mo hypertension_22mo hematologic_22mo hiv_22mo obesity_22mo) descending;
class any_smm bill_prov_id  birth_year racenum(ref='1') agesmm chronicheart_22mo congenitalheart_22mo hypertension_22mo hematologic_22mo hiv_22mo obesity_22mo/param=glm;
model any_smm = bill_prov_id racenum birth_year agesmm chronicheart_22mo congenitalheart_22mo hypertension_22mo hematologic_22mo hiv_22mo obesity_22mo/dist=bin;
lsmeans bill_prov_id /om cl exp;
run;
PROC GLIMMIX DATA=mothers.testsd(keep=any_smm bill_prov_id  birth_year racenum agesmm chronicheart_22mo congenitalheart_22mo hypertension_22mo hematologic_22mo hiv_22mo obesity_22mo) MAXLMMUPDATE=100;
CLASS bill_prov_id  birth_year racenum(ref='1') agesmm chronicheart_22mo congenitalheart_22mo hypertension_22mo hematologic_22mo hiv_22mo obesity_22mo;

MODEL any_smm = bill_prov_id racenum birth_year  agesmm chronicheart_22mo congenitalheart_22mo hypertension_22mo hematologic_22mo hiv_22mo obesity_22mo
        /D=Binary LINK=LOGIT SOLUTION; *Distribution = Binary, Link = Logit;
RANDOM INTERCEPT/SUBJECT=bill_prov_id SOLUTION;
run;


proc genmod data =  mothers.testsd(keep=any_smm bill_prov_id  birth_year racenum agesmm chronicheart_22mo congenitalheart_22mo hypertension_22mo hematologic_22mo hiv_22mo obesity_22mo)  descending;
class bill_prov_id  birth_year race(ref='White, non-Hispanic') agesmm chronicheart_22mo congenitalheart_22mo hypertension_22mo hematologic_22mo hiv_22mo obesity_22mo/param=glm;
model any_smm = bill_prov_id race birth_year race agesmm chronicheart_22mo congenitalheart_22mo hypertension_22mo hematologic_22mo hiv_22mo obesity_22mo;
lsmeans bill_prov_id;
run;

proc genmod data =  mothers.testsd(keep=any_smm bill_prov_id  birth_year racenum agesmm chronicheart_22mo congenitalheart_22mo hypertension_22mo hematologic_22mo hiv_22mo obesity_22mo) descending;
class any_smm bill_prov_id  birth_year racenum(ref='1') agesmm chronicheart_22mo congenitalheart_22mo hypertension_22mo hematologic_22mo hiv_22mo obesity_22mo/param=glm;
model any_smm = bill_prov_id racenum birth_year agesmm chronicheart_22mo congenitalheart_22mo hypertension_22mo hematologic_22mo hiv_22mo obesity_22mo/dist=bin;
lsmeans bill_prov_id /om cl exp;
run;

ODS OUTPUT PARAMETERESTIMATES=&EST (KEEP=EFFECT ESTIMATE STDERR);

PROC GLIMMIX DATA=mothers.testsd NOCLPRINT MAXLMMUPDATE=100;
CLASS bill_prov_id race age;
ODS OUTPUT PARAMETERESTIMATES=&EST (KEEP=EFFECT ESTIMATE STDERR);
MODEL any_smm=bill_prov_id race birth_year age
        /D=Binomial LINK=LOGIT SOLUTION; *Distribution = Binary, Link = Logit;
XBETA=_XBETA_;
LINP=_LINP_;
RANDOM INTERCEPT/SUBJECT=bill_prov_id SOLUTION;
format age $smmage.;
run;



PROC GLIMMIX DATA=mothers.smm_demographics NOCLPRINT MAXLMMUPDATE=100;
CLASS race;
ODS OUTPUT PARAMETERESTIMATES=&EST (KEEP=EFFECT ESTIMATE STDERR);
MODEL any_smm=race &MODEL_VAR
        /D=Binomial LINK=LOGIT SOLUTION; *Distribution = Binary, Link = Logit;
XBETA=_XBETA_;
LINP=_LINP_;
RANDOM INTERCEPT/SUBJECT=race SOLUTION;

run;


PROC GLIMMIX DATA=mothers.smm_demographics NOCLPRINT MAXLMMUPDATE=100;
CLASS race;
ODS OUTPUT PARAMETERESTIMATES=&EST (KEEP=EFFECT ESTIMATE STDERR);
MODEL any_smm=race &MODEL_VAR
        /D=Binomial LINK=LOGIT SOLUTION; *Distribution = Binary, Link = Logit;
XBETA=_XBETA_;
LINP=_LINP_;
RANDOM INTERCEPT/SUBJECT=race SOLUTION;
OUTPUT OUT=any_smm
        PRED(BLUP ILINK)=PREDPROB
PRED(NOBLUP ILINK)=EXPPROB
        PRED(BLUP)=PREDLP  
PRED(NOBLUP)=PREDMLP;
ID any_smm;
NLOPTIONS TECH=NMSIMP;
ods  output ParameterEstimates=outRandomfile;
ods  output SolutionR=R.&CONDITION._solnr;
ods  output CovParms=R.&CONDITION._cov;  
covtest/wald cl;
run;
format race ;
*should this be a logistic regression?^;

proc contents data = mothers.smm_demographics;
run;

*smm desc tables;
Title "A. Select top SMM Indicators";
proc means data = mothers.tables(where = (2012 le birth_year le 2017)); 
var Total_SMM
Any_SMM
Nonvent_SMM
Transfusion_flag
Nontransfusion_SMM
Nontransvent_SMM
Coagulation_flag
Tracheo_Vent_flag
Ventilation_flag
Sepsis_flag
Eclampsia_flag
Resp_flag
Hysterectomy_flag
Renal_flag
Pulmonary_flag
Shock_flag
Cerebro_flag
Throm_flag
Cardiac_Conv_flag
Sicklecell_flag
Conversion_flag
Anesthesia_flag
Heart_flag
MI_Aneurysm_flag
Cardiac_flag
MI_flag
Aneurysm_flag
Embolism_flag
Tracheo_flag;
run;
Title "A. Select top SMM Indicators -dx";
proc means data = mothers.tables(where = (2012 le birth_year le 2017)); 
var 
MI_flag
Aneurysm_flag
Renal_flag
Resp_flag
Embolism_flag
Cardiac_flag
Coagulation_flag
Eclampsia_flag
Heart_flag
Cerebro_flag
Pulmonary_flag
Anesthesia_flag
Sepsis_flag
Shock_flag
Sicklecell_flag
Throm_flag;
run;
Title "A. Select top SMM Indicators -px";
proc means data = mothers.tables(where = (2012 le birth_year le 2017)); 
var 
Conversion_flag
Transfusion_flag
Hysterectomy_flag
Tracheo_flag
Ventilation_flag
;
run;

Title "A. Select top SMM Indicators -summary";
proc means data = mothers.tables(where = (2012 le birth_year le 2017)); 
var 
Nontransfusion_SMM
Nonvent_SMM
Nontransvent_SMM
MI_Aneurysm_flag
Cardiac_Conv_flag
Tracheo_Vent_flag
;
run;


Title "1. Yearly Hospital Births";
proc freq data = mothers.tables(where = (2012 le birth_year le 2017)); 
table birth_year/nocol norow nopct;
run;
Title "2. Yearly SMM Rates";
proc freq data = mothers.tables(where = (2012 le birth_year le 2017)); 
tables
birth_year*any_smm
birth_year*nontransfusion_SMM
birth_year*nontransvent_SMM/nocol norow nopct;
run;
Title "3. Yearly Transfusions and Ventilations and top 5";
proc freq data = mothers.tables(where = (2012 le birth_year le 2017)); 
tables
birth_year*transfusion_flag
birth_year*Coagulation_flag
birth_year*Ventilation_flag
birth_year*Sepsis_flag
birth_year*Eclampsia_flag
/*Resp_flag
Hysterectomy_flag*/
/nocol norow nopct;
run;

Title "1a. Year by SMM by Region";
proc freq data = mothers.tables(where = (2012 le birth_year le 2017)); 
table 
birth_year*Region_Name*any_smm
/nocol norow nopct;
run;

Title "1b. Year by SMM by Race";
proc freq data = mothers.tables(where = (2012 le birth_year le 2017)); 
table 
birth_year*race2*any_smm/nocol norow nopct;
run;
Title "1c. Year by SMM by Age";
proc freq data = mothers.tables(where = (2012 le birth_year le 2017)); 
table 
birth_year*agegrp*any_smm/nocol norow nopct;;
run;
Title "1d. Year by SMM by SMM Type (Top 5)";
proc freq data = mothers.tables(where = (2012 le birth_year le 2017)); 
table 
birth_year*transfusion_flag
birth_year*Coagulation_flag
birth_year*Ventilation_flag
birth_year*Sepsis_flag
birth_year*Eclampsia_flag/nocol norow nopct;
run;

Title "2a.1 Year by SMM by Race by Region";

*see which are the smallest regions;
proc freq data = mothers.tables(where = (2012 le birth_year le 2017));
table Region_Name*birth_year/nocol norow nopct;
run;
/*
Title "2a. Year by SMM by Race by Region, selection";
 format aprdrg $delivery.
        srv_end_dt_adj year.;
run;
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
run;*/
proc freq data = mothers.tables(where = (2012 le birth_year le 2017)); 
table 
birth_year*white*Region_Name*any_smm/nocol norow nopct; 
run;
Title "2a.2 Year by SMM by Race by Region Type";

proc freq data = mothers.tables(where = (2012 le birth_year le 2017)); 
table 
birth_year*race2*urban*any_smm/nocol norow nopct; 
run;
Title "2c. Year by SMM by Race by SMM Type (top 5 overall) (selection)";
proc freq data = mothers.tables(where = (2012 le birth_year le 2017)); 
table 
birth_year*white*transfusion_flag
birth_year*white*Coagulation_flag
birth_year*white*Ventilation_flag
birth_year*white*Sepsis_flag
birth_year*white*Eclampsia_flag/nocol norow nopct;
run;
proc freq data = mothers.tables(where = (2012 le birth_year le 2017)); 
table 
birth_year*race2*transfusion_flag
birth_year*race2*Coagulation_flag
birth_year*race2*Ventilation_flag
birth_year*race2*Sepsis_flag
birth_year*race2*Eclampsia_flag/nocol norow nopct;
run;
title;

proc contents data = mothers.tables;run;
proc freq data = mothers.tables(where = (2012 le birth_year le 2017)); 
title "Monthly estimates - Main";
table 
birth_stay_st
birth_stay_st*any_smm
birth_stay_st*Nontransfusion_SMM
birth_stay_st*Nontransvent_SMM

birth_stay_st*Total_SMM/nocol norow nopct;
format birth_stay_st monyy7.
;
run;

proc freq data = mothers.tables(where = (2012 le birth_year le 2017)); 
title "Monthly estimates - top SMM";
table 
birth_stay_st*transfusion_flag
birth_stay_st*Coagulation_flag
birth_stay_st*Ventilation_flag
birth_stay_st*Sepsis_flag
birth_stay_st*Eclampsia_flag/nocol norow nopct;
format birth_stay_st monyy7.
;
run;
proc freq data = mothers.tables(where = (2012 le birth_year le 2017)); 
title "Monthly estimates - top SMM";
table 
birth_stay_st*Ventilation_flag/nocol norow nopct;
format birth_stay_st monyy7.
;
run;
proc freq data = mothers.tables(where = (2012 le birth_year le 2017)); 
title "Monthly estimates - All";
table 
birth_stay_st*MI_flag
birth_stay_st*Aneurysm_flag
birth_stay_st*Renal_flag
birth_stay_st*Resp_flag
birth_stay_st*Embolism_flag
birth_stay_st*Cardiac_flag
birth_stay_st*Coagulation_flag
birth_stay_st*Eclampsia_flag
birth_stay_st*Heart_flag
birth_stay_st*Cerebro_flag
birth_stay_st*Pulmonary_flag
birth_stay_st*Anesthesia_flag
birth_stay_st*Sepsis_flag
birth_stay_st*Shock_flag
birth_stay_st*Sicklecell_flag
birth_stay_st*Throm_flag
birth_stay_st*Conversion_flag
birth_stay_st*Transfusion_flag
birth_stay_st*Hysterectomy_flag
birth_stay_st*Tracheo_flag
birth_stay_st*Ventilation_flag/nocol norow nopct
format birth_stay_st monyy7.
;
run;
