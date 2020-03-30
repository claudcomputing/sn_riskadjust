/**MACRO PROGRAMS/VARIABLES FOR HOSPITAL WIDE READMISSION SAS PACK Updated 12/04/18 *****/
%MACRO RETRIEVE_HX(INDEXFILE,OUT_DIAG);
PROC SQL;
CREATE TABLE BUNDLE AS
SELECT HICNO, CASEID, HISTORY_CASE, COUNT(HICNO) AS MAXCASE
FROM &INDEXFILE (RENAME=(CASE=CASEID))
GROUP BY HICNO, HISTORY_CASE
HAVING MAXCASE > 1;
QUIT;

DATA BUNDLE;
SET BUNDLE;
HICNO_HXCASE=HICNO||'_'||HISTORY_CASE;
RUN;

PROC SORT DATA=BUNDLE;
BY HICNO_HXCASE CASEID;
RUN;

DATA BUNDLE;
SET BUNDLE;
BY HICNO_HXCASE;
IF LAST.HICNO_HXCASE THEN DELETE;
RUN;

PROC SORT DATA=BUNDLE;
BY HICNO CASEID;
RUN;

PROC SORT DATA=&INDEXFILE out=index;
BY HICNO CASE;
RUN;
 
** ICD10: including DVRSND01-DVRSND25, EVRSCD01-EVRSCD12, output DVRSND;        
DATA &OUT_DIAG;
MERGE BUNDLE (IN=A RENAME=(HISTORY_CASE=CASE) DROP=MAXCASE HICNO_HXCASE) 
    index (KEEP=HICNO CASE ADMIT DISCH DIAG1-DIAG25 EDGSCD01-EDGSCD12 EVRSCD01-EVRSCD12 YEAR DVRSND01-DVRSND25    
    RENAME=(CASE=CASEID ADMIT=FDATE DISCH=TDATE));
BY HICNO CASEID;
IF A;
diag26 = EDGSCD01; diag27 = EDGSCD02; diag28 = EDGSCD03; diag29 = EDGSCD04;
diag30 = EDGSCD05; diag31 = EDGSCD06; diag32 = EDGSCD07; diag33 = EDGSCD08;
diag34 = EDGSCD09; diag35 = EDGSCD10; diag36 = EDGSCD11; diag37 = EDGSCD12;

attrib diag length=$7.;    
ARRAY ICD(1:37) $ DIAG1-DIAG37;  
ARRAY DVRSND_(1:37) DVRSND01-DVRSND25 EVRSCD01-EVRSCD12;
DO I=1 TO 37;
    IF I=1 THEN DO;
    SOURCE='0.0.1.0';
        DIAG=ICD(I);
        DVRSND = DVRSND_(I);
    OUTPUT;
    END;
    ELSE DO;
    SOURCE='0.0.2.0';
        DIAG=ICD(I);
        DVRSND = DVRSND_(I);
    OUTPUT;
    END;
END;
KEEP HICNO CASE DIAG FDATE TDATE SOURCE YEAR DVRSND;
RUN;
DATA &OUT_DIAG;
SET &OUT_DIAG;
    IF DIAG IN ('', ' ') THEN DELETE;
RUN;

%MEND RETRIEVE_HX;

%MACRO HCCPAI(INDSN, OUTDSN);
  DATA &OUTDSN;
    SET &INDSN;
    length ICD $7;
    AGE=INT((ADMIT-BIRTH)/365.25);
    SEX=/*"" || */CSEX;
    SOURCE='0.0.2.0'; 
    ARRAY ICDCODE{*} $ DIAG1-DIAG25 EDGSCD01-EDGSCD12;
    array ICDFLAG{1:37} $  DVRSND01-DVRSND25 EVRSCD01-EVRSCD12;
    DO I=2 TO dim(ICDCODE);
        ICD=ICDCODE[I];
        DVRSND = ICDFLAG[I];
        if ICD not in ('', ' ') then output;
        END;
    KEEP HICno CASE AGE SEX ICD SOURCE DVRSND;
    RUN;
   
%MEND HCCPAI;


%MACRO CMS_HCC_GET(INDSN, OUTDSN, prefix); 
  DATA TEMP1;
    SET &INDSN;
	length nhic $18.;
	nhic=strip(hicno) || '_' || strip(put(case,$5.)); 
    LENGTH ADDXG $6.;
 If DVRSND = '9' then do;
       ADDXG = PUT(ICD,$CCASS22V.);
      IF ICD in ('79901', '79902') then ADDXG = '84';
	  IF ICD IN ('40403','40413','40493') THEN ADDXG = '85';
    End;
    else if DVRSND = '0' then do;
      ADDXG = PUT(ICD,$CCASS10V.);
      IF ICD in ('R0902', 'R0901') then ADDXG='84';
	  IF ICD in ('I132') then ADDXG = '85';
      End;

    KEEP HICNO CASE ADDXG SOURCE NHIC ICD AGE SEX DVRSND; /* ZQ: add age and sex */
RUN;

PROC SORT DATA=TEMP1 NODUP;
	BY nhic ADDXG ICD; 
RUN;

  /*  Using a format, this step maps each addxg group for a person into a larger;
  *  group denoted by "CC".  The numeric variable IND is set to the value of ;
  *  the character variable CC. If ind is between 1 and 201 then ;
  *  the ind'th element of the array "C" is set to 1; if not it is set to 0 ;
  *  The array has variables CC1 through CC201. The array is retained as each ;
  *  ADDXG record is mapped for a person.  After last record for a person is;
  *  mapped, the macro at the top of the program is run to allow the presence of;
  *  high severity diseases to cancel out low severity versions of the disease. ;
  *  The final vector of 1's and 0's is stored in the variables HCC1 - HCC201.  ;
  *  The record is written to the output dataset and the CCs are reinitialized  ;
  *  the HCCs are the diagnosis groups that are used in the risk adjustment formula;
  */

 DATA &OUTDSN(KEEP=HICNO CASE &prefix.CC1-&prefix.CC201 NHIC) ERR;
    SET TEMP1;
	by nhic;
    length cc $6.;   
    cc=left(addxg);
    RETAIN &prefix.CC1-&prefix.CC201 0 ;
    ATTRIB &prefix.CC1-&prefix.CC201  LENGTH=3.;
    ARRAY C(201)  &prefix.CC1-&prefix.CC201;

	IF CC NOT IN ('0.0 ',' 0.0','-1.0',' -1.') THEN DO;
      *- to find index for the array for current PHCC -;
      IND = INPUT(CC,8.);
      IF 1<= IND <= 201 THEN C(IND)=1;
      ELSE OUTPUT ERR;
    END;
     
