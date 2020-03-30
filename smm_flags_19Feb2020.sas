*csr315@nyu.edu;
       
options mprint 
		mlogic 
		symbolgen
		compress=yes
		fullstimer 
        msglevel=i
        bufno=500
        bufsize=4096 
		cpucount=4
        SORTSIZE=34359738368
        SPDEINDEXSORTSIZE=2147483648
        SPDESORTSIZE=2147483648
        SUMSIZE=34359738368
        threads;

%put &sysdate &systime;

libname claims06 "D:\Medicaid Data\2006";
libname claims07 "D:\Medicaid Data\2007";
libname claims08 "D:\Medicaid Data\2008";
libname claims09 "D:\Medicaid Data\2009";
libname claims10 "D:\Medicaid Data\2010";
libname claims11 "D:\Medicaid Data\2011";
libname claims12 "D:\Medicaid Data\2012";
libname claims13 "D:\Medicaid Data\2013 new";
libname claims14 "D:\Medicaid Data\2014 new";
libname claims15 "D:\Medicaid Data\2015";
libname claims16 "D:\Medicaid Data\2016";
libname claims17 "D:\Medicaid Data\2017";
libname claims18 "D:\Medicaid Data\2018";

/*******
* running px dx with newest dx px files (in case didn't before) on deliveries with older 13 14.
*******/

*note: mothers 1 had the 2013 and 2014 pre rolled data and we noticed some weird things.
mothers 2 is the directory where we are saving variables we recreate for 2013 and 2014.;

libname mothers1 "D:\ProjectData\Intermediate\smm-data\before 21Jan2019";
libname mothers2 "D:\ProjectData\Intermediate\smm-data\after21Jan2019";


libname yr06 "D:\ProjectData\Intermediate\smm-data\3m-smm-data\before 21Jan2019\06";
libname yr07 "D:\ProjectData\Intermediate\smm-data\3m-smm-data\before 21Jan2019\07";
libname yr08 "D:\ProjectData\Intermediate\smm-data\3m-smm-data\before 21Jan2019\08";
libname yr09 "D:\ProjectData\Intermediate\smm-data\3m-smm-data\before 21Jan2019\09";
libname yr10 "D:\ProjectData\Intermediate\smm-data\3m-smm-data\before 21Jan2019\10";
libname yr11 "D:\ProjectData\Intermediate\smm-data\3m-smm-data\before 21Jan2019\11";
libname yr12 "D:\ProjectData\Intermediate\smm-data\3m-smm-data\before 21Jan2019\12";
libname yr13 "D:\ProjectData\Intermediate\smm-data\3m-smm-data\before 21Jan2019\13 old"; *note the "new" 2013 did not run properly at the time of this note 1/23/2020;
libname yr14 "D:\ProjectData\Intermediate\smm-data\3m-smm-data\before 21Jan2019\14 old"; *note the "new" 2013 did not run properly at the time of this note 1/23/2020;
libname yr15 "D:\ProjectData\Intermediate\smm-data\3m-smm-data\before 21Jan2019\15";
libname yr16 "D:\ProjectData\Intermediate\smm-data\3m-smm-data\before 21Jan2019\16";
libname yr17 "D:\ProjectData\Intermediate\smm-data\3m-smm-data\before 21Jan2019\17";
libname yr18 "D:\ProjectData\Intermediate\smm-data\3m-smm-data\before 21Jan2019\18";


	data mothers2.ip_drg06to17v / view = mothers2.ip_drg06to17v;
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
create view mothers2.births as
select distinct member_id, max(srv_end_dt_adj) as birth_stay_end format = mmddyy., srv_dt_adj as birth_stay_st format = mmddyy. from 
mothers2.ip_drg06to17v(where=( '01jan2006'd le srv_dt_adj le '31dec2017'd and 
  aprdrg in ('540','541','542','560')))
group by member_id, birth_stay_st;
quit;
proc sort nodupkey data = mothers2.births out = births dupout=dupes; by member_id birth_stay_st; run;
* 1442434 - no duplicates & same as before. Using older 13 14 roll up data, looks like tried 13 14 and didn't run bc dataset generated had almost no drgs;

proc freq data = mothers2.births;
table birth_stay_st / nocol norow nopct missing; 
format birth_stay_st year.;
run;


%macro split(yr=06);
data mothers2.births&yr.;
set mothers2.births(where=( "01jan20&yr."d le birth_stay_st le "31dec20&yr."d));
run;
%mend;
/*%split(yr=06);*/
/*%split(yr=07);*/
/*%split(yr=08);*/
/*%split(yr=09);*/
/*%split(yr=10);*/
/*%split(yr=11);*/
%split(yr=12);
%split(yr=13);
%split(yr=14);
%split(yr=15);
/*%split(yr=16);*/
/*%split(yr=17);*/
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


/***************************
*Get px dx ****************
****************************/
*pick up dx and pxs of member_id within birth hospital stay;
*pick up dx and pxs of member_id within the same year as the birth;

%macro pxyear(yr=06); 
	proc sql;
			create table mothers2.b_px&yr. as 
				select distinct a.*
					, a.birth_stay_st
					, a.birth_stay_end
					, c.srv_dt_adj as event_dt
					, c.proc_cd
					, c.cos_final
				from mothers2.births&yr.  a 
				left join claims&yr..Px_final_cleaned_020617dd
	(keep = member_id proc_cd srv_dt_adj srv_end_dt_adj cos_final) c
					on a.member_id= c.member_id
					and a.birth_stay_st le c.srv_dt_adj le a.birth_stay_end;
				quit;
	%mend pxyear;
