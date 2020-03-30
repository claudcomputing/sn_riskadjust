/**************************************************************************************
 Name: Hospital Wide 30-Day Claims-Based Readmission Measure                   
 --------------------------------------------------------------------------------------
 Company: YALE/YNHH CORE										       		    
 Date: last revised on 10/29/18                 						        
 Platform: SAS 9.3 or greater WINDOWS                                 			
 Notes:                                                                        
  2016 Updates: Planned Readmission Algorithm (PRA) Version 4.0 added               			
  2017 Updates: ICD-10 Codes 
  2018 Updates: ICD-10 Codes, CCS map and CC map for ICD-10 codes, PRA, REHAB Indicator        
  2019 Updates: ICD-10 Codes, CCS map and CC map for ICD-10 codes, PRA                                                      
****************************************************************************************/

/*  Input data must conform to the specifications of HCQAR ANALYTIC FILES */    	
OPTIONS SYMBOLGEN MPRINT; 
*****************************************************************************;
* Specify year, disease condition, and various file pathes					*;
*****************************************************************************;
%LET RY2019=;    *location of input data;
%LET FORMAT=;    *location of format files;
%LET MEASURE=HWR;

%LET CONDITION=HW;
%LET YEAR=1718;  

%LET PATH1=&RY2019.\&MEASURE.;
%LET PATH2=&RY2019.\&MEASURE.\RESULTS;  
                                                      
LIBNAME RAW "&PATH1";                            /* RAW: RAW DATA.*/
LIBNAME R   "&PATH2";                            /* R: RESULTS.   */

%LET ADMISSION=RAW.INDEX_&CONDITION._&YEAR; 
%LET POST=RAW.POSTINDEX_&CONDITION._&YEAR; 
%LET HXDIAG=RAW.DIAGHISTORY_&CONDITION._&YEAR;

%LET ALL=R.&CONDITION._READM_ALL;
%LET ANALYSIS=R.&CONDITION._READM_ANALYSIS;
%LET TRANS_DIAG=R.DIAGHISTORY_&CONDITION._&YEAR._TRANS;

%LET HWR_RSRR=R.&CONDITION._READM_RSRR;
%LET RESULTS=R.&CONDITION._READM_RSRR_BS;

%LET PATH31=&RY2019.\&MEASURE.\CODE;                  
%INCLUDE "&PATH31.\&MEASURE._Readmission_Macros_V2019.SAS";    
%LET PATH32=&RY2019.;          
%INCLUDE "&PATH32.\PRA_2019_CODES_MACRO.sas";    
%INCLUDE "&PATH32.\PRA_2019_PostPlanned.sas";

%LET CCS= &FORMAT.\;   *CCS Format directory for ICD-9 Codes *;
%LET CCS10= &FORMAT.\; *CCS Format directory for ICD-10 UPDATED 11/2018*;
%LET CC=  &FORMAT.\;    		   *CC Map directory for ICD-9*;
%LET CC10= &FORMAT.\;     *CC Map directory for ICD-10 UPDATED 11/2018*;

LIBNAME F "&CCS";      
LIBNAME C "&CC";      
LIBNAME F2 "&CCS10";      
LIBNAME C2 "&CC10";      

OPTIONS FMTSEARCH=(F C F2 C2) SYMBOLGEN MPRINT;

%LET MODEL_VAR=AGE_65 MetaCancer SevereCancer OtherCancer Hematological Coagulopathy 
	IronDeficiency LiverDisease PancreaticDisease OnDialysis RenalFailure Transplants
	HxInfection OtherInfectious Septicemia CHF CADCVD Arrhythmias CardioRespiratory 
	COPD LungDisorder Malnutrition MetabolicDisoder Arthritis Diabetes Ulcers
	MotorDisfunction Seizure RespiratorDependence  Alcohol Psychological HipFracture;   
  
*****************************************************************************;
* Create variables for study cohort inclusion and exclusion criteria		*;
*****************************************************************************;

