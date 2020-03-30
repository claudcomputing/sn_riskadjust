/**MACRO PROGRAMS/VARIABLES FOR HOSPITAL WIDE READMISSION SAS PACK Updated 12/04/18 *****/


***************************************************************;
* PROGRAM NAME: BOOTSTRAP_3b_altmethods.SAS                   *;
* LAST REVISED 2014                                           *;
* *************************************************************;
*options pageno=1 date;
*OPTIONS SYMBOLGEN MPRINT;

%MACRO BOOTSTRAP_HOSPITAL_READMISSION(SFILE, TFILE, STARTPOINT, ENDPOINT, SEED);

%LET COHORT1=MEDICINE;
%LET COHORT2=SURGICAL;
%LET COHORT3=CARDIORESPIRATORY;
%LET COHORT4=CV;
%LET COHORT5=NEUROLOGY;

%DO specialty=1 %TO 5;
DATA &TFILE._&&COHORT&specialty;
 
*****************************************************************************;
* FITTING HIERARCHICAL MODEL                                                *;
*****************************************************************************;

%DO specialty=1 %TO 5;


* PARAMETERIZE OPTIMIZATION TECHNIQUE AND OFFER 2 OPTIONS JS 3/19/08 *;

PROC GLIMMIX DATA=BSHP (WHERE=(COHORT="&&COHORT&specialty")) NOCLPRINT  MAXLMMUPDATE= &nbrits;
CLASS H_S_ID CONDITION;
ODS OUTPUT SOLUTIONR=SR_&bs._&&COHORT&specialty;
MODEL RADM30=CONDITION &MODEL_VAR	/d=b link=logit solution;
XBETA=_XBETA_;
RANDOM INTERCEPT/SUBJECT=H_S_ID SOLUTION;
*****RANDOM _RESIDUAL_;  * removed 3/2014 JNG;
OUTPUT OUT=PRED_&bs._&&COHORT&specialty PRED(BLUP ILINK)=PREDPROB PRED(NOBLUP ILINK)=EXPPROB;
ID XBETA PSTATE PROVID H_S_ID HICNO CASE RADM30;
NLOPTIONS TECH=&firstmethod;
run;

* assuming that the one of the methods will converge;
%if %sysfunc(exist(sr_&bs._&&COHORT&specialty)) %then %do;
        data _null_;
            file PRINT;
            put "DEBUG:  iteration # &bs converged with &firstmethod";
        run;
        %end;
    %else %do;
        PROC GLIMMIX DATA=BSHP (WHERE=(COHORT="&&COHORT&specialty")) NOCLPRINT MAXLMMUPDATE= &nbrits;
            CLASS H_S_ID CONDITION;
            ODS OUTPUT SOLUTIONR=SR_&bs._&&COHORT&specialty;
            MODEL RADM30=CONDITION &MODEL_VAR	/d=b link=logit solution;
            XBETA=_XBETA_;
            RANDOM INTERCEPT/SUBJECT=H_S_ID SOLUTION;
*****RANDOM _RESIDUAL_;  * removed 3/2014 JNG;
            OUTPUT OUT=PRED_&bs._&&COHORT&specialty PRED(BLUP ILINK)=PREDPROB PRED(NOBLUP ILINK)=EXPPROB;
            ID XBETA PSTATE PROVID H_S_ID HICNO CASE RADM30;
            NLOPTIONS TECH=&nextmethod;
        run;
        %if %sysfunc(exist(sr_&bs._&&COHORT&specialty)) %then %do;
            data _null_;
                file PRINT;
                put "DEBUG:  iteration # &bs converged with &nextmethod";
            run;
            %end;
        %else %do;
            data _null_;
                file PRINT;
                put "DEBUG:  iteration # &bs failed to converge";
            run;                
            %end;
        %end;

%if %sysfunc(exist(sr_&bs._&&COHORT&specialty)) %then %do;

PROC SORT DATA=PRED_&bs._&&COHORT&specialty;
	BY H_S_ID;
RUN;

DATA RE_&bs._&&COHORT&specialty;
	SET SR_&bs._&&COHORT&specialty (KEEP=SUBJECT ESTIMATE STDERRPRED);
	LENGTH H_S_ID 8.;
	H_S_ID=SUBSTR(SUBJECT, 8);
	multiplier=rannor(&SEED + &bs);
	m_stderr=stderrpred*multiplier;
	DROP SUBJECT;
RUN;


PROC SORT DATA=RE_&bs._&&COHORT&specialty;
	BY H_S_ID;
RUN;

DATA ALL_&bs._&&COHORT&specialty;
	MERGE PRED_&bs._&&COHORT&specialty (IN=A) RE_&bs._&&COHORT&specialty;
	BY H_S_ID;
	IF A;
	LINP=XBETA + ESTIMATE;
	LINP_BS=LINP + m_stderr;
	P_XBETA=EXP(XBETA)/(1 + EXP(XBETA));
	P_LINP=EXP(LINP)/(1 + EXP(LINP));
	P_LINP_BS=EXP(LINP_BS)/(1 + EXP(LINP_BS));
	IF RADM30 ^=. AND P_LINP_BS ^=. AND P_XBETA ^=.;
	KEEP PROVID RADM30 P_XBETA P_LINP_BS H_S_ID;
RUN;;

