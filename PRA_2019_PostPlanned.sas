/********************************************************************************************
                                           GENERAL
 -------------------------------------------------------------------------------------------
 	 Version 4.0 Planned Readmission Algorithm (PRA) for 2019 Reporting      
	 For Use with 2019 Public Reporting of Claims Based Readmission Measures except CABG and
     THA/THK

     Use with PRA_2019_CODE_MACRO for all CCS and ICD codes needed for this PRA
  
 Created: 12/01/17
 UPDATED: 12/04/18 BY HY
 *******************************************************************************************/ 

%macro Post_planned;
data postindex;
set &post;
length   i j k 3.;
/* determine the Proc CCS group each procedure falls into*/
ATTRIB procccp_1-procccp_25  LENGTH=$3.;
ARRAY procccp_ (1:25) procccp_1-procccp_25;
ARRAY procccsp_(1:25) $  PROC1 - PROC25;
ARRAY PVSNCD_(1:25) $ PVSNCD01-PVSNCD25; 
ARRAY DVRSND_(1:25) $ DVRSND01-DVRSND25; 

DCGDIAG = diag1;

/*PR4-ACUTE CARE Dx*/
/*ICD-9 VERSION*/
IF  DVRSND01 = "9" THEN DO; 
	ADDXG_P = PUT(DCGDIAG,$CCS.);
	excldx = 0; 
		if ADDXG_p in (&CCS9_DIAG.)
			OR
		diag1 in (&ICD9_DIAG_Acute.)
		then excldx = 1; 
END;
/*ICD-10 VERSION*/
IF DVRSND01 = "0" THEN DO;
  	ADDXG_P = PUT(DCGDIAG,$CCS10CD.);
  	excldx = 0; 
  		IF ADDXG_p in (&CCS10_DIAG.)
   		  OR 
  		diag1 in (&ICD10_DIAG_Acute.)
		OR
		diag1 in (&ICD10_DIAG_Acute_1.)
		OR
		diag1 in (&ICD10_DIAG_Acute_2.)
   		  OR
  		&ICD10_DIAG_EXCL_1. 
  		  OR
   		&ICD10_DIAG_EXCL_2. 
		  OR
  		&ICD10_DIAG_EXCL_3. 
  		  OR
		&ICD10_DIAG_EXCL_4.
  		  OR
		&ICD10_DIAG_EXCL_5. 
		THEN excldx = 1; 
END;

/***********************************************
 ***** ASSIGN PROC CCS TO PROCEDURES  **********
 ***********************************************/
DO k=1 TO 25;
  IF PVSNCD_(k)= "9" THEN procccp_(k) = put(procccsp_(k),$ccsproc.); 
  ELSE IF PVSNCD_(k)= "0" THEN  procccp_(k) = put(procccsp_(k),$ccs10proc.); 
END;

/*PR1-ALWAYS PLANNED PROC*/
ARRAY PROCCS(25) $  PROCCCP_1 - PROCCCP_25;
planned_1 = 0; planned_2=0;
DO I=1 TO 25;
   IF proccs(I) IN (&always_pln_proc.) THEN DO;     
   proc_2  = proccs(I);
   planned_2 = 1; 
   END;
END;

/*PR3-POTENTIAL PLANNED*/
/*PR3-Potentially Planned CCS Procedures*/
DO i=1 TO 25;
  IF (PVSNCD_(i)= "9" AND proccs(i) IN (&CCS9_PROC.))   /* ICD-9 CODE VERSION*/
     OR
     (PVSNCD_(i)= "0" AND proccs(i) IN (&CCS10_PROC.))  /* ICD-10 CODE VERSION*/
     THEN DO;
     procnum  = proccs(i);
     planned_1 = 1; 
     END;
END;
/*PR3-Potentially Planned ICD PROCEDURE CODE LEVEL*/
ARRAY pproc(25) $ PROC1 - PROC25;
DO j=1 TO 25;
   IF (PVSNCD_(j)= "9" AND pproc(j) IN (&ICD9_PROC_PLAN.))
      OR
	  (PVSNCD_(j)= "0" AND pproc(j) IN (&ICD10_PROC_PLAN.))
      THEN planned_1 = 1; 
END;

planned = 0;
/*PR1-Always PLANNED PROC*/
IF planned_2 = 1 THEN DO; 
   planned = 1;
   procnum = proc_2;
   END;
/*PR2-Always Planned Diagnoses
  (1) Maintenance Chemo Therapy;
  (2) Rehabilitation Therapy*/
   ELSE IF ADDXG_p IN (&always_pln_diag.) THEN planned = 1;  
/*^PR4+PR3: NOT PLANNED ACUTE CARE + PLANNED POTENTIAL PROC*/
   ELSE IF planned_1 =1 AND excldx = 1 THEN planned = 0;
   ELSE IF planned_1 =1 AND excldx = 0 THEN planned = 1;
RUN;
%mend POST_PLANNED;