%macro dxyear(yr=06); 
	proc sql;
			create table mothers2.b_dx&yr. as 
				select distinct a.*
					, a.birth_stay_st
					, a.birth_stay_end
					, b.srv_dt_adj as event_dt
					, b.dx_cd
					, b.cos_final
				from mothers2.births&yr.  a 
				left join claims&yr..dx_final_cleaned
	(keep = member_id dx_cd srv_dt_adj srv_end_dt_adj cos_final) b
					on a.member_id= b.member_id
					and a.birth_stay_st le b.srv_dt_adj le a.birth_stay_end;
				quit;
				%mend dxyear; 
/**/
/*	%dxyear(yr=06);*/
/*	%dxyear(yr=07);*/
/*	%dxyear(yr=08);*/
/*	%dxyear(yr=09);*/
/*	%dxyear(yr=10);*/
/*	%dxyear(yr=11);*/
/**/
/*	%dxyear(yr=06);*/
/*	%dxyear(yr=07);*/
/*	%dxyear(yr=08);*/
/*	%dxyear(yr=09);*/
/*	%dxyear(yr=10);*/
/*	%dxyear(yr=11);*/
/**/

	%pxyear(yr=12);
	%pxyear(yr=13);
	%pxyear(yr=14); /* There was a roll up problem 2013 and 2014 px files*/
	%pxyear(yr=15);
/*	%pxyear(yr=16);*/
/*	%pxyear(yr=17);*/

	%dxyear(yr=12);
	%dxyear(yr=13);
	%dxyear(yr=14); /* There was a roll up problem 2013 and 2014 px files*/
	%dxyear(yr=15);
/*	%dxyear(yr=16);*/
/*	%dxyear(yr=17);*/

%macro quiet;	
*checks;
proc sql;
create table mothers2.aproc990 as
select * from mothers.b_px12
where proc_cd  like '990%'  and member_id in select member_id from mothers.ids;
quit;
%mend quiet;


/***************************
*Morbidities****************
****************************/


*###########################################################################################################;
*note - lengths of codes on CDC website were found to be inconsistent,
New York state code does not account for length of codes. We do limit the
length of the code for blood transfusion procedure in icd9 because these were
found to incorrectly identify numerous claims unrelated to blood transfusion
;

%macro smmdx_icd9_flag(yr=12);
*ICD9;

*DIAGNOSIS CODES;
data mothers2.b_dx&yr._smm;
set mothers2.b_dx&yr.;

label MI_flag = "Acute myocardial infarction";
MI_flag = 0;
if dx_cd in :('410') /*and length(dx_cd) le 5*/
then MI_flag =1;

label Aneurysm_flag = "Aneurysm";
Aneurysm_flag = 0;
if dx_cd in :('441') /*and length(dx_cd) le 5*/
then Aneurysm_flag =1;

label Renal_flag = "Acute renal failure";
Renal_flag = 0;
if (dx_cd in :('5845','5846','5847','5848','5849','6693') /*and length(dx_cd) le 4*/) 
	or
	(dx_cd in : ('6693') /*and length(dx_cd) eq 5)*/)
then Renal_flag= 1;

label Resp_flag = "Adult respiratory distress syndrome";
Resp_flag = 0;
if (dx_cd in :('5185','51881', '51882', '51884') /*and length(dx_cd) le 5*/) 
	or
	(dx_cd in : ('7791') /*and length(dx_cd) le 4)*/)
then Resp_flag =1;

label Embolism_flag = "Amniotic fluid embolism";
Embolism_flag = 0;
if dx_cd in :('6731') /*and length(dx_cd) le 5*/
then Embolism_flag =1;

label Cardiac_flag = "Cardiac arrest";
Cardiac_flag = 0;
if (dx_cd in :('42741', '42742') /*and length(dx_cd) le 5*/)
or (dx_cd in :('4275') /*and length(dx_cd) le 4*/)
then Cardiac_flag =1;

label Coagulation_flag = "Disseminated intravascular coagulation";
Coagulation_flag = 0;
if (dx_cd in :('2866', '2869', '6663') /*and length(dx_cd) le 4*/) or
(dx_cd in :('6663') /*and length(dx_cd) le 5*/)
then Coagulation_flag =1;

label Eclampsia_flag = "Eclampsia";
Eclampsia_flag = 0;
if dx_cd in :('6426') /*and length(dx_cd) le 4*/
then Eclampsia_flag =1;

label Heart_flag = "Heart failure during procedure or surgery";
Heart_flag = 0;
if dx_cd in :('9971') /*and length(dx_cd) le 4*/
then Heart_flag =1;

label Cerebro_flag = "Puerperal cerebrovascular disorders";
Cerebro_flag = 0;
if dx_cd in :('430','431','432','434', '436', '437', '6715', '6740', '99702') /*and length(dx_cd) le 5*/
then Cerebro_flag =1;

label Pulmonary_flag = "Pulmonary edema/acute heart failure";
Pulmonary_flag = 0;
if (dx_cd in :('5184', '4281', '4280') /*and length(dx_cd) le 5*/) or
(dx_cd in: ('42821', '42823', '42831', '42833', '42841', '42843') /*and length(dx_cd) le 5*/)
then Pulmonary_flag =1;

label Anesthesia_flag = "Severe anesthesia complications";
Anesthesia_flag = 0;
if dx_cd in :('6680','6681','6682') /*and length(dx_cd) le 5*/
then Anesthesia_flag =1;

label Sepsis_flag = "Sepsis";
Sepsis_flag = 0;
if (dx_cd in :('038', '99591', '99592', '6702') /*and length(dx_cd) le 5*/) 
	or (dx_cd in :('6702') /*and length(dx_cd) le 5 */ and event_dt ge '01oct2009'd) 
then Sepsis_flag =1;

label Shock_flag = "Shock";
Shock_flag = 0;
if (dx_cd in :('6691', '9980', '7855') /*and length(dx_cd) le 5*/) or
 (dx_cd in :('9950', '9954') /*and length(dx_cd) le 4*/)
then Shock_flag =1;