%RETRIEVE_HX(&ADMISSION,&TRANS_DIAG);

data INDEX;
set &ADMISSION (WHERE=(PARA=1)); 
/*Drop these variables to speed up sorting step*/
drop ADMSOUR CCUIND COUNTY DISST EDBVDETH GROUP ICUIND LOS
MSCD NPI_AT NPI_OP   POAEND01-POAEND12 POSTMO POSTMOD POSTMO_A PREMO PROCDT1-PROCDT25
TYPEADM UNRELDMG UNRELDTH UPIN_AT UPIN_OP ;  
RUN;


/* Eliminate admissions that appear twice (across years)*/
PROC SORT DATA=INDEX NODUPKEY DUPOUT=QA_DupOut EQUALS;
	BY HICNO ADMIT DISCH PROVID;
RUN;

/* Identify and combine two adjacent admissions (disch1=admit2):
Use discharge date of 2nd admission to replace discharge date of 1st admission
(disch1=disch2), as well as discharge status, trans_first, trans_mid, postmod.
Create case_p to be used for finding readmission.
This works when there are more than two adjacent admissions */

DATA TEMP; 
	SET INDEX;
	BY HICNO;   
if (admit <= lag(disch) <= disch) and lag(provid)=provid
	and lag(hicno)=hicno and lag(diag1) = diag1
	 then combine0=1;
	else combine0=0;
RUN;

proc sort data=TEMP;
	by hicno descending admit descending disch;
run;

data TEMP2 QA_CombOut_mid;
set TEMP;
by hicno;

if (admit <= lag(admit) <= disch) and 
	lag(provid)=provid
	and lag(hicno)=hicno and lag(diag1) = diag1
	then combine=1;
	else combine=0;
if combine0 and combine then output QA_CombOut_mid;
	else output TEMP2;

run;

data TEMP3 QA_CombOut_last;
set TEMP2;
disch_2=lag(disch);
case_2=lag(case);
ddest_2=lag(ddest);
trans_first_2=lag(trans_first);
trans_mid_2=lag(trans_mid);
postmod_a2=lag(postmod_a);    
if lag(provid)=provid and lag(hicno)=hicno and lag(combine0)=1 then do;
	disch=disch_2;
	case_p=case_2;
	ddest=ddest_2;
	trans_first=trans_first_2;
	trans_mid=trans_mid_2;
	postmod_a=postmod_a2;
	end;
else case_p=case;

drop disch_2 case_2 ddest_2 trans_first_2 trans_mid_2 postmod_a2;

if combine0 ^=1 then output TEMP3;
				else output QA_CombOut_last;

run;

PROC SORT DATA=TEMP3;
	BY HICNO DESCENDING ADMIT  DESCENDING DISCH PROVID;
RUN;

*****************************************;
* Create study cohort					*;
*****************************************;
DATA ALL; 
	SET TEMP3 (DROP=COMBINE0);
	BY HICNO;
ATTRIB TRANSFER_OUT LABEL='TRANSFER OUT' LENGTH=3.;
ATTRIB TRANS_COMBINE LABEL='TRANSFER OUT' LENGTH=3.;
ATTRIB DD30 LABEL='30-DAY MORTALITY FROM DISCHARGE' LENGTH=3.;
ATTRIB AGE_65 LABEL='YEARS OVER 65' LENGTH=3.;
ATTRIB AGE65 LABEL='AGE GE 65' LENGTH=3.;
ATTRIB DEAD LABEL='IN HOSPITAL DEATH' LENGTH=3.;
ATTRIB sample LABEL='MEET INC & EXL CRITERIA' LENGTH=3.;
LENGTH ADDXG $6. DCGDIAG $7. proccc1-proccc25 $7. rehabexcl 3.;

array ahrqcc{25} $ proccc1 - proccc25;
array surg{10} ophtho vascular ortho gen ct uro neuro obgyn plastic ent;
ARRAY proccc (1:25) proccc1-proccc25;