IF LAST.NHIC  THEN DO;
       OUTPUT &OUTDSN;
      DO I=1 TO 201;
        C(I)=0; 
      END;
    END;

    LABEL
			&PREFIX.CC1=	"HIV/AIDS"
			&PREFIX.CC2=	"Septicemia, Sepsis, Systemic Inflammatory Response Syndrome/Shock"
			&PREFIX.CC3=	"Bacterial, Fungal, and Parasitic Central Nervous System Infections"
			&PREFIX.CC4=	"Viral and Late Effects Central Nervous System Infections"
			&PREFIX.CC5=	"Tuberculosis"
			&PREFIX.CC6=	"Opportunistic Infections"
			&PREFIX.CC7=	"Other Infectious Diseases"
			&PREFIX.CC8=	"Metastatic Cancer and Acute Leukemia"
			&PREFIX.CC9=	"Lung and Other Severe Cancers"
			&PREFIX.CC10=	"Lymphoma and Other Cancers"
			&PREFIX.CC11=	"Colorectal, Bladder, and Other Cancers"
			&PREFIX.CC12=	"Breast, Prostate, and Other Cancers and Tumors"
			&PREFIX.CC13=	"Other Respiratory and Heart Neoplasms"
			&PREFIX.CC14=	"Other Digestive and Urinary Neoplasms"
			&PREFIX.CC15=	"Other Neoplasms"
			&PREFIX.CC16=	"Benign Neoplasms of Skin, Breast, Eye"	
			&PREFIX.CC17=	"Diabetes with Acute Complications"
			&PREFIX.CC18=	"Diabetes with Chronic Complications"
			&PREFIX.CC19=	"Diabetes without Complication"
			&PREFIX.CC20=	"Type I Diabetes Mellitus"
			&PREFIX.CC21=	"Protein-Calorie Malnutrition"
			&PREFIX.CC22=	"Morbid Obesity"
			&PREFIX.CC23=	"Other Significant Endocrine and Metabolic Disorders"
			&PREFIX.CC24=	"Disorders of Fluid/Electrolyte/Acid-Base Balance"
			&PREFIX.CC25=	"Disorders of Lipoid Metabolism"
			&PREFIX.CC26=	"Other Endocrine/Metabolic/Nutritional Disorders"
			&PREFIX.CC27=	"End-Stage Liver Disease"
			&PREFIX.CC28=	"Cirrhosis of Liver"
			&PREFIX.CC29=	"Chronic Hepatitis"
			&PREFIX.CC30=	"Acute Liver Failure/Disease"
			&PREFIX.CC31=	"Other Hepatitis and Liver Disease"
			&PREFIX.CC32=	"Gallbladder and Biliary Tract Disorders"
			&PREFIX.CC33=	"Intestinal Obstruction/Perforation"
			&PREFIX.CC34=	"Chronic Pancreatitis"
			&PREFIX.CC35=	"Inflammatory Bowel Disease"
			&PREFIX.CC36=	"Peptic Ulcer, Hemorrhage, Other Specified Gastrointestinal Disorders"
			&PREFIX.CC37=	"Appendicitis"
			&PREFIX.CC38=	"Other Gastrointestinal Disorders"
			&PREFIX.CC39=	"Bone/Joint/Muscle Infections/Necrosis"
			&PREFIX.CC40=	"Rheumatoid Arthritis and Inflammatory Connective Tissue Disease"
			&PREFIX.CC41=	"Disorders of the Vertebrae and Spinal Discs"
			&PREFIX.CC42=	"Osteoarthritis of Hip or Knee"
			&PREFIX.CC43=	"Osteoporosis and Other Bone/Cartilage Disorders"
			&PREFIX.CC44=	"Congenital/Developmental Skeletal and Connective Tissue Disorders"
			&PREFIX.CC45=	"Other Musculoskeletal and Connective Tissue Disorders"
			&PREFIX.CC46=	"Severe Hematological Disorders"
			&PREFIX.CC47=	"Disorders of Immunity"
			&PREFIX.CC48=	"Coagulation Defects and Other Specified Hematological Disorders"
			&PREFIX.CC49=	"Iron Deficiency and Other/Unspecified Anemias and Blood Disease"
			&PREFIX.CC50=	"Delirium and Encephalopathy"
			&PREFIX.CC51=	"Dementia With Complications"
			&PREFIX.CC52=	"Dementia Without Complication"
			&PREFIX.CC53=	"Nonpsychotic Organic Brain Syndromes/Conditions"
			&PREFIX.CC54=	"Drug/Alcohol Psychosis"
			&PREFIX.CC55=	"Drug/Alcohol Dependence"
			&PREFIX.CC56=	"Drug/Alcohol Abuse, Without Dependence"
			&PREFIX.CC57=	"Schizophrenia"
			&PREFIX.CC58=	"Major Depressive, Bipolar, and Paranoid Disorders"
			&PREFIX.CC59=	"Reactive and Unspecified Psychosis"
			&PREFIX.CC60=	"Personality Disorders"
			&PREFIX.CC61=	"Depression"
			&PREFIX.CC62=	"Anxiety Disorders"
			&PREFIX.CC63=	"Other Psychiatric Disorders"
			&PREFIX.CC64=	"Profound Intellectual Disability/Developmental Disorder"
			&PREFIX.CC65=	"Severe Intellectual Disability/Developmental Disorder"
			&PREFIX.CC66=	"Moderate Intellectual Disability/Developmental Disorder"
			&PREFIX.CC67=	"Mild Intellectual Disability, Autism, Down Syndrome"
			&PREFIX.CC68=	"Other Developmental Disorders"
			&PREFIX.CC69=	"Attention Deficit Disorder"
			&PREFIX.CC70=	"Quadriplegia"
			&PREFIX.CC71=	"Paraplegia"
			&PREFIX.CC72=	"Spinal Cord Disorders/Injuries"
			&PREFIX.CC73=	"Amyotrophic Lateral Sclerosis and Other Motor Neuron Disease"
			&PREFIX.CC74=	"Cerebral Palsy"
			&PREFIX.CC75=	"Myasthenia Gravis/Myoneural Disorders and Guillain-Barre Syndrome/Inflammatory and Toxic Neuropathy"
			&PREFIX.CC76=	"Muscular Dystrophy"
			&PREFIX.CC77=	"Multiple Sclerosis"
			&PREFIX.CC78=	"Parkinson's and Huntington's Diseases"
			&PREFIX.CC79=	"Seizure Disorders and Convulsions"
			&PREFIX.CC80=	"Coma, Brain Compression/Anoxic Damage"
			&PREFIX.CC81=	"Polyneuropathy, Mononeuropathy, and Other Neurological Conditions/Injuries"
			&PREFIX.CC82=	"Respirator Dependence/Tracheostomy Status"
			&PREFIX.CC83=	"Respiratory Arrest"
			&PREFIX.CC84=	"Cardio-Respiratory Failure and Shock"
			&PREFIX.CC85=	"Congestive Heart Failure"
			&PREFIX.CC86=	"Acute Myocardial Infarction"
			&PREFIX.CC87=	"Unstable Angina and Other Acute Ischemic Heart Disease"
			&PREFIX.CC88=	"Angina Pectoris"
			&PREFIX.CC89=	"Coronary Atherosclerosis/Other Chronic Ischemic Heart Disease"
			&PREFIX.CC90=	"Heart Infection/Inflammation, Except Rheumatic"
			&PREFIX.CC91=	"Valvular and Rheumatic Heart Disease"
			&PREFIX.CC92=	"Major Congenital Cardiac/Circulatory Defect"
			&PREFIX.CC93=	"Other Congenital Heart/Circulatory Disease"
			&PREFIX.CC94=	"Hypertensive Heart Disease"
			&PREFIX.CC95=	"Hypertension"
			&PREFIX.CC96=	"Specified Heart Arrhythmias"
			&PREFIX.CC97=	"Other Heart Rhythm and Conduction Disorders"
			&PREFIX.CC98=	"Other and Unspecified Heart Disease"
			&PREFIX.CC99=	"Cerebral Hemorrhage"
			&PREFIX.CC100=	"Ischemic or Unspecified Stroke"
			&PREFIX.CC101=	"Precerebral Arterial Occlusion and Transient Cerebral Ischemia"
			&PREFIX.CC102=	"Cerebrovascular Atherosclerosis, Aneurysm, and Other Disease"
			&PREFIX.CC103=	"Hemiplegia/Hemiparesis"
			&PREFIX.CC104=	"Monoplegia, Other Paralytic Syndromes"
			&PREFIX.CC105=	"Late Effects of Cerebrovascular Disease, Except Paralysis"
			&PREFIX.CC106=	"Atherosclerosis of the Extremities with Ulceration or Gangrene"
			&PREFIX.CC107=	"Vascular Disease with Complications"
			&PREFIX.CC108=	"Vascular Disease"
			&PREFIX.CC109=	"Other Circulatory Disease"
			&PREFIX.CC110=	"Cystic Fibrosis"
			&PREFIX.CC111=	"Chronic Obstructive Pulmonary Disease"
			&PREFIX.CC112=	"Fibrosis of Lung and Other Chronic Lung Disorders"
			&PREFIX.CC113=	"Asthma"
			&PREFIX.CC114=	"Aspiration and Specified Bacterial Pneumonias"
			&PREFIX.CC115=	"Pneumococcal Pneumonia, Empyema, Lung Abscess"
			&PREFIX.CC116=	"Viral and Unspecified Pneumonia, Pleurisy"
			&PREFIX.CC117=	"Pleural Effusion/Pneumothorax"
			&PREFIX.CC118=	"Other Respiratory Disorders"
			&PREFIX.CC119=	"Legally Blind"
			&PREFIX.CC120=	"Major Eye Infections/Inflammations"
			&PREFIX.CC121=	"Retinal Detachment"
			&PREFIX.CC122=	"Proliferative Diabetic Retinopathy and Vitreous Hemorrhage"
			&PREFIX.CC123=	"Diabetic and Other Vascular Retinopathies"
			&PREFIX.CC124=	"Exudative Macular Degeneration"
			&PREFIX.CC125=	"Other Retinal Disorders"
			&PREFIX.CC126=	"Glaucoma"
			&PREFIX.CC127=	"Cataract"
			&PREFIX.CC128=	"Other Eye Disorders"
			&PREFIX.CC129=	"Significant Ear, Nose, and Throat Disorders"
			&PREFIX.CC130=	"Hearing Loss"
			&PREFIX.CC131=	"Other Ear, Nose, Throat, and Mouth Disorders"
			&PREFIX.CC132=	"Kidney Transplant Status"
			&PREFIX.CC133=	"End Stage Renal Disease"
			&PREFIX.CC134=	"Dialysis Status"
			&PREFIX.CC135=	"Acute Renal Failure"
			&PREFIX.CC136=	"Chronic Kidney Disease, Stage 5"
			&PREFIX.CC137=	"Chronic Kidney Disease, Severe (Stage 4)"
			&PREFIX.CC138=	"Chronic Kidney Disease, Moderate (Stage 3)"
			&PREFIX.CC139=	"Chronic Kidney Disease, Mild or Unspecified (Stages 1-2 or Unspecified)"
			&PREFIX.CC140=	"Unspecified Renal Failure"
			&PREFIX.CC141=	"Nephritis"
			&PREFIX.CC142=	"Urinary Obstruction and Retention"
			&PREFIX.CC143=	"Urinary Incontinence"
			&PREFIX.CC144=	"Urinary Tract Infection"
			&PREFIX.CC145=	"Other Urinary Tract Disorders"
			&PREFIX.CC146=	"Female Infertility"
			&PREFIX.CC147=	"Pelvic Inflammatory Disease and Other Specified Female Genital Disorders"
			&PREFIX.CC148=	"Other Female Genital Disorders"
			&PREFIX.CC149=	"Male Genital Disorders"
			&PREFIX.CC150=	"Ectopic and Molar Pregnancy"
			&PREFIX.CC151=	"Miscarriage/Terminated Pregnancy"
			&PREFIX.CC152=	"Completed Pregnancy With Major Complications"
			&PREFIX.CC153=	"Completed Pregnancy With Complications"
			&PREFIX.CC154=	"Completed Pregnancy With No or Minor Complications"
			&PREFIX.CC155=	"Uncompleted Pregnancy With Complications"
			&PREFIX.CC156=	"Uncompleted Pregnancy With No or Minor Complications"
			&PREFIX.CC157=	"Pressure Ulcer of Skin with Necrosis Through to Muscle, Tendon, or Bone"
			&PREFIX.CC158=	"Pressure Ulcer of Skin with Full Thickness Skin Loss"
			&PREFIX.CC159=	"Pressure Ulcer of Skin with Partial Thickness Skin Loss"
			&PREFIX.CC160=	"Pressure Pre-Ulcer Skin Changes or Unspecified Stage"
			&PREFIX.CC161=	"Chronic Ulcer of Skin, Except Pressure"
			&PREFIX.CC162=	"Severe Skin Burn or Condition"
			&PREFIX.CC163=	"Moderate Skin Burn or Condition"
			&PREFIX.CC164=	"Cellulitis, Local Skin Infection"
			&PREFIX.CC165=	"Other Dermatological Disorders"
			&PREFIX.CC166=	"Severe Head Injury"
			&PREFIX.CC167=	"Major Head Injury"
			&PREFIX.CC168=	"Concussion or Unspecified Head Injury"
			&PREFIX.CC169=	"Vertebral Fractures without Spinal Cord Injury"
			&PREFIX.CC170=	"Hip Fracture/Dislocation"
			&PREFIX.CC171=	"Major Fracture, Except of Skull, Vertebrae, or Hip"
			&PREFIX.CC172=	"Internal Injuries"
			&PREFIX.CC173=	"Traumatic Amputations and Complications"
			&PREFIX.CC174=	"Other Injuries, modified"
			&PREFIX.CC175=	"Poisonings and Allergic and Inflammatory Reactions"
			&PREFIX.CC176=	"Complications of Specified Implanted Device or Graft"
			&PREFIX.CC177=	"Other Complications of Medical Care"
			&PREFIX.CC178=	"Major Symptoms, Abnormalities"
			&PREFIX.CC179=	"Minor Symptoms, Signs, Findings"
			&PREFIX.CC180=	"Extremely Immature Newborns, Including Birthweight < 1000 Grams"
			&PREFIX.CC181=	"Premature Newborns, Including Birthweight 1000-1499 Grams"
			&PREFIX.CC182=	"Serious Perinatal Problem Affecting Newborn"
			&PREFIX.CC183=	"Other Perinatal Problems Affecting Newborn"
			&PREFIX.CC184=	"Term or Post-Term Singleton Newborn, Normal or High Birthweight"
			&PREFIX.CC185=	"Major Organ Transplant (procedure)"
			&PREFIX.CC186=	"Major Organ Transplant or Replacement Status"
			&PREFIX.CC187=	"Other Organ Transplant Status/Replacement"
			&PREFIX.CC188=	"Artificial Openings for Feeding or Elimination"
			&PREFIX.CC189=	"Amputation Status, Lower Limb/Amputation Complications"
			&PREFIX.CC190=	"Amputation Status, Upper Limb"
			&PREFIX.CC191=	"Post-Surgical States/Aftercare/Elective"
			&PREFIX.CC192=	"Radiation Therapy"
			&PREFIX.CC193=	"Chemotherapy"
			&PREFIX.CC194=	"Rehabilitation"
			&PREFIX.CC195=	"Screening/Observation/Special Exams"
			&PREFIX.CC196=	"History of Disease"
			&PREFIX.CC197=	"Supplemental Oxygen"
			&PREFIX.CC198=	"CPAP/IPPB/Nebulizers"
			&PREFIX.CC199=	"Patient Lifts, Power Operated Vehicles, Beds"
			&PREFIX.CC200=	"Wheelchairs, Commodes"
			&PREFIX.CC201=	"Walkers";