label Sicklecell_flag = "Sickle Cell Anemia with Crisis";
Sicklecell_flag = 0;
if dx_cd in :('28242', '28262', '28264', '28269') /*and length(dx_cd) le 5*/
then Sicklecell_flag =1;

label Throm_flag = "Thrombotic embolism";
Throm_flag = 0;
if dx_cd in :('4151', '6730', '6732', '6733', '6738') /*and length(dx_cd) le 5 */
then Throm_flag =1;
run;
%mend smmdx_icd9_flag;

%macro smmpx_icd9_flag(yr=12);
*ICD9;

*PROCEDURE CODES;
data mothers2.b_px&yr._smm;
set mothers2.b_px&yr.;

label Conversion_flag = "Conversion of cardiac rhythm";
Conversion_flag = 0;
if proc_cd in :('996') /*and length(proc_cd) le 4*/
then Conversion_flag =1;

label Transfusion_flag = "Blood Transfusion";
Transfusion_flag = 0;
if proc_cd in :('990') and length(proc_cd) le 4
then Transfusion_flag =1;

label Hysterectomy_flag = "Hysterectomy";
Hysterectomy_flag = 0;
if proc_cd in :('683','684','685','686','687','688','689') /*and length(proc_cd) le 4*/
then Hysterectomy_flag =1;

label Tracheo_flag = "Temporary Tracheostomy";
Tracheo_flag = 0;
if proc_cd in :('311') /*and length(proc_cd) le 3*/
then Tracheo_flag =1;

label Ventilation_flag = "Ventilation";
Ventilation_flag = 0;
if proc_cd in :('9390'	,
'9392'	,
'9601'	,
'9602'	,
'9603'	,
'9604'	,
'9605'	,
'9670'	,
'9671'	,
'9672'	
) /*and length(proc_cd) le 4*/
then Ventilation_flag =1;

run;
%mend smmpx_icd9_flag;




*###########################################################################################################;

%macro smmdx_icd10_flag(yr=12);
*ICD10;

*DIAGNOSIS CODES;
data mothers2.b_dx&yr._smm_icd10;
set mothers2.b_dx&yr.;

label MI_flag = "Acute myocardial infarction";
MI_flag = 0;
if (dx_cd in :('I21') /*and length(dx_cd) le 5*/)
or (dx_cd in :('I22') /*and length(dx_cd) le 5*/)
then MI_flag =1;

label Aneurysm_flag = "Aneurysm";
Aneurysm_flag = 0;
if dx_cd in :('I71','I790') /*and length(dx_cd) le 5*/
then Aneurysm_flag =1;

label Renal_flag = "Acute renal failure";
Renal_flag = 0;
if dx_cd in :('N170', 'N171', 'N172', 'N178', 'N179', 'O904') /*and length(dx_cd) le 4*/
then Renal_flag= 1;

label Resp_flag = "Adult respiratory distress syndrome";
Resp_flag = 0;
if dx_cd in :('J80','J951', 'J952', 'J953', 'J95821', 'J95822', 'J9600', 'J9601', 'J9602')
then Resp_flag =1;

label Embolism_flag = "Amniotic fluid embolism";
Embolism_flag = 0;
if dx_cd in :('O881')
then Embolism_flag =1;

label Cardiac_flag = "Cardiac arrest";
Cardiac_flag = 0;
if dx_cd in :('I462', 'I468', 'I469', 'I4901', 'I4902')
then Cardiac_flag =1;

label Coagulation_flag = "Disseminated intravascular coagulation";
Coagulation_flag = 0;
if (dx_cd in :('D65', 'D688', 'D689', 'O723') /*and length(dx_cd) le 4*/) or
(dx_cd in :('6663')/* and length(dx_cd) le 5*/)
then Coagulation_flag =1;

label Eclampsia_flag = "Eclampsia";
Eclampsia_flag = 0;
if dx_cd in :('O15')/* and length(dx_cd) le 5*/
/*O14.22 – HELLP syndrome (HELLP), second trimester, O14.23 – HELLP syndrome (HELLP), third trimester HELLP syndrome is not included currently (ranges in severity, more research is needed)*/
then Eclampsia_flag =1;

label Heart_flag = "Heart failure during procedure or surgery";
Heart_flag = 0;
if dx_cd in :('I9712', 'I9713', 'I97710', 'I97711')
then Heart_flag =1;

label Cerebro_flag = "Puerperal cerebrovascular disorders";
Cerebro_flag = 0;
if (dx_cd in :('160','161','162','163', '165', '166', '167', '168', 'O2251', 'O2252', 'O2253') /* and length(dx_cd) le 5*/)
	or (dx_cd in :('I9781', 'I9782') /*and length(dx_cd) le 5*/)
 or (dx_cd in: ('O873')/* and length(dx_cd) le 4*/)
then Cerebro_flag =1;

label Pulmonary_flag = "Pulmonary edema/acute heart failure";
Pulmonary_flag = 0;
if dx_cd in :('J810', 'I501', 'I5020', 'I5021', 'I5023', 'I5030', 'I5031', 'I5033', 'I5040', 'I5041', 'I5043', 'I509')
then Pulmonary_flag =1;

label Anesthesia_flag = "Severe anesthesia complications";
Anesthesia_flag = 0;
if dx_cd in :('O740', 'O741', 'O742', 'O743', 'O8901', 'O8909', 'O891', 'O892') /*and length(dx_cd) le 5*/
then Anesthesia_flag =1;

label Sepsis_flag = "Sepsis";
Sepsis_flag = 0;
if dx_cd in :('O85','T80211A', 'T814XXA','R6520', 'R6520','A400', 'A401', 'A403', 'A408', 'A409', 'A410', 
'A411', 'A412', 'A413', 'A414', 'A4150', 'A4151', 'A4152', 'A4153', 'A4159', 'A4181', 'A4189', 'A419', 'A327')
then Sepsis_flag =1;