DCGDIAG = diag1;

*******************FOR 2019 Reporting Cohort no longer include ICD-9 Codes***************;

if DVRSND01 = '0' then DO;
	ADDXG = PUT(DCGDIAG,$CCS10cd.);  
	if addxg = "" then delete;      

	Array PROCST{25} $ proc1 - proc25;
	DO J=1 TO 25;
	 	proccc(j) = put(procst(j),$Ccs10proc.); 
	END;

/*Excluded rehab ccs*/
	rehabexcl=0;
	if addxg in ('254') or rehab_ind = 1  then rehabexcl=1 ; ** 2018 Added rehab bed revenue center as indicator of rehab claim;

/*Excluded PSYCH - Note 664-669 are not  assigned in CCS Software */
	psychexcl = 0;   
	if addxg in ('650', '651', '652','654', '655', '656', '657', '658', '659', '662', '670') then psychexcl = 1;

/*Subset Surgeries into catergories;  Make Changes based on ICD-10 Version of CCS Map */
	do i =1 to 25;
		if ahrqcc(i) in ('20', '15', '16', '14', '13', '17') then ophtho=1;
		if ahrqcc(i) in ('51', '55', '52', '60', '59', '56', '53') then vascular=1;
		if ahrqcc(i) in ('153', '146', '152', '158', '3', '161', '142', '147', '162', '148', 
			             '154', '145', '150' ) then ortho=1;  
		if ahrqcc(i) in ('78', '157', '84', '90', '96', '75', '86', '105', '72', '80', 
			             '73', '85', '164', '74', '167', '176', '89', '166', '99', '94',
			             /*'67',*/ '66', '79') then gen=1;  /*CCS 67 WAS REMOVED IN RY2019*/
		if ahrqcc(i) in ('44', '43', /*'49',*/ '36', '42') or PROCST(i) in (&SURG_COHORT_ICD10.) then ct=1; /*A SUBSET OF ICD10 CODES OF CCS 49 WERE ADDED IN RY2019*/
		if ahrqcc(i) in ('101', '112', '103', '104', '114', '118', '113', '106', '109') then uro=1; 
		if ahrqcc(i) in ('1', '9', '2') then neuro=1;
		if ahrqcc(i) in ('172', '175', '28', '144', '160') then plastic=1;
		if ahrqcc(i) in ('33', '10', '12', '26', '21', '23','30','24', '22') then ent=1; 
	    if ahrqcc(i) in ('124', '119', '132', '129', '125', '131', '120', '123', '121', '141', '133') then obgyn=1;  
	end;

	do j=1 to 10;
		if surg(j)=. then surg(j)=0;
	end;
	surg_sum=sum(ophtho, vascular, ortho, gen, ct, uro, neuro, obgyn, plastic, ent);

	attrib category length=$10.;
		if ophtho or vascular or ortho or gen or ct or uro or neuro or plastic or ent or obgyn then
		category='Surgical';
	 		else category='Medical';

	attrib subcategory length=$18.;

	if addxg in ('11', '12', '13', '14', '15', '16', '17', '18', '19', '20', 
                 '21', '22', '23', '24', '29', '30', '31', '32', '33', '34', 
                 '35', '36', '37', '38', '39', '40', '41', '42', '43', '44', 
				 '45','25','26','27','28') then subcategory='Cancer';

		else if addxg in ('56','103', '108', '122', '125', '127', '128', '131') 
				then subcategory='Cardiorespiratory';
		else if addxg in ('96', '97', '100', '101', '102', '104', '105', '106', '107', '114', 
                          '115', '116', '117', '213') 
                then subcategory='CV';
		else if addxg in ('1', '2', '3', '4', '5', '6', '7', '8', '9', '10', 
                          '46', '47', '48', '49', '50', '51', '52', '53', '54', '55', 
                          '57', '58', '59', '60', '61', '62', '63', '64', '76', '77', 
                          '84', '86', '87', '88', '89', '90', '91', '92', '93', '94', 
                          '98', '99', '118', '119', '120', '121', '123', '124', '126', '129', 
                          '130', '132', '133', '134', '135', '136', '137', '138', '139', '140', 
                          '141', '142', '143', '144', '145', '146', '147', '148', '149', '151', 
                          '152', '153', '154', '155', '156', '157', '158', '159', '160', '161', 
                          '162', '163', '164', '165', '166', '167', '168', '169', '170', '171', 
                          '172', '173', '175', '197', '198', '199', '200', '201', '202', '203', 
                          '204', '205', '206', '207', '208', '209', '210', '211', '212', '214', 
                          '215', '217', '225', '226', '228', '229', '230', '231', '232', '234', 
                          '235', '236', '237', '238', '239', '240', '241', '242', '243', '244', 
                          '245', '246', '247', '248', '249', '250', '251', '252', '253', '255', 
                          '256', '257', '258', '259', '653', '660', '661', '663', '2617' )
				then subcategory='Medicine';  
		else if addxg in ('78', '79', '80', '81', '82', '83', '85', '95', '109', '110',
		                  '111', '112', '113', '216', '227', '233') 
                then subcategory='Neurology';