RUN;


%MEND CMS_HCC_GET;

%macro HWR_model_variables();
Attrib HxInfection length=8. label='Severe Infection (CC 1, 3-6)';
Attrib Septicemia length=8. label='Septicemia, sepsis, systemic inflammatory response syndrome/shock (CC 2) ';
Attrib OtherInfectious length=8. label='Other infectious disease & pneumonias (CC 7, 114-116)';
Attrib MetaCancer length=8. label='Metastatic cancer/acute leukemia (CC 8)';
Attrib SevereCancer length=8. label='Severe Cancer (CC 9, 10)';
Attrib OtherCancer length=8. label='Other Cancers (CC 11-14)';
Attrib Diabetes length=8. label='Diabetes mellitus (CC 17-19, 122, 123)';
Attrib Malnutrition length=8. label='Protein-calorie malnutrition (CC 21)';
Attrib MetabolicDisoder length=8. label='Other significant endocrine and metabolic disorders; disorders of fluid/electrolyte/acid-base balance (CC 23-24)';
Attrib LiverDisease length=8. label='End-stage liver disease (CC 27, 28)';
Attrib PancreaticDisease length=8. label='Pancreatic disease; peptic ulcer, hemorrhage, other specified gastrointestinal disorders (CC 34, 36)';
Attrib Arthritis length=8. label='Rheumatoid arthritis and inflammatory connective tissue disease (CC 40) ';
Attrib Hematological length=8. label='Severe Hematological Disorders (CC 46)';
Attrib Coagulopathy length=8. label='Coagulation defects and other specified hematological disorders (CC 48)';
Attrib IronDeficiency length=8. label='Iron deficiency or Other Unspecified Anemias and Blood Disease (CC 49)';
Attrib Alcohol length=8. label='Drug/alcohol psychosis or dependence (CC 54-55)';
Attrib Psychological length=8. label='Psychiatric comorbidity (CC 57-59, 61, 63) ';
Attrib MotorDisfunction length=8. label='Hemiplegia, paraplegia, paralysis, functional disability (CC 70-74 103,104,189,190)';
Attrib Seizure length=8. label='Seizure disorders and convulsions (CC 79)';
Attrib RespiratorDependence length=8. label='Respirator dependence/tracheostomy status (CC 82) ';
Attrib CardioRespiratory length=8. label='Cardio-respiratory failure and shock (CC 84), plus ICD-10-CM codes R09.01 and R09.02';
Attrib CHF length=8. label='Congestive heart failure (CC 85)';
Attrib CADCVD length=8. label='Coronary atherosclerosis or angina, cerebrovascular disease (CC 86-89,102,105-109)';
Attrib Arrhythmias length=8. label='Specified arrhythmias and other heart rhythm disorders (CC 96-97)';
Attrib COPD length=8. label='Coronary obstructive pulmonary disease (COPD) (CC 111) ';
Attrib LungDisorder length=8. label='Fibrosis of lung or other chronic lung disorders (CC 112) ';
Attrib Transplants length=8. label='Transplants (CC 132, 186)';
Attrib OnDialysis length=8. label='Dialysis status (CC 134)';
Attrib RenalFailure length=8. label='Renal failure (CC 135-140)';
Attrib Ulcers length=8. label='Decubitus Ulcer or Chronic Skin Ulcer (CC 157-161) ';
Attrib HipFracture length=8. label='Hip fracture/dislocation (CC 170)';

       HxInfection = (CC1 OR CC3 OR CC4 OR CC5 OR CC6);
	   Septicemia  = (CC2);
	   OtherInfectious = (CC7 OR CC114 OR CC115 OR CC116);
	   MetaCancer = (CC8);
	   SevereCancer = (CC9 OR CC10);
	   OtherCancer = (CC11 OR CC12 OR CC13 OR CC14);
	   Diabetes = (CC17 OR CC18 OR CC19 OR CC122 OR CC123);
	   Malnutrition = (CC21);
	   MetabolicDisoder = (CC23 OR CC24);
	   LiverDisease = (CC27 OR CC28);
	   PancreaticDisease = (CC34 OR CC36);
	   Arthritis = (CC40);
	   Hematological = (CC46);
	   Coagulopathy = (CC48);
	   IronDeficiency = (CC49);
	   Alcohol = (CC54 OR CC55);
	   Psychological = (CC57 OR CC58 OR CC59 OR CC61 OR CC63);
	   MotorDisfunction = (CC70 OR CC71 OR CC72 OR CC73 OR CC74 OR CC103 OR CC104 OR CC189 OR CC190); 
	   Seizure = (CC79);
	   RespiratorDependence = (CC82);
	   CardioRespiratory = (CC84); 
	   CHF = (CC85); 
	   CADCVD = (CC86 OR CC87 OR CC88 OR CC89 OR CC102 OR CC105 OR CC106 OR CC107 OR CC108 OR CC109); 
	   Arrhythmias = (CC96 OR CC97); 
	   COPD = (CC111);
	   LungDisorder = (CC112); 
	   Transplants = (CC132 OR CC186);  
	   OnDialysis = (CC134); 
	   RenalFailure = (CC135 OR CC136 OR CC137 OR CC138 OR CC139 OR CC140);
	   Ulcers = (CC157 OR CC158 OR CC159 OR CC160 OR CC161); 
	   HipFracture = (CC170); 