label Shock_flag = "Shock";
Shock_flag = 0;
if dx_cd in :('O751', 'R570', 'R571', 'R578', 'R579', 'R6521', 'T782XXA', 'T882XXA', 'T886XXA', 'T8110XA', 'T8111XA', 'T8119XA')
then Shock_flag =1;

label Sicklecell_flag = "Sickle Cell Anemia with Crisis";
Sicklecell_flag = 0;
if dx_cd in :('D5700', 'D5701', 'D5702', 'D57211', 'D57212', 'D57219', 'D57411', 'D57412', 'D57419', 'D57811', 'D57812', 'D57819')
then Sicklecell_flag =1;

label Throm_flag = "Thrombotic embolism";
Throm_flag = 0;
if (dx_cd in :('I26') /*and length(dx_cd) le 4*/)
or (dx_cd in: ('O880', 'O882', 'O883', 'O888') /*and length(dx_cd) le 5*/)
then Throm_flag =1;

run;
%mend smmdx_icd10_flag;


%macro smmpx_icd10_flag(yr=12);
*PROCEDURE CODES;
data mothers2.b_px&yr._smm_icd10;
set mothers2.b_px&yr.;


label Conversion_flag = "Conversion of cardiac rhythm";
Conversion_flag = 0;
if proc_cd in: ('5A2204Z', '5A12012')
then Conversion_flag =1;

label Transfusion_flag = "Blood Transfusion";
Transfusion_flag = 0;
if proc_cd in: ('30230H0'	,
'30230H1'	,
'30230J0'	,
'30230J1'	,
'30230K0'	,
'30230K1'	,
'30230L0'	,
'30230L1'	,
'30230M0'	,
'30230M1'	,
'30230N0'	,
'30230N1'	,
'30230P0'	,
'30230P1'	,
'30230Q0'	,
'30230Q1'	,
'30230R0'	,
'30230R1'	,
'30230S0'	,
'30230S1'	,
'30230T0'	,
'30230T1'	,
'30230V0'	,
'30230V1'	,
'30230W0'	,
'30230W1'	,
'30233H0'	,
'30233H1'	,
'30233J0'	,
'30233J1'	,
'30233K0'	,
'30233K1'	,
'30233L0'	,
'30233L1'	,
'30233M0'	,
'30233M1'	,
'30233N0'	,
'30233N1'	,
'30233P0'	,
'30233P1'	,
'30233Q0'	,
'30233Q1'	,
'30233R0'	,
'30233R1'	,
'30233S0'	,
'30233S1'	,
'30233T0'	,
'30233T1'	,
'30233V0'	,
'30233V1'	,
'30233W0'	,
'30233W1'	,
'30240H0'	,
'30240H1'	,
'30240J0'	,
'30240J1'	,
'30240K0'	,
'30240K1'	,
'30240L0'	,
'30240L1'	,
'30240M0'	,
'30240M1'	,
'30240N0'	,
'30240N1'	,
'30240P0'	,
'30240P1'	,
'30240Q0'	,
'30240Q1'	,
'30240R0'	,
'30240R1'	,
'30240S0'	,
'30240S1'	,
'30240T0'	,
'30240T1'	,
'30240V0'	,
'30240V1'	,
'30240W0'	,
'30240W1'	,
'30243H0'	,
'30243H1'	,
'30243J0'	,
'30243J1'	,
'30243K0'	,
'30243K1'	,
'30243L0'	,
'30243L1'	,
'30243M0'	,
'30243M1'	,
'30243N0'	,
'30243N1'	,
'30243P0'	,
'30243P1'	,
'30243Q0'	,
'30243Q1'	,
'30243R0'	,
'30243R1'	,
'30243S0'	,
'30243S1'	,
'30243T0'	,
'30243T1'	,
'30243V0'	,
'30243V1'	,
'30243W0'	,
'30243W1'	,
'30250H0'	,
'30250H1'	,
'30250J0'	,
'30250J1'	,
'30250K0'	,
'30250K1'	,
'30250L0'	,
'30250L1'	,
'30250M0'	,
'30250M1'	,
'30250N0'	,
'30250N1'	,
'30250P0'	,
'30250P1'	,
'30250Q0'	,
'30250Q1'	,
'30250R0'	,
'30250R1'	,
'30250S0'	,
'30250S1'	,
'30250T0'	,
'30250T1'	,
'30250V0'	,
'30250V1'	,
'30250W0'	,
'30250W1'	,
'30253H0'	,
'30253H1'	,
'30253J0'	,
'30253J1'	,
'30253K0'	,
'30253K1'	,
'30253L0'	,
'30253L1'	,
'30253M0'	,
'30253M1'	,
'30253N0'	,
'30253N1'	,
'30253P0'	,
'30253P1'	,
'30253Q0'	,
'30253Q1'	,
'30253R0'	,
'30253R1'	,
'30253S0'	,
'30253S1'	,
'30253T0'	,
'30253T1'	,
'30253V0'	,
'30253V1'	,
'30253W0'	,
'30253W1'	,
'30260H0'	,
'30260H1'	,
'30260J0'	,
'30260J1'	,
'30260K0'	,
'30260K1'	,
'30260L0'	,
'30260L1'	,
'30260M0'	,
'30260M1'	,
'30260N0'	,
'30260N1'	,
'30260P0'	,
'30260P1'	,
'30260Q0'	,
'30260Q1'	,
'30260R0'	,
'30260R1'	,
'30260S0'	,
'30260S1'	,
'30260T0'	,
'30260T1'	,
'30260V0'	,
'30260V1'	,
'30260W0'	,
'30260W1'	,
'30263H0'	,
'30263H1'	,
'30263J0'	,
'30263J1'	,
'30263K0'	,
'30263K1'	,
'30263L0'	,
'30263L1'	,
'30263M0'	,
'30263M1'	,
'30263N0'	,
'30263N1'	,
'30263P0'	,
'30263P1'	,
'30263Q0'	,
'30263Q1'	,
'30263R0'	,
'30263R1'	,
'30263S0'	,
'30263S1'	,
'30263T0'	,
'30263T1'	,
'30263V0'	,
'30263V1'	,
'30263W0'	,
'30263W1'	,
'30273H1'	,
'30273J1'	,
'30273K1'	,
'30273L1'	,
'30273M1'	,
'30273N1'	,
'30273P1'	,
'30273Q1'	,
'30273R1'	,
'30273S1'	,
'30273T1'	,
'30273V1'	,
'30273W1'	,
'30277H1'	,
'30277J1'	,
'30277K1'	,
'30277L1'	,
'30277M1'	,
'30277N1'	,
'30277P1'	,
'30277Q1'	,
'30277R1'	,
'30277S1'	,
'30277T1'	,
'30277V1'	,
'30277W1'	,
'30280B1'	,
'30283B1'	,
'3E030GC'	,
'3E033GC'	,
'3E040GC'	,
'3E043GC'	,
'3E050GC'	,
'3E053GC'	,
'3E060GC'	,
'3E063GC'	)
then Transfusion_flag =1;