END;

if category='Surgical' then subcategory='Surgical';
if rehabexcl=1 then subcategory =('Rehab excl');
if psychexcl=1 then subcategory =('Psych excl');

/*Excluded PPS-Exempt cancer hopitals*/
if provid in ('050146','050660','100079','100271','220162','330354','360242','390196','450076','330154','500138') 
then cancer_hosp=1; else cancer_hosp = 0;

all = 1;
  
TRANSFER_OUT=(ADMIT <= LAG(ADMIT) <= DISCH +1) AND (HICNO=LAG(HICNO)) AND (PROVID ^=LAG(PROVID));
TRANS_COMBINE=(TRANSFER_OUT OR TRANS_FIRST OR TRANS_MID or post_flag); 

MALE=(SEX='1');
AGE=INT((ADMIT - BIRTH)/365.25);
AGE65=(AGE >=65);
AGE_65=AGE - 65;

DEAD=(DDEST=20);
AMA=(DDEST=7);

IF DEATH ^=. THEN DO;
	IF 0 < (DEATH - DISCH) <=30 THEN DD30=1;
	ELSE IF (DEATH - DISCH) > 30 THEN DD30=0;
	ELSE IF (DEATH - DISCH) <= 0 THEN DD30=0;
	END;
ELSE DD30=0;
obs30_mort=dd30;

/*PREMO_A is PART A enrollment only*/
PRIOR12=(PREMO_A=12);    

/*If pt dies in 30day post period they are eligible*/
IF DD30=1 THEN POSTMOD_A=1;   
POST1=(POSTMOD_A IN (1, 2, 3));

/* INCLUSION CRITERIA: FFS,AGE GE 65,IN HOSPITAL DEATH,TRANSFER OUT,WITH 12-MONTH HISTORY,
   EXCLUSION CRITERIA: WITHOUT >= 1 MONTH POST, AMA, 
   NOT COUNTED AS RADM30: CANCER Medical,PPS Cancer Hosp, Rehab, psych*/
if dead=0 and age65 and post1=1 and trans_combine=0 and PRIOR12=1 and ama = 0 and 
   rehabexcl=0 and cancer_hosp = 0  and subcategory not in ('Cancer') and psychexcl=0
   then sample = 1; else sample=0 ;
RUN;

 
proc freq data=all;
tables subcategory rehabexcl trans dead para prior12 post1 psychexcl cancer_hosp ama age65 ;
*ophtho  vascular  ortho  gen  ct  uro  neuro  plastic  ent  obgyn;
run;