%mend HWR_model_variables;

%macro HWR_model_Condition_Indicator();

ATTRIB CONDITION LENGTH=$4.;*****changed to account for new four digit CCS codes used in ICD-10;
condition = addxg;

/* medicine */
IF COHORT = 'MEDICINE' THEN DO;
	IF ADDXGnum IN (&med_lfaddxg) THEN CONDITION='000';
	ELSE CONDITION=ADDXG;
END;

/* surgical */

ELSE IF COHORT = 'SURGICAL' THEN DO;
	IF ADDXGnum IN (&surg_lfaddxg) THEN CONDITION='000';
	ELSE CONDITION=ADDXG;
END;

/* cardiosrespiratory */

ELSE IF COHORT = 'CARDIORESPIRATORY' THEN DO;
	IF ADDXGnum IN (&cardio_lfaddxg) THEN CONDITION='000';
	ELSE CONDITION=ADDXG;
END;

/* cv */

ELSE IF COHORT = 'CV' THEN DO;
	IF ADDXGnum IN (&CV_lfaddxg) THEN CONDITION='000';
	ELSE CONDITION=ADDXG;
END;

/* neurology */

ELSE IF COHORT ='NEUROLOGY' THEN DO;
	IF ADDXGnum IN (&neuro_lfaddxg) THEN CONDITION='000';
	ELSE CONDITION=ADDXG;
END;

%mend HWR_model_Condition_Indicator;

%MACRO HGLM_CONDITION(INFILE, CONDITION);

PROC GLIMMIX DATA=&INFILE (WHERE=(COHORT="&CONDITION")) NOCLPRINT MAXLMMUPDATE=100;
TITLE "HWR READMISSION: &CONDITION COHORT";
CLASS PROVID CONDITION;
MODEL RADM30=CONDITION &MODEL_VAR/D=B LINK=LOGIT SOLUTION;
XBETA=_XBETA_;
LINP=_LINP_;
RANDOM INTERCEPT/SUBJECT=PROVID;
OUTPUT OUT=RADM30
		PRED(BLUP ILINK)=PREDPROB PRED(NOBLUP ILINK)=EXPPROB;
ID XBETA LINP PROVID HICNO CASE RADM30 radm30p;
NLOPTIONS TECH=NMSIMP;
run;

PROC SQL NOPRINT;
SELECT MEAN(RADM30) INTO: YBAR FROM RADM30;
QUIT;

PROC SQL;
CREATE TABLE &CONDITION._RSRR AS
SELECT DISTINCT PROVID, MEAN(RADM30) AS OBS,
						sum(radm30) as radm,  
						sum(radm30p) as radmp,  
     					MEAN(PREDPROB) AS PRED,
						MEAN(EXPPROB) AS EXP,
						(CALCULATED PRED)/(CALCULATED EXP) AS SRR,
						(CALCULATED SRR)*&YBAR AS RSRR,
						COUNT(PROVID) AS VOLUME
FROM RADM30
GROUP BY PROVID;
QUIT;

PROC SORT DATA=&CONDITION._RSRR;
BY PROVID;

%MEND HGLM_CONDITION;

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

ATTRIB H_S_ID LENGTH=8.;
ATTRIB PROVID LENGTH=$6.;
ATTRIB ITERATION LENGTH=8.;
ATTRIB RADM LENGTH=8.;
ATTRIB SUBID LENGTH=8.;
ATTRIB EXP_R LENGTH=8.;
ATTRIB PRED_R LENGTH=8.;
ATTRIB OBS LENGTH=8.;
ATTRIB VOLUME LENGTH=8.;
ATTRIB SRR LENGTH=8.;