label Hysterectomy_flag = "Hysterectomy";
Hysterectomy_flag = 0;
if proc_cd in: ('0UT90ZZ', '0UT94ZZ', '0UT97ZZ', '0UT98ZZ', '0UT9FZZ')
then Hysterectomy_flag =1;

label Tracheo_flag = "Temporary Tracheostomy";
Tracheo_flag = 0;
if proc_cd in: ('0B110Z', '0B110F', '0B113', '0B114')
then Tracheo_flag =1;

label Ventilation_flag = "Ventilation";
Ventilation_flag = 0;
if proc_cd in: ('09HN7BZ'	,
'09HN8BZ'	,
'0BH13EZ'	,
'0BH17EZ'	,
'0BH18EZ'	,
'0CHY7BZ'	,
'0CHY8BZ'	,
'0DH57BZ'	,
'0DH58BZ'	,
'0WHQ73Z'	,
'0WHQ7YZ'	,
'5A09357'	,
'5A09457'	,
'5A09557'	,
'5A1935Z'	,
'5A1945Z'	,
'5A1955Z'	
)
then Ventilation_flag =1;
run;

%mend smmpx_icd10_flag;

/**/
/*%smmpx_icd9_flag(yr=06);*/
/*%smmpx_icd9_flag(yr=07);*/
/*%smmpx_icd9_flag(yr=08);*/
/*%smmpx_icd9_flag(yr=09);*/
/*%smmpx_icd9_flag(yr=10);*/
/*%smmpx_icd9_flag(yr=11);*/
/**/
/*%smmdx_icd9_flag(yr=06);*/
/*%smmdx_icd9_flag(yr=07);*/
/*%smmdx_icd9_flag(yr=08);*/
/*%smmdx_icd9_flag(yr=09);*/
/*%smmdx_icd9_flag(yr=10);*/
/*%smmdx_icd9_flag(yr=11);*/

%smmpx_icd9_flag(yr=12);

/*%smmpx_icd9_flag(yr=13);*/
/*%smmpx_icd9_flag(yr=14);*/

%smmpx_icd9_flag(yr=15);

%smmpx_icd10_flag(yr=15);
/*%smmpx_icd10_flag(yr=16);*/
/*%smmpx_icd10_flag(yr=17);*/

%smmdx_icd9_flag(yr=12);
/*%smmdx_icd9_flag(yr=13);*/
/*%smmdx_icd9_flag(yr=14);*/
%smmdx_icd9_flag(yr=15);

%smmdx_icd10_flag(yr=15);
/*%smmdx_icd10_flag(yr=16);*/
/*%smmdx_icd10_flag(yr=17);*/
/**/
/*proc means data = mothers2.b_dx15_smm; run;*/
/*proc means data = mothers2.b_dx15_smm_icd10; run;*/
/**/
/*proc means data = mothers1.b_dx13_smm; run; */
/*proc means data = mothers2.b_dx13_smm; run; */
/*proc means data = mothers1.b_dx14_smm; run; */
/*proc means data = mothers2.b_dx14_smm; run; */
/**/
/*proc means data = mothers1.b_dx16_smm_icd10; run;/*heart failure and amniotic embolism missing in icd10*/*/
/**/
/*proc means data = mothers1.b_px15_smm; run;*/
/*proc means data = mothers1.b_px15_smm_icd10; run;*/
/**/
/*proc means data = mothers1.b_px12_smm; run;*/
/*proc means data = mothers1.b_px16_smm_icd10; run; /*tracheo temporary missing 2017 2016*/*/
/**/

*###########################################################################################################;
*###########################################################################################################;
/*****************************************************************************************************************
COLLAPSE Get indicators to patient level
*****************************************************************************************************************/
data m3.smm_cl/view=m3.smm_cl;
set 

mothers1.b_px06_smm
mothers1.b_px07_smm
mothers1.b_px08_smm
mothers1.b_px09_smm
mothers1.b_px10_smm
mothers1.b_px11_smm

mothers1.b_dx06_smm
mothers1.b_dx07_smm
mothers1.b_dx08_smm
mothers1.b_dx09_smm
mothers1.b_dx10_smm
mothers1.b_dx11_smm


mothers1.b_px12_smm
mothers2.b_px13_smm
mothers1.b_px14_smm
mothers1.b_px15_smm

mothers1.b_px15_smm_icd10
mothers1.b_px16_smm_icd10
mothers1.b_px17_smm_icd10

mothers1.b_dx12_smm
mothers2.b_dx13_smm
mothers1.b_dx14_smm
mothers1.b_dx15_smm