proc freq data=all; where age65 = 1 and dead=0 and post1 = 1;
tables subcategory rehabexcl trans dead para prior12 post1 psychexcl cancer_hosp ama age65 ;
*ophtho  vascular  ortho  gen  ct  uro  neuro  plastic  ent  obgyn;
run;

PROC SORT DATA=ALL;
BY HICNO CASE_P;
RUN;

/*Define Planned Readmissions Version 4.0 in Post Index File*/
%Post_planned;

proc sort data=postindex; 
by hicno case admit; 
run;


data readm1 QA_DupIndex; 
merge ALL (IN=A)
	postindex (IN=B KEEP=HICNO ADMIT DISCH PROVID DIAG1 PROCCCP_1 - PROCCCP_25 CASE planned	procnum proc1-proc25 DVRSND01 rehab_ind
				RENAME=(DIAG1=_DIAG1 ADMIT=_ADMIT DISCH=_DISCH PROVID=_PROVID proc1-proc25=_proc1-_proc25 CASE=CASE_P 
                        DVRSND01=_DVRSND01 rehab_ind=_rehab_ind));    ****will need to keep rehab indicator for postindex;    
by HICNO CASE_P;
IF A;

IF NOT B THEN RADM30ALL=0;
ELSE IF 0 <= _ADMIT - DISCH <=30 THEN RADM30ALL=1;
ELSE IF _ADMIT - DISCH > 30 THEN RADM30ALL=0;

INTERVAL=_ADMIT - DISCH;
SAME=(PROVID=_PROVID); 
RADM30=RADM30ALL;

radm30p=0;
if planned =1 and RADM30=1 then do;
RADM30 = 0;
radm30p = 1;
end;
 
if _DVRSND01 = '0' then DO;
	if ((interval in (0,1)) and ddest=62) or _rehab_ind=1 then Radm_rehab=1; *2018 UPDATE TO INCLUDE EXCLUSION FOR REHAB REVENUE CENTER CODES ON POSTINDEX ;
		else Radm_rehab=0;
	if (_diag1=:'F' ) and (interval in (0,1))  and
		ddest=65 then Radm_psy=1; else Radm_psy=0;
END;
	
if radm_rehab=1 and (radm30=1 or radm30p = 1) then do; radm30=0; radm30p = 0; interval = 999;  end;
if radm_psy=1 and (radm30=1 or radm30p = 1) then do; radm30=0; radm30p = 0; interval = 999;	end;

hicno_case=strip(hicno)||strip(case_p);

DROP I;


*ICD-10: Same day bundle index should be excluded;
If RADM30=1 and interval=0 and same=1 and diag1=_diag1 then do;
Bundle=1;
Sample=0;
end;

IF ADMIT=_ADMIT AND DISCH=_DISCH AND PROVID=_PROVID AND DIAG1=_DIAG1 THEN OUTPUT QA_DupIndex; 
	ELSE OUTPUT readm1;
run;



proc sort data=readm1;
*ICD-10: Added another level to account for transfers in the postindex file;
by hicno_case interval descending _disch;
run;

data readm1data;
set readm1;
by hicno_case;
if first.hicno_case;
DROP HICNO_CASE;
run;

proc freq data=readm1data;
where sample=1;
tables radm30 radm30p;
run;
	
proc sort data=readm1data;
by hicno case;
run;

DATA sample;
set readm1data (where=(sample=1));
csex=put(sex, $1.);
attrib addxgnum length=8.; 
addxgnum=input(addxg, 8.);
drop sex;
RUN;
 
/*DETERMINE GRAB BAG CATEGORIES */
proc sql;
create table temp_indicator as
select distinct subcategory, addxg, count(hicno) as addxgvol
from sample
group by subcategory, addxg
having addxgvol < 1000;
quit;

proc sql;
select unique(addxg)
into:  med_lfaddxg separated by ','
from temp_indicator
where subcategory='Medicine';

select unique(addxg)
into:  surg_lfaddxg separated by ','
from temp_indicator
where subcategory='Surgical';