PROC SQL NOPRINT;
	CREATE TABLE BSHP&BS._&&COHORT&specialty AS
	SELECT DISTINCT H_S_ID, PROVID,
				&BS AS ITERATION, 
				SUM(RADM30) AS RADM, * CHANGED, ZQ, 4/30*;
				RANNOR(&SEED+ &BS) AS SUBID,
				MEAN(P_XBETA) AS EXP_R,
				MEAN(P_LINP_BS) AS PRED_R,
				MEAN(RADM30) AS OBS,
				COUNT(PROVID) AS VOLUME,
				(CALCULATED PRED_R)/(CALCULATED EXP_R) AS SRR
	FROM ALL_&bs._&&COHORT&specialty
	GROUP BY H_S_ID;
QUIT;




PROC SORT DATA=BSHP&BS._&&COHORT&specialty;
BY PROVID SUBID;

DATA BSHP&BS._&&COHORT&specialty;
	SET BSHP&BS._&&COHORT&specialty;
	BY PROVID;
	IF FIRST.PROVID THEN OUTPUT;
RUN;

PROC APPEND BASE=&TFILE._&&COHORT&specialty DATA=BSHP&BS._&&COHORT&specialty FORCE;
RUN;

%end;


proc delete data=SR_&bs._&&COHORT&specialty 
				PRED_&bs._&&COHORT&specialty 
				RE_&bs._&&COHORT&specialty
				ALL_&bs._&&COHORT&specialty;
quit;



DM 'LOG; CLEAR';
DM 'OUTPUT; CLEAR';


%END;

%if %sysfunc(exist(BSHP&BS._MEDICINE)) AND 
	%sysfunc(exist(BSHP&BS._SURGICAL)) AND 
	%sysfunc(exist(BSHP&BS._CV)) AND 
	%sysfunc(exist(BSHP&BS._CARDIORESPIRATORY)) AND 
	%sysfunc(exist(BSHP&BS._NEUROLOGY)) %then %do;


PROC SQL noprint;
CREATE TABLE PROVID AS
SELECT DISTINCT PROVID, 
	COUNT(PROVID) AS VOLUME,
	SUM(RADM30) AS READMISSION,
	SUM(RADM30p) AS READM_PLAN
FROM BSHP
GROUP BY PROVID;
SELECT MEAN(RADM30) INTO: HWYBAR FROM BSHP;
QUIT;


DATA HWR_RSRR&BS.;
MERGE 	PROVID (IN=A)
		BSHP&BS._MEDICINE (IN=B KEEP=PROVID SRR VOLUME
			RENAME=(SRR=SRR_MED VOLUME=VOLUME_MED))				
		BSHP&BS._SURGICAL (IN=C KEEP=PROVID SRR VOLUME
			RENAME=(SRR=SRR_SURG VOLUME=VOLUME_SURG))
		BSHP&BS._CV (IN=E KEEP=PROVID SRR VOLUME
			RENAME=(SRR=SRR_CV VOLUME=VOLUME_CV))
		BSHP&BS._CARDIORESPIRATORY  (IN=F KEEP=PROVID SRR VOLUME
			RENAME=(SRR=SRR_CARDIO VOLUME=VOLUME_CARDIO))
		BSHP&BS._NEUROLOGY (IN=H KEEP=PROVID SRR VOLUME
			RENAME=(SRR=SRR_NEURO VOLUME=VOLUME_NEURO));
BY PROVID;

IF A;

ITERATION=&BS;

ARRAY RESET0{5}  VOLUME_MED VOLUME_SURG VOLUME_CV VOLUME_CARDIO VOLUME_NEURO;
DO I=1 TO 5;
	IF RESET0(I)=. THEN RESET0(I)=0;
END;


IF VOLUME_MED>0 THEN MED_NUM=VOLUME_MED*LOG(SRR_MED); ELSE MED_NUM=0;
IF VOLUME_SURG>0 THEN SURG_NUM=VOLUME_SURG*LOG(SRR_SURG); ELSE SURG_NUM=0;
IF VOLUME_CV>0 THEN CV_NUM=VOLUME_CV*LOG(SRR_CV); ELSE CV_NUM=0;
IF VOLUME_CARDIO>0 THEN CARDIO_NUM=VOLUME_CARDIO*LOG(SRR_CARDIO); ELSE CARDIO_NUM=0;
IF VOLUME_NEURO>0 THEN NEURO_NUM=VOLUME_NEURO*LOG(SRR_NEURO); ELSE NEURO_NUM=0;

TOTAL_NUM=SUM(MED_NUM,SURG_NUM, CV_NUM, CARDIO_NUM, NEURO_NUM);


TOTAL_NUM=SUM(MED_NUM, SURG_NUM, CV_NUM, CARDIO_NUM, NEURO_NUM);

SRR_HWR=EXP(TOTAL_NUM/VOLUME);
RSRR_HWR=(SRR_HWR*&HWYBAR)*100;
OBS_HWR=(READMISSION/VOLUME)*100;

KEEP  ITERATION PROVID SRR_HWR RSRR_HWR OBS_HWR VOLUME READMISSION;

RUN;

PROC APPEND BASE=&TFILE._HWR DATA=HWR_RSRR&BS. FORCE;
RUN;

proc delete data=BSHP&BS._MEDICINE BSHP&BS._SURGICAL BSHP&BS._CV BSHP&BS._CARDIORESPIRATORY BSHP&BS._NEUROLOGY HWR_RSRR&BS.
	bshp h h2 provid;
quit;	


%end;

%END;

%MEND BOOTSTRAP_HOSPITAL_READMISSION; 

********************************************************************************************************************************;