mothers1.b_dx15_smm_icd10
mothers1.b_dx16_smm_icd10
mothers1.b_dx17_smm_icd10;
run;


/*data mothers2.smm_cl/view=mothers2.smm_cl;*/
/*set */
/**/
/*mothers1.b_px06_smm*/
/*mothers1.b_px07_smm*/
/*mothers1.b_px08_smm*/
/*mothers1.b_px09_smm*/
/*mothers1.b_px10_smm*/
/*mothers1.b_px11_smm*/
/**/
/*mothers1.b_dx06_smm*/
/*mothers1.b_dx07_smm*/
/*mothers1.b_dx08_smm*/
/*mothers1.b_dx09_smm*/
/*mothers1.b_dx10_smm*/
/*mothers1.b_dx11_smm*/
/**/
/**/
/*mothers1.b_px12_smm*/
/*mothers2.b_px13_smm*/
/*mothers1.b_px14_smm*/
/*mothers1.b_px15_smm*/
/**/
/*mothers1.b_px15_smm_icd10*/
/*mothers1.b_px16_smm_icd10*/
/*mothers1.b_px17_smm_icd10*/
/**/
/*mothers1.b_dx12_smm*/
/*mothers2.b_dx13_smm*/
/*mothers1.b_dx14_smm*/
/*mothers1.b_dx15_smm*/
/**/
/*mothers1.b_dx15_smm_icd10*/
/*mothers1.b_dx16_smm_icd10*/
/*mothers1.b_dx17_smm_icd10;*/
/*run;*/

/*data mothers2.smm_cl_look12t15/view=mothers2.smm_cl_look12t15;*/
/*set */
/**/
/*mothers1.b_px06_smm*/
/*mothers1.b_px07_smm*/
/*mothers1.b_px08_smm*/
/*mothers1.b_px09_smm*/
/*mothers1.b_px10_smm*/
/*mothers1.b_px11_smm*/
/**/
/*mothers1.b_dx06_smm*/
/*mothers1.b_dx07_smm*/
/*mothers1.b_dx08_smm*/
/*mothers1.b_dx09_smm*/
/*mothers1.b_dx10_smm*/
/*mothers1.b_dx11_smm*/
/*/**/*/
/**/
/*mothers1.b_px12_smm*/
/*mothers2.b_px13_smm*/
/*mothers1.b_px14_smm*/
/*mothers1.b_px15_smm*/
/**/
/*mothers1.b_px15_smm_icd10*/
/*mothers1.b_px16_smm_icd10*/
/*mothers1.b_px17_smm_icd10*/
/**/
/*mothers1.b_dx12_smm*/
/*mothers2.b_dx13_smm*/
/*mothers2.b_dx14_smm*/
/*mothers1.b_dx15_smm*/
/**/
/*mothers1.b_dx15_smm_icd10*/
/*mothers1.b_dx16_smm_icd10*/
/*mothers1.b_dx17_smm_icd10;*/
/*run;*/

/**/
/*proc sql;*/
/*create table m3.smm_pl_look12t15*/
/*as select distinct*/
/*	member_id*/
/*	,birth_stay_st format = mmddyy10.*/
/*	,max(MI_flag) as MI_flag*/
/*	,max(Aneurysm_flag) as Aneurysm_flag*/
/*	,max(Renal_flag) as Renal_flag*/
/*	,max(Resp_flag) as Resp_flag*/
/*	,max(Embolism_flag) as Embolism_flag*/
/*	,max(Cardiac_flag) as Cardiac_flag*/
/*	,max(Coagulation_flag) as Coagulation_flag*/
/*	,max(Eclampsia_flag) as Eclampsia_flag*/
/*	,max(Heart_flag) as Heart_flag*/
/*	,max(Cerebro_flag) as Cerebro_flag*/
/*	,max(Pulmonary_flag) as Pulmonary_flag*/
/*	,max(Anesthesia_flag) as Anesthesia_flag*/
/*	,max(Sepsis_flag) as Sepsis_flag*/
/*	,max(Shock_flag) as Shock_flag*/
/*	,max(Sicklecell_flag) as Sicklecell_flag*/
/*	,max(Throm_flag) as Throm_flag*/
/*	,max(Conversion_flag) as Conversion_flag*/
/*	,max(Transfusion_flag) as Transfusion_flag*/
/*	,max(Hysterectomy_flag) as Hysterectomy_flag*/
/*	,max(Tracheo_flag) as Tracheo_flag*/
/*	,max(Ventilation_flag) as Ventilation_flag */
/*	from mothers2.smm_cl_look12t15*/
/*	group by */
/*	member_id,*/
/*	birth_stay_st;*/
/*quit;*/
run;
*changed to m3 from mothers2.;
proc sql;
create table m3.smm_pl 
as select distinct
	member_id
	,birth_stay_st format = mmddyy10.
	,max(MI_flag) as MI_flag
	,max(Aneurysm_flag) as Aneurysm_flag
	,max(Renal_flag) as Renal_flag
	,max(Resp_flag) as Resp_flag
	,max(Embolism_flag) as Embolism_flag
	,max(Cardiac_flag) as Cardiac_flag
	,max(Coagulation_flag) as Coagulation_flag
	,max(Eclampsia_flag) as Eclampsia_flag
	,max(Heart_flag) as Heart_flag
	,max(Cerebro_flag) as Cerebro_flag
	,max(Pulmonary_flag) as Pulmonary_flag
	,max(Anesthesia_flag) as Anesthesia_flag
	,max(Sepsis_flag) as Sepsis_flag
	,max(Shock_flag) as Shock_flag
	,max(Sicklecell_flag) as Sicklecell_flag
	,max(Throm_flag) as Throm_flag
	,max(Conversion_flag) as Conversion_flag
	,max(Transfusion_flag) as Transfusion_flag
	,max(Hysterectomy_flag) as Hysterectomy_flag
	,max(Tracheo_flag) as Tracheo_flag
	,max(Ventilation_flag) as Ventilation_flag 
	from m3.smm_cl
	group by 
	member_id,
	birth_stay_st;