select unique(addxg)
into:  cardio_lfaddxg separated by ','
from temp_indicator
where subcategory='Cardiorespiratory';

select unique(addxg)
into:  cv_lfaddxg separated by ','
from temp_indicator
where subcategory='CV';

select unique(addxg)
into:  neuro_lfaddxg separated by ','
from temp_indicator
where subcategory='Neurology';

quit;

DATA _NULL_;

%LET MFILLER=0;

IF SYMEXIST('MED_LFADDXG')=0 THEN DO;
	CALL SYMPUT('MED_LFADDXG', '&MFILLER');
	END;
IF SYMEXIST('SURG_LFADDXG')=0 THEN DO;
	CALL SYMPUT('SURG_LFADDXG', '&MFILLER');
	END;
IF SYMEXIST('CV_LFADDXG')=0 THEN DO;
	CALL SYMPUT('CV_LFADDXG', '&MFILLER');
	END;
IF SYMEXIST('CARDIO_LFADDXG')=0 THEN DO;
	CALL SYMPUT('CARDIO_LFADDXG', '&MFILLER');
	END;
IF SYMEXIST('NEURO_LFADDXG')=0 THEN DO;
	CALL SYMPUT('NEURO_LFADDXG', '&MFILLER');
	END;

RUN;

****************************************************************;
*Create risk factors for adjustment							   *;
****************************************************************;
 
DATA HXDIAG;
SET &HXDIAG &TRANS_DIAG (IN=B);
if source in ('0.0.1.0','0.0.2.0'); /* only ip history available */
RUN;


PROC SQL;
CREATE TABLE HXDIAG AS
SELECT SAMPLE.HICNO, SAMPLE.CASE, SAMPLE.AGE, SAMPLE.CSEX AS SEX,
	HXDIAG.DIAG, HXDIAG.FDATE,
	HXDIAG.SOURCE,
	HXDIAG.TDATE, HXDIAG.YEAR, HXDIAG.DVRSND 
FROM SAMPLE LEFT JOIN HXDIAG
	ON SAMPLE.HICNO=HXDIAG.HICNO AND SAMPLE.HISTORY_CASE=HXDIAG.CASE;
QUIT;


%HCCPAI(sample, &CONDITION._PA0);   

data  &CONDITION._PA2 &CONDITION._PA1;
set hxdiag (keep=hicno case AGE SEX diag source DVRSND where=(diag^=''));
attrib icd  length=$7.;  
icd=diag;
DVRSCD=DVRSND;
if source in ('0.0.1.0') then output &CONDITION._PA1;
else if source in ('0.0.2.0') then output &CONDITION._PA2;
Run;

%cms_hcc_get(&CONDITION._PA0, &CONDITION._PA0_CC, PA0);
   
%cms_hcc_get(&CONDITION._PA1, &CONDITION._PA1_CC, PA1);
   
%cms_hcc_get(&CONDITION._PA2, &CONDITION._PA2_CC, PA2);
  

PROC SORT DATA=&CONDITION._PA0_CC;
	BY HICNO CASE;
RUN;
PROC SORT DATA=&CONDITION._PA2_CC;
	BY HICNO CASE;
RUN;
PROC SORT DATA=&CONDITION._PA1_CC;
	BY HICNO CASE;
RUN;

DATA &ANALYSIS;
MERGE 	sample (in=a)
		&CONDITION._PA2_CC  
		&CONDITION._PA1_CC
		&CONDITION._PA0_CC;
BY HICNO CASE;
IF A;

ARRAY PA0{1:201} PA0CC1-PA0CC201;
ARRAY PA2{1:201} PA2CC1-PA2CC201;
ARRAY PA1{1:201} PA1CC1-PA1CC201;
ARRAY CC{1:201}  CC1 - CC201;