H_S_ID=.;
PROVID='';
ITERATION=.;
RADM=.;
SUBID=.;
EXP_R=.;
PRED_R=.;
OBS=.;
VOLUME=.;
SRR=.;
RUN;

%END;

DATA &TFILE._HWR;

ATTRIB PROVID LENGTH=$6.;
ATTRIB ITERATION LENGTH=8.;
ATTRIB OBS_HWR LENGTH=8.;
ATTRIB SRR_HWR LENGTH=8.;
ATTRIB RSRR_HWR LENGTH=8.;
ATTRIB VOLUME LENGTH=8.;
ATTRIB READMISSION LENGTH=8.;

PROVID='';
ITERATION=.;
OBS_HWR=.;
RSRR_HWR=.;
SRR_HWR=.;
VOLUME=.;
READMISSION=.;

RUN;


PROC SORT DATA=&SFILE;
	BY PROVID;
RUN;

PROC SQL NOPRINT;
	CREATE TABLE HOSPITAL AS
	SELECT PROVID, COUNT(PROVID) AS VOLUME
	FROM &SFILE
	GROUP BY PROVID;
QUIT;
 
***************************************************************************;
* SAMPLE HOSPITAL WITH REPLACEMENT                                        *;
* ONE HOSPITAL MAY BE SAMPLED MORE THAN ONCE                              *;
* TOTLA NUMBER OF HOSPITAL WILL EQUAL TO THE NUMBER OF HOSPITAL IN THE    *;
* ORIGINAL DATASET. FOR HOSPITALS THAT APPEAR MORE THAN ONCE, THEY ARE    *;
* TREATED AS DISTINCT HOSPITAL.                                           *;
* ALL THE PATIENTS WITHIN EACH HOSPITAL ARE INCLUDED.                     *;
***************************************************************************;

%DO BS=&STARTPOINT %TO &ENDPOINT;



* SAMPLING HOSPITALS *;
PROC SURVEYSELECT DATA=HOSPITAL METHOD=URS SAMPRATE=1 OUT=H seed=%eval(&bs + &seed);
RUN;

DATA H2;
	SET H;
	DO I=1 TO NUMBERHITS;
			H_S_ID + 1;
		OUTPUT;
	END;
RUN;

PROC SORT DATA=H2;
	BY PROVID;
RUN;

* CONSTRUCTING PATIENT LEVEL DATA BASED ON HOSPITAL LEVEL DATA FROM THE ABOVE STEP *;
* THE TOTAL SAMPLE SIZE MAY BE DIFFERENT FROM THE ORIGINAL SAMPLE SIZE             *;

PROC SQL NOPRINT;
	CREATE TABLE BSHP AS
	SELECT B.H_S_ID, A.* FROM &SFILE AS A INNER JOIN H2 AS B
	ON A.PROVID=B.PROVID;
QUIT;


 
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

***** THIS LIST IS USED TO IDENTIFY ICD-10 SPECIFIC CODES CONSIDERED SURGICAL FOR SURGERY COHORT DEFINTIION *****;
%LET SURG_COHORT_ICD10 = /*ADDED IN 2018
                         '0C9030Z','0C903ZZ','0C9130Z','0C913ZZ','0C9230Z','0C923ZZ','0C9330Z','0C933ZZ','0C9430Z','0C943ZZ',
                         '0C9730Z','0C973ZZ','0C9M30Z','0C9M3ZZ','0C9N30Z','0C9N3ZZ','0C9P30Z','0C9P3ZZ','0C9Q30Z','0C9Q3ZZ',
                         '0C9R30Z','0C9R3ZZ','0C9S30Z','0C9S3ZZ','0C9T30Z','0C9T3ZZ','0C9V30Z','0C9V3ZZ','0CPS70Z','0CPS7DZ',
                         '0CPS80Z','0CPS8DZ','0W9330Z','0W933ZZ','0W9430Z','0W943ZZ','0W9530Z','0W953ZZ','0MPX30Z','0MPY30Z',
                         '0N9030Z','0N903ZZ','0N9130Z','0N913ZZ','0N9230Z','0N923ZZ','0N9330Z','0N933ZZ','0N9430Z','0N943ZZ',
                         '0N9530Z','0N953ZZ','0N9630Z','0N963ZZ','0N9730Z','0N973ZZ','0N9830Z','0N983ZZ','0N9C30Z','0N9C3ZZ',
                         '0N9D30Z','0N9D3ZZ','0N9F30Z','0N9F3ZZ','0N9G30Z','0N9G3ZZ','0N9H30Z','0N9H3ZZ','0N9J30Z','0N9J3ZZ',
                         '0N9K30Z','0N9K3ZZ','0N9L30Z','0N9L3ZZ','0N9M30Z','0N9M3ZZ','0N9N30Z','0N9N3ZZ','0N9P30Z','0N9P3ZZ',
                         '0N9Q30Z','0N9Q3ZZ','0N9X30Z','0N9X3ZZ','0P9030Z','0P903ZZ','0P9130Z',
                         '0P913ZZ','0P9230Z','0P923ZZ','0P9330Z','0P933ZZ','0P9430Z','0P943ZZ','0P9530Z','0P953ZZ','0P9630Z',
                         '0P963ZZ','0P9730Z','0P973ZZ','0P9830Z','0P983ZZ','0P9930Z','0P993ZZ','0P9B30Z','0P9B3ZZ','0P9C30Z',
                         '0P9C3ZZ','0P9D30Z','0P9D3ZZ','0P9F30Z','0P9F3ZZ','0P9G30Z','0P9G3ZZ','0P9H30Z','0P9H3ZZ','0P9J30Z',
                         '0P9J3ZZ','0P9K30Z','0P9K3ZZ','0P9L30Z','0P9L3ZZ','0P9M30Z','0P9M3ZZ','0P9N30Z','0P9N3ZZ','0P9P30Z',
                         '0P9P3ZZ','0P9Q30Z','0P9Q3ZZ','0P9R30Z','0P9R3ZZ','0P9S30Z','0P9S3ZZ','0P9T30Z','0P9T3ZZ','0P9V30Z',
                         '0P9V3ZZ','0PPY30Z','0Q9030Z','0Q903ZZ','0Q9130Z','0Q913ZZ','0Q9230Z','0Q923ZZ','0Q9330Z','0Q933ZZ',
                         '0Q9430Z','0Q943ZZ','0Q9530Z','0Q953ZZ','0Q9630Z','0Q963ZZ','0Q9730Z','0Q973ZZ','0Q9830Z','0Q983ZZ',
                         '0Q9930Z','0Q993ZZ','0Q9B30Z','0Q9B3ZZ','0Q9C30Z','0Q9C3ZZ','0Q9D30Z','0Q9D3ZZ','0Q9F30Z','0Q9F3ZZ',
                         '0Q9G30Z','0Q9G3ZZ','0Q9H30Z','0Q9H3ZZ','0Q9J30Z','0Q9J3ZZ','0Q9K30Z','0Q9K3ZZ','0Q9L30Z','0Q9L3ZZ',
                         '0Q9M30Z','0Q9M3ZZ','0Q9N30Z','0Q9N3ZZ','0Q9P30Z','0Q9P3ZZ','0Q9Q30Z','0Q9Q3ZZ','0Q9R30Z','0Q9R3ZZ',
                         '0Q9S30Z','0Q9S3ZZ','0QPY30Z','0W9230Z','0W923ZZ','0W9630Z','0W963ZZ','0NH005Z','0NH035Z','0NH045Z'
                         REMOVED IN RY2019*/