quit;

/*****************************************************************************************************************
OVERALL SMM Variables - Count and Dichotomous
*****************************************************************************************************************/
data m3.smm_pl; 
	set m3.smm_pl; 
	array change _numeric_;
	do over change;
		if change = . then change = 0;
	end;
run;

*Create overall SMM flag;
*Changing smm_pl to smm_pl_look12t15 to check something out;
*changing back to smm_pl and m3.;
data m3.smm_pl (drop = i );
set m3.smm_pl;
*SMM 21 indicators;
*Create a count variable for total morbidities;
array SMM_array {*} MI_flag Aneurysm_flag Renal_flag 
Resp_flag Embolism_flag Cardiac_flag Coagulation_flag 
Eclampsia_flag Heart_flag Cerebro_flag Pulmonary_flag
Anesthesia_flag Sepsis_flag Shock_flag Sicklecell_flag 
Throm_flag Conversion_flag 

Transfusion_flag Hysterectomy_flag Tracheo_flag Ventilation_flag;
Total_SMM=0;
do i = 1 to dim(SMM_array);
Total_SMM = sum(of SMM_array{*});
end;
label Total_SMM = "Total SMM";

Any_SMM = 0;
label Any_SMM = "Any SMM";
if Total_SMM ge 1 then Any_SMM = 1;

Nontransfusion_SMM=0;
label Nontransfusion_SMM = "SMM excluding Transfusion";
if (MI_flag + Aneurysm_flag + Renal_flag +
Resp_flag +Embolism_flag +Cardiac_flag +Coagulation_flag +
Eclampsia_flag +Heart_flag +Cerebro_flag +Pulmonary_flag+
Anesthesia_flag +Sepsis_flag +Shock_flag +Sicklecell_flag +
Throm_flag +Conversion_flag +Hysterectomy_flag +Tracheo_flag +
	Ventilation_flag) ge 1 then 
Nontransfusion_SMM = 1;

Nonvent_SMM=0;
label nonvent_SMM = "SMM excluding Ventilation";
if (MI_flag + Aneurysm_flag + Renal_flag +
Resp_flag +Embolism_flag +Cardiac_flag +Coagulation_flag +
Eclampsia_flag +Heart_flag +Cerebro_flag +Pulmonary_flag+
Anesthesia_flag +Sepsis_flag +Shock_flag +Sicklecell_flag +
Throm_flag +Conversion_flag +Hysterectomy_flag +Tracheo_flag +
	 Transfusion_flag) ge 1 then 
Nonvent_SMM =1;


Nontransvent_SMM=0;
label nontransvent_SMM = "SMM excluding Ventilation and Transfusion";
if (MI_flag + Aneurysm_flag + Renal_flag +
Resp_flag +Embolism_flag +Cardiac_flag +Coagulation_flag +
Eclampsia_flag +Heart_flag +Cerebro_flag +Pulmonary_flag+
Anesthesia_flag +Sepsis_flag +Shock_flag +Sicklecell_flag +
Throm_flag +Conversion_flag +Hysterectomy_flag +Tracheo_flag) 
ge 1 then
	Nontransvent_SMM = 1;
	
/*The following low count indicators can be combined:*/
MI_Aneurysm_flag=0;
label MI_Aneurysm_flag = "Acute myocardial infarction/Aneurysm";
if MI_flag+ Aneurysm_flag then MI_Aneurysm_flag = 1;
*Cardiac arrest ventricular fibrillation and conversion of cardiac rhythm;
Cardiac_Conv_flag=0;
label Cardiac_Conv_flag = "Cardiac Arrest/Vent Fib/Conversion";
if Cardiac_Flag + Conversion_flag ge 1 then Cardiac_Conv_flag =1;
*Temporary Tracheostomy and ventilation;
Tracheo_Vent_flag =0;
label Tracheo_Vent_flag = "Tracheo/Ventilation";
if Tracheo_flag + Ventilation_flag ge 1 then Tracheo_Vent_flag=1;
*pregnancy Id;
pregnancy_id = cat(of member_Id, birth_stay_st);
run;

%macro smm_labels(datawant, datahave);
*Labels;
data &datawant;
set &datahave;

birth_year = year(birth_stay_st);
where "01jan2006"d le birth_stay_st le "31dec2017"d; 

label Total_SMM = "Total SMM";
label Any_SMM = "Any SMM";

label nontransfusion_SMM = "SMM excluding Transfusion";
label nonvent_SMM = "SMM excluding Ventilation";
label nontransvent_SMM = "SMM excluding Ventilation and Transfusion";

label MI_flag = "Acute myocardial infarction";
label Aneurysm_flag = "Aneurysm";
label Renal_flag = "Acute renal failure";
label Resp_flag = "Adult respiratory distress syndrome";
label Embolism_flag = "Amniotic fluid embolism";
label Cardiac_flag = "Cardiac arrest";
label Coagulation_flag = "Disseminated intravascular coagulation";
label Eclampsia_flag = "Eclampsia";
label Heart_flag = "Heart failure during procedure or surgery";
label Cerebro_flag = "Puerperal cerebrovascular disorders";
label Pulmonary_flag = "Pulmonary edema/acute heart failure";
label Anesthesia_flag = "Severe anesthesia complications";
label Sepsis_flag = "Sepsis";
label Shock_flag = "Shock";
label Sicklecell_flag = "Sickle Cell Anemia with Crisis";
label Throm_flag = "Thrombotic embolism";
label Conversion_flag = "Conversion of cardiac rhythm";
label Transfusion_flag = "Blood Transfusion";
label Hysterectomy_flag = "Hysterectomy";
label Tracheo_flag = "Temporary Tracheostomy";
label Ventilation_flag = "Ventilation";