ARRAY COMP{*} 	PA0CC2 PA0CC7 PA0CC17 PA0CC24 PA0CC36 PA0CC48 PA0CC82 PA0CC84 PA0CC85 PA0CC86
                PA0CC87 PA0CC96 PA0CC97 PA0CC103 PA0CC104 PA0CC106 PA0CC107 PA0CC108 PA0CC109 PA0CC114 
                PA0CC115 PA0CC134 PA0CC135 PA0CC140 PA0CC157 PA0CC158 PA0CC159 PA0CC160 PA0CC170 PA0CC186
                PA0CC189 PA0CC190;
				      
DO I=1 TO dim(COMP);
	IF COMP(I)=1 THEN COMP(I)=0;
END;

DO I=1 TO 201;
	IF PA0[I]=. THEN PA0[I]=0;
	IF PA2[I]=. THEN PA2[I]=0;
	IF PA1[I]=. THEN PA1[I]=0;
	CC[I]=PA2[I] OR PA0[I] OR PA1[I];
END;


Attrib Cohort length=$18.;

IF subcategory='Cardiorespiratory'  THEN Cohort='CARDIORESPIRATORY';
ELSE IF subcategory='CV' THEN Cohort='CV';
ELSE IF subcategory='Neurology' THEN Cohort='NEUROLOGY';
ELSE IF subcategory='Medicine' THEN Cohort='MEDICINE';
ELSE IF  subcategory='Surgical' then Cohort='SURGICAL';
%HWR_model_variables();
%HWR_model_Condition_Indicator();

If Cohort in ('SURGICAL', 'MEDICINE', 'CV', 'CARDIORESPIRATORY', 'NEUROLOGY');
KEEP &MODEL_VAR HICNO CASE ADMIT DISCH PROVID COHORT CATEGORY condition radm30 
     radm30p obs30_mort MBI_CRNT MBI_CLM dual_elig_dsch;
RUN;

data &all;
merge readm1data (in=a) &analysis (keep=hicno case &model_var condition cohort MBI_CRNT MBI_CLM dual_elig_dsch);
by hicno case;
if a;
run;

proc freq data=&analysis; table radm30 radm30p; run;
proc freq data=&analysis; tables MetaCancer SevereCancer OtherCancer Hematological Coagulopathy 
	IronDeficiency LiverDisease PancreaticDisease OnDialysis RenalFailure Transplants
	HxInfection OtherInfectious Septicemia CHF CADCVD Arrhythmias CardioRespiratory 
	COPD LungDisorder Malnutrition MetabolicDisoder Arthritis Diabetes Ulcers
	MotorDisfunction Seizure RespiratorDependence  Alcohol Psychological HipFracture;   
run;


***Run HGLM Analyses by Cohort *****;
%HGLM_CONDITION(&ANALYSIS, CV);
%HGLM_CONDITION(&ANALYSIS, CARDIORESPIRATORY);
%HGLM_CONDITION(&ANALYSIS, NEUROLOGY);
%HGLM_CONDITION(&ANALYSIS, MEDICINE);
%HGLM_CONDITION(&ANALYSIS, SURGICAL);

*********************************************************************************;
*Calculate RSRR by Cohort and Composite                                         *;
*********************************************************************************;
PROC SQL;
CREATE TABLE PROVID AS
SELECT DISTINCT PROVID, 
	COUNT(PROVID) AS VOLUME,
	SUM(RADM30) AS READMISSION,
	SUM(RADM30p) AS READM_PLAN
FROM &ANALYSIS
GROUP BY PROVID;
SELECT MEAN(RADM30) INTO: HWYBAR FROM &ANALYSIS;
QUIT;