/*ADDED IN RY2019*/
'021608P', 
'021608Q', 
'021608R', 
'021609P', 
'021609Q', 
'021609R', 
'02160AP', 
'02160AQ', 
'02160AR', 
'02160JP', 
'02160JQ', 
'02160JR', 
'02160KP', 
'02160KQ', 
'02160KR', 
'02160Z7', 
'02160ZP', 
'02160ZQ', 
'02160ZR', 
'02163Z7', 
'021648P', 
'021648Q', 
'021648R', 
'021649P', 
'021649Q', 
'021649R', 
'02164AP', 
'02164AQ', 
'02164AR', 
'02164JP', 
'02164JQ', 
'02164JR', 
'02164KP', 
'02164KQ', 
'02164KR', 
'02164Z7', 
'02164ZP', 
'02164ZQ', 
'02164ZR', 
'021708P', 
'021708Q', 
'021708R', 
'021708S', 
'021708T', 
'021708U', 
'021709P', 
'021709Q', 
'021709R', 
'021709S', 
'021709T', 
'021709U', 
'02170AP', 
'02170AQ', 
'02170AR', 
'02170AS', 
'02170AT', 
'02170AU', 
'02170JP', 
'02170JQ', 
'02170JR', 
'02170JS', 
'02170JT', 
'02170JU', 
'02170KP', 
'02170KQ', 
'02170KR', 
'02170KS', 
'02170KT', 
'02170KU', 
'02170ZP', 
'02170ZQ', 
'02170ZR', 
'02170ZS', 
'02170ZT', 
'02170ZU', 
'021748P', 
'021748Q', 
'021748R', 
'021748S', 
'021748T', 
'021748U', 
'021749P', 
'021749Q', 
'021749R', 
'021749S', 
'021749T', 
'021749U', 
'02174AP', 
'02174AQ', 
'02174AR', 
'02174AS', 
'02174AT', 
'02174AU', 
'02174JP', 
'02174JQ', 
'02174JR', 
'02174JS', 
'02174JT', 
'02174JU', 
'02174KP', 
'02174KQ', 
'02174KR', 
'02174KS', 
'02174KT', 
'02174KU', 
'02174ZP', 
'02174ZQ', 
'02174ZR', 
'02174ZS', 
'02174ZT', 
'02174ZU', 
'021K08P', 
'021K08Q', 
'021K08R', 
'021K09P', 
'021K09Q', 
'021K09R', 
'021K0AP', 
'021K0AQ', 
'021K0AR', 
'021K0JP', 
'021K0JQ', 
'021K0JR', 
'021K0KP', 
'021K0KQ', 
'021K0KR', 
'021K0Z5', 
'021K0Z8', 
'021K0Z9', 
'021K0ZC', 
'021K0ZF', 
'021K0ZP', 
'021K0ZQ', 
'021K0ZR', 
'021K0ZW', 
'021K48P', 
'021K48Q', 
'021K48R', 
'021K49P', 
'021K49Q', 
'021K49R', 
'021K4AP', 
'021K4AQ', 
'021K4AR', 
'021K4JP', 
'021K4JQ', 
'021K4JR', 
'021K4KP', 
'021K4KQ', 
'021K4KR', 
'021K4Z5', 
'021K4Z8', 
'021K4Z9', 
'021K4ZC', 
'021K4ZF', 
'021K4ZP', 
'021K4ZQ', 
'021K4ZR', 
'021K4ZW', 
'021L08P', 
'021L08Q', 
'021L08R', 
'021L09P', 
'021L09Q', 
'021L09R', 
'021L0AP', 
'021L0AQ', 
'021L0AR', 
'021L0JP', 
'021L0JQ', 
'021L0JR', 
'021L0KP', 
'021L0KQ', 
'021L0KR', 
'021L0Z5', 
'021L0Z8', 
'021L0Z9', 
'021L0ZC', 
'021L0ZF', 
'021L0ZP', 
'021L0ZQ', 
'021L0ZR', 
'021L0ZW', 
'021L48P', 
'021L48Q', 
'021L48R', 
'021L49P', 
'021L49Q', 
'021L49R', 
'021L4AP', 
'021L4AQ', 
'021L4AR', 
'021L4JP', 
'021L4JQ', 
'021L4JR', 
'021L4KP', 
'021L4KQ', 
'021L4KR', 
'021L4Z5', 
'021L4Z8', 
'021L4Z9', 
'021L4ZC', 
'021L4ZF', 
'021L4ZP', 
'021L4ZQ', 
'021L4ZR', 
'021L4ZW', 
'02540ZZ', 
'02543ZZ', 
'02544ZZ', 
'02550ZZ', 
'02553ZZ', 
'02554ZZ', 
'02560ZZ', 
'02563ZZ', 
'02564ZZ', 
'02570ZZ', 
'02573ZZ', 
'02574ZZ', 
'02580ZZ', 
'02583ZZ', 
'02584ZZ', 
'02590ZZ', 
'02593ZZ', 
'02594ZZ', 
'025D0ZZ', 
'025D3ZZ', 
'025D4ZZ', 
'025F0ZZ', 
'025F3ZZ', 
'025F4ZZ', 
'025G0ZZ', 
'025G3ZZ', 
'025G4ZZ', 
'025H0ZZ', 
'025H3ZZ', 
'025H4ZZ', 
'025J0ZZ', 
'025J3ZZ', 
'025J4ZZ', 
'025K0ZZ', 
'025K3ZZ', 
'025K4ZZ', 
'025L0ZZ', 
'025L3ZZ', 
'025L4ZZ', 
'025M0ZZ', 
'025M3ZZ', 
'025M4ZZ', 
'025N0ZZ', 
'025N3ZZ', 
'025N4ZZ', 
'0270046', 
'027004Z', 
'0270056', 
'027005Z', 
'0270066', 
'027006Z', 
'0270076', 
'027007Z', 
'02700D6', 
'02700DZ', 
'02700E6', 
'02700EZ', 
'02700F6', 
'02700FZ', 
'02700G6', 
'02700GZ', 
'02700T6', 
'02700TZ', 
'02700Z6', 
'02700ZZ', 
'0271046', 
'027104Z', 
'0271056', 
'027105Z', 
'0271066', 
'027106Z', 
'0271076', 
'027107Z', 
'02710D6', 
'02710DZ', 
'02710E6', 
'02710EZ', 
'02710F6', 
'02710FZ', 
'02710G6', 
'02710GZ', 
'02710T6', 
'02710TZ', 
'02710Z6', 
'02710ZZ', 
'0272046', 
'027204Z', 
'0272056', 
'027205Z', 
'0272066', 
'027206Z', 
'0272076', 
'027207Z', 
'02720D6', 
'02720DZ', 
'02720E6', 
'02720EZ', 
'02720F6', 
'02720FZ', 
'02720G6', 
'02720GZ', 
'02720T6', 
'02720TZ', 
'02720Z6', 
'02720ZZ', 
'0273046', 
'027304Z', 
'0273056', 
'027305Z', 
'0273066', 
'027306Z', 
'0273076', 
'027307Z', 
'02730D6', 
'02730DZ', 
'02730E6', 
'02730EZ', 
'02730F6', 
'02730FZ', 
'02730G6', 
'02730GZ', 
'02730T6', 
'02730TZ', 
'02730Z6', 
'02730ZZ', 
'027K04Z', 
'027K0DZ', 
'027K0ZZ', 
'027K34Z', 
'027K3DZ', 
'027K3ZZ', 
'027K44Z', 
'027K4DZ', 
'027K4ZZ', 
'027L04Z', 
'027L0DZ', 
'027L0ZZ', 
'027L34Z', 
'027L3DZ', 
'027L3ZZ', 
'027L44Z', 
'027L4DZ', 
'027L4ZZ', 
'027R04T', 
'027R0DT', 
'027R0ZT', 
'027R34T', 
'027R3DT', 
'027R3ZT', 
'027R44T', 
'027R4DT', 
'027R4ZT', 
'02880ZZ', 
'02883ZZ', 
'02884ZZ', 
'02890ZZ', 
'02893ZZ', 
'02894ZZ', 
'028D0ZZ', 
'028D3ZZ', 
'028D4ZZ', 
'02B40ZZ', 
'02B43ZZ', 
'02B44ZZ', 
'02B50ZZ', 
'02B53ZZ', 
'02B54ZZ', 
'02B60ZZ', 
'02B63ZZ', 
'02B64ZZ', 
'02B70ZZ', 
'02B73ZZ', 
'02B74ZZ', 
'02B80ZZ', 
'02B83ZZ', 
'02B84ZZ', 
'02B90ZZ', 
'02B93ZZ', 
'02B94ZZ', 
'02BD0ZZ', 
'02BD3ZZ', 
'02BD4ZZ', 
'02BF0ZZ', 
'02BF3ZZ', 
'02BF4ZZ', 
'02BG0ZZ', 
'02BG3ZZ', 
'02BG4ZZ', 
'02BH0ZZ', 
'02BH3ZZ', 
'02BH4ZZ', 
'02BJ0ZZ', 
'02BJ3ZZ', 
'02BJ4ZZ', 
'02BK0ZZ', 
'02BK3ZZ', 
'02BK4ZZ', 
'02BL0ZZ', 
'02BL3ZZ', 
'02BL4ZZ', 
'02BM0ZZ', 
'02BM3ZZ', 
'02BM4ZZ', 
'02BN0ZZ', 
'02BN3ZZ', 
'02BN4ZZ', 
'02C00Z6', 
'02C00ZZ', 
'02C10Z6', 
'02C10ZZ', 
'02C20Z6', 
'02C20ZZ', 
'02C30Z6', 
'02C30ZZ', 
'02C40ZZ', 
'02C43ZZ', 
'02C44ZZ', 
'02C50ZZ', 
'02C53ZZ', 
'02C54ZZ', 
'02C60ZZ', 
'02C63ZZ', 
'02C64ZZ', 
'02C70ZZ', 
'02C73ZZ', 
'02C74ZZ', 
'02C80ZZ', 
'02C83ZZ', 
'02C84ZZ', 
'02C90ZZ', 
'02C93ZZ', 
'02C94ZZ', 
'02CD0ZZ', 
'02CD3ZZ', 
'02CD4ZZ', 
'02CK0ZZ', 
'02CK3ZZ', 
'02CK4ZZ', 
'02CL0ZZ', 
'02CL3ZZ', 
'02CL4ZZ', 
'02CM0ZZ', 
'02CM3ZZ', 
'02CM4ZZ', 
'02CN0ZZ', 
'02CN3ZZ', 
'02CN4ZZ', 
'02FN0ZZ', 
'02FN3ZZ', 
'02FN4ZZ', 
'02H400Z', 
'02H402Z', 
'02H403Z', 
'02H40DZ', 
'02H40YZ', 
'02H43DZ', 
'02H43YZ', 
'02H443Z', 
'02H44DZ', 
'02H44YZ', 
'02H600Z', 
'02H602Z', 
'02H603Z', 
'02H60DZ', 
'02H60YZ', 
'02H63DZ', 
'02H63YZ', 
'02H643Z', 
'02H64DZ', 
'02H64YZ', 
'02H700Z', 
'02H702Z', 
'02H703Z', 
'02H70DZ', 
'02H70YZ', 
'02H73DZ', 
'02H73YZ', 
'02H743Z', 
'02H74DZ', 
'02H74YZ', 
'02HA0QZ', 
'02HA0RJ', 
'02HA0RS', 
'02HA0RZ', 
'02HA0YZ', 
'02HA3QZ', 
'02HA3RJ', 
'02HA3RS', 
'02HA3RZ', 
'02HA3YZ', 
'02HA4QZ', 
'02HA4RJ', 
'02HA4RS', 
'02HA4RZ', 
'02HA4YZ', 
'02HK00Z', 
'02HK02Z', 
'02HK03Z', 
'02HK0DZ', 
'02HK0YZ', 
'02HK3DZ', 
'02HK3YZ', 
'02HK43Z', 
'02HK4DZ', 
'02HK4YZ', 
'02HL00Z', 
'02HL02Z', 
'02HL03Z', 
'02HL0DZ', 
'02HL0YZ', 
'02HL3DZ', 
'02HL3YZ', 
'02HL43Z', 
'02HL4DZ', 
'02HL4YZ', 
'02HN00Z', 
'02HN02Z', 
'02HN0YZ', 
'02HN3YZ', 
'02HN4YZ', 
'02N00ZZ', 
'02N03ZZ', 
'02N04ZZ', 
'02N10ZZ', 
'02N13ZZ', 
'02N14ZZ', 
'02N20ZZ', 
'02N23ZZ', 
'02N24ZZ', 
'02N30ZZ', 
'02N33ZZ', 
'02N34ZZ', 
'02N40ZZ', 
'02N43ZZ', 
'02N44ZZ', 
'02N50ZZ', 
'02N53ZZ', 
'02N54ZZ', 
'02N60ZZ', 
'02N63ZZ', 
'02N64ZZ', 
'02N70ZZ', 
'02N73ZZ', 
'02N74ZZ', 
'02N80ZZ', 
'02N83ZZ', 
'02N84ZZ', 
'02N90ZZ', 
'02N93ZZ', 
'02N94ZZ', 
'02ND0ZZ', 
'02ND3ZZ', 
'02ND4ZZ', 
'02NK0ZZ', 
'02NK3ZZ', 
'02NK4ZZ', 
'02NL0ZZ', 
'02NL3ZZ', 
'02NL4ZZ', 
'02NM0ZZ', 
'02NM3ZZ', 
'02NM4ZZ', 
'02NN0ZZ', 
'02NN3ZZ', 
'02NN4ZZ', 
'02PA02Z', 
'02PA03Z', 
'02PA07Z', 
'02PA08Z', 
'02PA0CZ', 
'02PA0DZ', 
'02PA0JZ', 
'02PA0KZ', 
'02PA0QZ', 
'02PA0RS', 
'02PA0RZ', 
'02PA0YZ', 
'02PA37Z', 
'02PA38Z', 
'02PA3CZ', 
'02PA3JZ', 
'02PA3KZ', 
'02PA3QZ', 
'02PA3RS', 
'02PA3RZ', 
'02PA42Z', 
'02PA43Z', 
'02PA47Z', 
'02PA48Z', 
'02PA4CZ', 
'02PA4DZ', 
'02PA4JZ', 
'02PA4KZ', 
'02PA4QZ', 
'02PA4RS', 
'02PA4RZ', 
'02Q00ZZ', 
'02Q03ZZ', 
'02Q04ZZ', 
'02Q10ZZ', 
'02Q13ZZ', 
'02Q14ZZ', 
'02Q20ZZ', 
'02Q23ZZ', 
'02Q24ZZ', 
'02Q30ZZ', 
'02Q33ZZ', 
'02Q34ZZ', 
'02Q40ZZ', 
'02Q43ZZ', 
'02Q44ZZ', 
'02Q50ZZ', 
'02Q53ZZ', 
'02Q54ZZ', 
'02Q60ZZ', 
'02Q63ZZ', 
'02Q64ZZ', 
'02Q70ZZ', 
'02Q73ZZ', 
'02Q74ZZ', 
'02Q80ZZ', 
'02Q83ZZ', 
'02Q84ZZ', 
'02Q90ZZ', 
'02Q93ZZ', 
'02Q94ZZ', 
'02QA0ZZ', 
'02QA3ZZ', 
'02QA4ZZ', 
'02QB0ZZ', 
'02QB3ZZ', 
'02QB4ZZ', 
'02QC0ZZ', 
'02QC3ZZ', 
'02QC4ZZ', 
'02QD0ZZ', 
'02QD3ZZ', 
'02QD4ZZ', 
'02QK0ZZ', 
'02QK3ZZ', 
'02QK4ZZ', 
'02QL0ZZ', 
'02QL3ZZ', 
'02QL4ZZ', 
'02QM0ZZ', 
'02QM3ZZ', 
'02QM4ZZ', 
'02QN0ZZ', 
'02QN3ZZ', 
'02QN4ZZ', 
'02R507Z', 
'02R508Z', 
'02R50JZ', 
'02R50KZ', 
'02R547Z', 
'02R548Z', 
'02R54JZ', 
'02R54KZ', 
'02R607Z', 
'02R608Z', 
'02R60JZ', 
'02R60KZ', 
'02R647Z', 
'02R648Z', 
'02R64JZ', 
'02R64KZ', 
'02R707Z', 
'02R708Z', 
'02R70JZ', 
'02R70KZ', 
'02R747Z', 
'02R748Z', 
'02R74JZ', 
'02R74KZ', 
'02R907Z', 
'02R908Z', 
'02R90JZ', 
'02R90KZ', 
'02R947Z', 
'02R948Z', 
'02R94JZ', 
'02R94KZ', 
'02RD07Z', 
'02RD08Z', 
'02RD0JZ', 
'02RD0KZ', 
'02RD47Z', 
'02RD48Z', 
'02RD4JZ', 
'02RD4KZ', 
'02RK07Z', 
'02RK08Z', 
'02RK0JZ', 
'02RK0KZ', 
'02RK47Z', 
'02RK48Z', 
'02RK4JZ', 
'02RK4KZ', 
'02RL07Z', 
'02RL08Z', 
'02RL0JZ', 
'02RL0KZ', 
'02RL47Z', 
'02RL48Z', 
'02RL4JZ', 
'02RL4KZ', 
'02RM07Z', 
'02RM08Z', 
'02RM0JZ', 
'02RM0KZ', 
'02RM47Z', 
'02RM48Z', 
'02RM4JZ', 
'02RM4KZ', 
'02RN07Z', 
'02RN08Z', 
'02RN0JZ', 
'02RN0KZ', 
'02RN47Z', 
'02RN48Z', 
'02RN4JZ', 
'02RN4KZ', 
'02T50ZZ', 
'02T53ZZ', 
'02T54ZZ', 
'02T80ZZ', 
'02T83ZZ', 
'02T84ZZ', 
'02T90ZZ', 
'02T93ZZ', 
'02T94ZZ', 
'02TD0ZZ', 
'02TD3ZZ', 
'02TD4ZZ', 
'02TM0ZZ', 
'02TM3ZZ', 
'02TM4ZZ', 
'02TN0ZZ', 
'02TN3ZZ', 
'02TN4ZZ', 
'02U507Z', 
'02U508Z', 
'02U50JZ', 
'02U50KZ', 
'02U537Z', 
'02U538Z', 
'02U53JZ', 
'02U53KZ', 
'02U547Z', 
'02U548Z', 
'02U54JZ', 
'02U54KZ', 
'02U607Z', 
'02U608Z', 
'02U60JZ', 
'02U60KZ', 
'02U637Z', 
'02U638Z', 
'02U63JZ', 
'02U63KZ', 
'02U647Z', 
'02U648Z', 
'02U64JZ', 
'02U64KZ', 
'02U707Z', 
'02U708Z', 
'02U70JZ', 
'02U70KZ', 
'02U737Z', 
'02U738Z', 
'02U73KZ', 
'02U747Z', 
'02U748Z', 
'02U74KZ', 
'02U907Z', 
'02U908Z', 
'02U90JZ', 
'02U90KZ', 
'02U937Z', 
'02U938Z', 
'02U93JZ', 
'02U93KZ', 
'02U947Z', 
'02U948Z', 
'02U94JZ', 
'02U94KZ', 
'02UA07Z', 
'02UA08Z', 
'02UA0JZ', 
'02UA0KZ', 
'02UA37Z', 
'02UA38Z', 
'02UA3JZ', 
'02UA3KZ', 
'02UA47Z', 
'02UA48Z', 
'02UA4JZ', 
'02UA4KZ', 
'02UD07Z', 
'02UD08Z', 
'02UD0JZ', 
'02UD0KZ', 
'02UD37Z', 
'02UD38Z', 
'02UD3JZ', 
'02UD3KZ', 
'02UD47Z', 
'02UD48Z', 
'02UD4JZ', 
'02UD4KZ', 
'02UK07Z', 
'02UK08Z', 
'02UK0JZ', 
'02UK0KZ', 
'02UK37Z', 
'02UK38Z', 
'02UK3JZ', 
'02UK3KZ', 
'02UK47Z', 
'02UK48Z', 
'02UK4JZ', 
'02UK4KZ', 
'02UL07Z', 
'02UL08Z', 
'02UL0JZ', 
'02UL0KZ', 
'02UL37Z', 
'02UL38Z', 
'02UL3JZ', 
'02UL3KZ', 
'02UL47Z', 
'02UL48Z', 
'02UL4JZ', 
'02UL4KZ', 
'02UM07Z', 
'02UM08Z', 
'02UM0JZ', 
'02UM0KZ', 
'02UM37Z', 
'02UM38Z', 
'02UM3JZ', 
'02UM3KZ', 
'02UM47Z', 
'02UM48Z', 
'02UM4JZ', 
'02UM4KZ', 
'02UN07Z', 
'02UN08Z', 
'02UN0JZ', 
'02UN0KZ', 
'02UN37Z', 
'02UN38Z', 
'02UN3JZ', 
'02UN3KZ', 
'02UN47Z', 
'02UN48Z', 
'02UN4JZ', 
'02UN4KZ', 
'02VA0CZ', 
'02VA0ZZ', 
'02VA3CZ', 
'02VA3ZZ', 
'02VA4CZ', 
'02VA4ZZ', 
'02VR0CT', 
'02VR0DT', 
'02VR0ZT', 
'02VR3CT', 
'02VR3DT', 
'02VR3ZT', 
'02VR4CT', 
'02VR4DT', 
'02VR4ZT', 
'02W50JZ', 
'02W54JZ', 
'02WA02Z', 
'02WA03Z', 
'02WA07Z', 
'02WA08Z', 
'02WA0CZ', 
'02WA0DZ', 
'02WA0JZ', 
'02WA0KZ', 
'02WA0QZ', 
'02WA0RS', 
'02WA0RZ', 
'02WA0YZ', 
'02WA37Z', 
'02WA38Z', 
'02WA3CZ', 
'02WA3JZ', 
'02WA3KZ', 
'02WA3QZ', 
'02WA3RS', 
'02WA3RZ', 
'02WA42Z', 
'02WA43Z', 
'02WA47Z', 
'02WA48Z', 
'02WA4CZ', 
'02WA4DZ', 
'02WA4JZ', 
'02WA4KZ', 
'02WA4QZ', 
'02WA4RS', 
'02WA4RZ', 
'02WM0JZ', 
'02WM4JZ', 
'0W3D0ZZ', 
'0W3D3ZZ', 
'0W3D4ZZ', 
'0W9D00Z', 
'0W9D0ZZ', 
'0WCD0ZZ', 
'0WCD3ZZ', 
'0WCD4ZZ', 
'0WFD0ZZ', 
'0WFD3ZZ', 
'0WFD4ZZ', 
'0WHD03Z', 
'0WHD0YZ', 
'0WHD33Z', 
'0WHD3YZ', 
'0WHD43Z', 
'0WHD4YZ', 
'0WPD00Z', 
'0WPD01Z', 
'0WPD03Z', 
'0WPD0YZ', 
'0WPD30Z', 
'0WPD31Z', 
'0WPD33Z', 
'0WPD3YZ', 
'0WPD40Z', 
'0WPD41Z', 
'0WPD43Z', 
'0WPD4YZ', 
'0WWD00Z', 
'0WWD03Z', 
'0WWD0YZ', 
'0WWD30Z', 
'0WWD33Z', 
'0WWD3YZ', 
'0WWD40Z', 
'0WWD43Z', 
'0WWD4YZ', 
'X2C0361', 
'X2C1361', 
'X2C2361', 
'X2C3361';

********************************************************************************************************************************;