label MI_Aneurysm_flag = "Acute myocardial infarction/Aneurysm";
label Cardiac_Conv_flag = "Cardiac Arrest/Vent Fib/Conversion";
label Tracheo_Vent_flag = "Tracheo/Ventilation";
run;
%mend smm_labels;

/*%smm_labels(mothers2.smm_pl, mothers2.smm_pl);*/
* 1442434;
/*%smm_labels(m3.smm_pl_look12t15, m3.smm_pl_look12t15);*/
%smm_labels(m3.smm_pl, m3.smm_pl);
proc freq data = m3.smm_pl;
table birth_year*any_smm/nocol norow nopct;
run;

title;
title;
proc freq data = m3.smm_pl_look12t15;
table birth_year*any_smm/nocol norow nopct;
run;
proc freq data = mothers2.smm_pl;
table birth_year*any_smm/nocol norow nopct;
run;

proc freq data = mothers1.testsd;
table birth_year*any_smm/nocol norow nopct;
run;
proc means data = mothers2.smm_pl;
class birth_stay_st;
format birth_stay_st monyy.;
run;

proc genmod data =  mothers2.smm_pl
		(keep=Nontransvent_SMM birth_year) 
		descending;
		*pregnancy_id bill_prov_id  ;
class 	Nontransvent_SMM   birth_year/param=glm;
		*bill_prov_id pregnancy_id;
model 	Nontransvent_SMM =  birth_year ; */dist=bin;
		*bill_prov_id pregnancy_id;
*lsmeans bill_prov_id ; */om cl exp;

*ods output  ParameterEstimates=mothers.ols1; *observed values; 

run;

proc genmod data =  mothers2.smm_pl
		(keep=Any_SMM birth_year) 
		descending;
		*pregnancy_id bill_prov_id  ;
class 	Any_SMM   birth_year/param=glm;
		*bill_prov_id pregnancy_id;
model 	Any_SMM =  birth_year ; */dist=bin;
		*bill_prov_id pregnancy_id;
*lsmeans bill_prov_id ; */om cl exp;

*ods output  ParameterEstimates=mothers.ols1; *observed values; 

run;

proc freq data=mothers2.smm_pl;
 title "Deliveries by month for 2006-2017";
  tables birth_stay_st*any_smm /no pct missing;
 format birth_stay_st monyy.;
run;

title "nontransvent_smm";
proc genmod data =  mothers1.testsd
		(keep=Nontransvent_SMM birth_year racenum agesmm chronicheart_22mo congenitalheart_22mo hypertension_22mo hematologic_22mo hiv_22mo obesity_22mo) 
		descending;
		*pregnancy_id bill_prov_id  ;
class 	Nontransvent_SMM   birth_year 
		racenum(ref='1') agesmm chronicheart_22mo 
		congenitalheart_22mo hypertension_22mo 
		hematologic_22mo hiv_22mo obesity_22mo/param=glm;
		*bill_prov_id pregnancy_id;
model 	Nontransvent_SMM =  racenum birth_year 
		racenum agesmm chronicheart_22mo 
		congenitalheart_22mo hypertension_22mo 
		hematologic_22mo hiv_22mo obesity_22mo; */dist=bin;
		*bill_prov_id pregnancy_id;
*lsmeans bill_prov_id ; */om cl exp;

*ods output  ParameterEstimates=mothers.ols1; *observed values; 

run;
proc genmod data =  mothers1.testsd
		(keep=Nontransvent_SMM birth_year racenum agesmm chronicheart_22mo congenitalheart_22mo hypertension_22mo hematologic_22mo hiv_22mo obesity_22mo) 
		descending;
		*pregnancy_id bill_prov_id  ;
class 	Nontransvent_SMM   birth_year/param=glm;
		*bill_prov_id pregnancy_id;
model 	Nontransvent_SMM =  birth_year ; */dist=bin;
		*bill_prov_id pregnancy_id;
*lsmeans bill_prov_id ; */om cl exp;

*ods output  ParameterEstimates=mothers.ols1; *observed values; 

run;
proc genmod data =  mothers2.smm_pl
		(keep=Nontransvent_SMM birth_year) 
		descending;
		*pregnancy_id bill_prov_id  ;
class 	Nontransvent_SMM   birth_year/param=glm;
		*bill_prov_id pregnancy_id;
model 	Nontransvent_SMM =  birth_year ; */dist=bin;
		*bill_prov_id pregnancy_id;
*lsmeans bill_prov_id ; */om cl exp;

*ods output  ParameterEstimates=mothers.ols1; *observed values; 

run;


proc means data= mothers2.smm_pl;
run;
proc means data = mothers2.smm_pl;
class birth_year;
run;
/*Top 5:
Transfusion_flag
Coagulation_flag
Ventilation_flag
Sepsis_flag
Eclampsia_flag
*/
proc means data= mothers2.smm_pl(where = (Any_SMM=1));
run;
proc freq data= mothers2.smm_pl;
tables nontransfusion_SMM nonvent_SMM nontransvent_SMM;
run;
/*Top 5:
Transfusion_flag
Coagulation_flag
Ventilation_flag
Sepsis_flag
Eclampsia_flag
*/
proc means data= mothers2.smm_pl;
class birth_year;
run;

proc freq data=mothers2.smm_pl;
 title "Deliveries by month for 2006-2017";
  tables birth_stay_st*any_smm /list missing;
 format birth_stay_st monyy.;
run;

proc freq data=mothers2.smm_pl;
 title "Deliveries by month for 2006-2017";
  tables birth_stay_st*any_smm /list missing;
 format birth_stay_st year.;
run;
proc freq data=mothers2.smm_pl;
 title "Deliveries by month for 2006-2017";
  tables birth_stay_st*any_smm /list missing;
 format birth_stay_st year.;
run;