DATA &HWR_RSRR;
MERGE 	PROVID (IN=A)
	MEDICINE_RSRR (IN=B KEEP=PROVID SRR VOLUME RSRR OBS RADM RADMP
			RENAME=(SRR=SRR_MED VOLUME=VOLUME_MED RSRR=RSRR_MED OBS=OBS_MED 
	RADM=RADM30_MED RADMP=RADM30P_MED))				
	SURGICAL_RSRR (IN=C KEEP=PROVID SRR VOLUME RSRR OBS RADM RADMP
			RENAME=(SRR=SRR_SURG VOLUME=VOLUME_SURG RSRR=RSRR_SURG OBS=OBS_SURG 
	RADM=RADM30_SURG 	RADMP=RADM30P_SURG))
		CV_RSRR (IN=E KEEP=PROVID SRR VOLUME RSRR OBS RADM RADMP
			RENAME=(SRR=SRR_CV VOLUME=VOLUME_CV RSRR=RSRR_CV OBS=OBS_CV 
	RADM=RADM30_CV RADMP=RADM30P_CV))
		 CARDIORESPIRATORY_RSRR  (IN=F KEEP=PROVID SRR VOLUME RSRR OBS RADM RADMP
			RENAME=(SRR=SRR_CARDIO VOLUME=VOLUME_CARDIO RSRR=RSRR_CARDIO OBS=OBS_CARDIO 
	RADM=RADM30_CARDIO RADMP=RADM30P_CARDIO))
		NEUROLOGY_RSRR (IN=H KEEP=PROVID SRR VOLUME RSRR OBS RADM RADMP
			RENAME=(SRR=SRR_NEURO VOLUME=VOLUME_NEURO RSRR=RSRR_NEURO OBS=OBS_NEURO 
	RADM=RADM30_NEURO RADMP=RADM30P_NEURO));
BY PROVID;

IF A;

ARRAY RESET0{5}  VOLUME_MED VOLUME_SURG VOLUME_CV VOLUME_CARDIO VOLUME_NEURO;
DO I=1 TO 5;
	IF RESET0(I)=. THEN RESET0(I)=0;
END;

/* 1 threshold indicator */
MED_VOL1=(VOLUME_MED >=1); 
SUR_VOL1=(VOLUME_SURG >=1);
CV_VOL1=(VOLUME_CV >=1);
CAR_VOL1=(VOLUME_CARDIO >=1);
NEU_VOL1=(VOLUME_NEURO >=1);

/* 25 threshold indicator */
MED_VOL25=(VOLUME_MED >=25); 
SUR_VOL25=(VOLUME_SURG >=25);
CV_VOL25=(VOLUME_CV >=25);
CAR_VOL25=(VOLUME_CARDIO >=25);
NEU_VOL25=(VOLUME_NEURO >=25);

/* # of cohorts with at least 1 cases */
NUMBER_COHORT1=SUM(MED_VOL1, SUR_VOL1, CV_VOL1, CAR_VOL1, NEU_VOL1);

/* # of cohorts with at least 25 cases */
NUMBER_COHORT25=SUM(MED_VOL25, SUR_VOL25, CV_VOL25, CAR_VOL25, NEU_VOL25);

IF VOLUME_MED>0 THEN MED_NUM=VOLUME_MED*LOG(SRR_MED); ELSE MED_NUM=0;
IF VOLUME_SURG>0 THEN SURG_NUM=VOLUME_SURG*LOG(SRR_SURG); ELSE SURG_NUM=0;
IF VOLUME_CV>0 THEN CV_NUM=VOLUME_CV*LOG(SRR_CV); ELSE CV_NUM=0;
IF VOLUME_CARDIO>0 THEN CARDIO_NUM=VOLUME_CARDIO*LOG(SRR_CARDIO); ELSE CARDIO_NUM=0;
IF VOLUME_NEURO>0 THEN NEURO_NUM=VOLUME_NEURO*LOG(SRR_NEURO); ELSE NEURO_NUM=0;

TOTAL_NUM=SUM(MED_NUM, SURG_NUM, CV_NUM, CARDIO_NUM, NEURO_NUM);

SRR_HWR=EXP(TOTAL_NUM/VOLUME);
RSRR_HWR=(SRR_HWR*&HWYBAR)*100;
OBS_HWR=(READMISSION/VOLUME)*100;

RUN;

