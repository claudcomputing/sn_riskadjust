options xsync noxwait ;

*SMM 3M deliveries;
*births - year by year and total
*providers - bill npi bill prov
*providres to birth xwalk
*%macro 3m;

*NYU HEAL SMM Analyses for NYSHF;
*csr315@nyu.edu;
%let path_directory = D:\Medicaid Data\;
%let project_directory = D:\ProjectData\Intermediate\smm-data\3m-smm-data\;
%let path_eligibility = D:\Medicaid Data\eligibility\;
%let path_project = D:\ProjectData\Intermediate\smm-data;
%let eligibility_file = together_all_ev_18_final;

libname mothers "D:\ProjectData\Intermediate\smm-data";
%let filename=3m;
%let proghom = d:\3m\Program\cgs\;

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

libname for 'D:\formats'; proc sort data=for.formats_final_testing4; by fmtname; run; proc format cntlin=for.formats_final_testing4; run;

/*-----------------------------------------------------------------------------------------------------*
* prep M data -----------------------------------------------------------------------------------------*
*------------------------------------------------------------------------------------------------------*/

%macro ThreeMrun(yy=);
libname sample "&project_directory.&yy.";

proc sort data=claims&yy..dx_final_cleaned(where=(cos_final in ('01','02','04')))
           out=sample.ip_dxs(keep=member_id srv_dt_adj srv_end_dt_adj prim_dx_ind dx_cd);
 by member_id srv_dt_adj descending prim_dx_ind dx_cd;
run;

proc sort equals nodupkey data=sample.ip_dxs;
 by member_id srv_dt_adj descending prim_dx_ind dx_cd;
run;

proc transpose data=sample.ip_dxs
               out=sample.dxs_wide
               prefix=dx;
 by member_id srv_dt_adj;
 var dx_cd;
run;

proc sort data=claims&yy..px_final_cleaned_020617dd(where=(cos_final in ('01','02','04')))
           out=sample.ip_pxs(keep=member_id srv_dt_adj srv_end_dt_adj princ_proc_ind proc_cd);
 by member_id srv_dt_adj descending princ_proc_ind proc_cd;
run;

proc sort equals nodupkey data=sample.ip_pxs;
 by member_id srv_dt_adj descending princ_proc_ind proc_cd;
run;

proc transpose data=sample.ip_pxs
               out=sample.pxs_wide
               prefix=px;
 by member_id srv_dt_adj;
 var proc_cd;
run;

proc sort data=claims&yy..allhospsb_final_cleaned_110116(where=(goodadm eq 'Y'))
           out=sample.ip_claims_goodadm;
 by member_id srv_dt_adj;
run;
%mend;

%macro ThreeMrun_2014(yy=14);
libname sample "&project_directory.&yy.";

proc sort data=claims&yy..px_final_cleaned_020617dd(where=(cos_final in ('01','02','04')))
           out=sample.ip_pxs(keep=member_id srv_dt_adj srv_end_dt_adj /*princ_proc_ind*/ proc_cd);
 by member_id srv_dt_adj descending /*princ_proc_ind*/ proc_cd;
run;

proc sort equals nodupkey data=sample.ip_pxs;
 by member_id srv_dt_adj descending /*princ_proc_ind*/ proc_cd;
run;

proc transpose data=sample.ip_pxs
               out=sample.pxs_wide
               prefix=px;
 by member_id srv_dt_adj;
 var proc_cd;
run;
%mend;

/*-----------------------------------------------------------------------------------------------------*
* 3m input --------------------------------------------------------------------------------------------*
*------------------------------------------------------------------------------------------------------*/


%macro make_3m_input(icd_version,yy); * takes icd9 or icd10;

libname sample "&project_directory.&yy.";
%let dir=d:\ProjectData\Intermediate\smm-data\3m-smm-data\&yy.\;
x erase "&dir.&filename._icd9.in";
x erase "&dir.&filename._icd10.in";


%global &icd_version;

%if &icd_version eq icd9 %then %do;
 %let operator=lt;
 %let icd_ver_cd_num=9;
 %let map_date=10012014;
%end;
%else %do;
 %let operator=ge;
 %let icd_ver_cd_num=0;
 %let map_date=10011900;
%end;

proc sql;
 select count(*) into :claim_count
 from sample.ip_claims_goodadm
      (where=(srv_end_dt_adj &operator '01oct2015'd));
quit;

%let &icd_version=&claim_count;

%if &claim_count gt 20 %then %do;

data _null_;
 merge sample.ip_claims_goodadm
       (in=in1 where=(srv_end_dt_adj &operator '01oct2015'd))
       sample.pxs_wide(in=in2)
       sample.dxs_wide(in=in3);
 by member_id srv_dt_adj;
 if in1 and first.srv_dt_adj;
 mbr_birth_dt = '01jan1990'd;
 mbr_sex_cd = 'F';
 icd_ver_cd_num=&icd_ver_cd_num;
 file "&dir.&filename._&icd_version..in" lrecl=12400 dropover pad;
  put 
   /*@  70 bill_prov_id   $8. -l  medical record number */
   @  94 member_id      $11. -l /* patient id */
   @ 119 mbr_sex_cd     $1.
   @ 120 mbr_birth_dt   mmddyyn8.
   @ 133 srv_dt_adj     mmddyyn8. /* admit date */
   @ 141 srv_end_dt_adj mmddyyn8.
   @ 176 pat_status_cd  $10. -l
   @ 599 icd_ver_cd_num 1.
   @ 600 admit_dx_cd    $8. -l
   @ 608 dx1            $8. -l
   @ 690 (dx2 - dx50)   ($8. -l)
   @ 1082 (px1 - px50)  ($7. -l);
run;

* 3M notes: use historical mapping, which works with icd9 and 10. Do not need HAC;
* -map_date should be October 1st of the prior year for icd9 claims,
* and 10011900 (automatic) for icd10 claims;
* the most recent grouper that will work with icd9 claims is 07320;
* You have to write icd_ver_cd to the input file,
* otherwise 3m will assume icd9;
* Write -grouper_icd_version 9 for icd9 records, dont use it for icd10 records;
* For ICD10 records, I can use any grouper;
data _null_;
 file "3m_&icd_version..bat" lrecl = 32767;
 put "&proghom.cgs_console.exe "@;
 put "-input &dir.&filename._&icd_version..in "@;
 put "-input_template  &proghom.templates\all_in.dic "@;
 put "-upload &dir.&filename._&icd_version..out "@;
 put "-upload_template &proghom.templates\all_out_v2.dic "@;
 put "-report &dir.&filename._&icd_version._report.html "@;
 put "-error_log &dir.&filename._&icd_version._ErrorLog.html "@;
 put "-edit_log &dir.&filename._&icd_version._EditLog.html "@;
 put "-schedule off "@;
 put "-reorder off "@;
 put "-grouper 07320 "@;
 * the following used to say 9 for both icd9 and icd10, i do not think it matters;
 put "-grouper_icd_version &icd_ver_cd_num "@;
 put "-interpretation_poa_indicators 1 "@;
 put "-map_type 1 "@; * historical, which it should always be;
 put "-map_date &map_date "@;
 put "-bwt_option 6"; * i think this will look for appropriate v codes;
run;

x 3m_&icd_version..bat;

%end;

%mend make_3m_input;

/*-----------------------------------------------------------------------------------------------------*
* set and output files ------------------------------------------------------------------------------*
*------------------------------------------------------------------------------------------------------*/

%macro set_input_files(yy);
libname sample "&project_directory.&yy.";
%let dir=d:\ProjectData\Intermediate\smm-data\3m-smm-data\&&yy.\;
filename out3m (%if &icd9 gt 20 %then "&dir.&filename._icd9.out";
                %if &icd10 gt 20 %then "&dir.&filename._icd10.out";);

%mend set_input_files;

%macro set_input_files_icd(yy=,icd=);
libname sample "&project_directory.&yy.";
%let dir=d:\ProjectData\Intermediate\smm-data\3m-smm-data\&&yy.\;
filename out3m (/*%if &icd=9 %then "&dir.&filename._icd9.out";*/
                %if &icd=10 %then "&dir.&filename._icd10.out";);

%mend set_input_files_icd;

%macro output3m(yy=);
libname sample "&project_directory.&yy.";
%let dir=d:\ProjectData\Intermediate\smm-data\3m-smm-data\&yy.\;
data sample.from3m;
 infile out3m;
 input 
  /*@1  bill_prov_id    $8.*/
  @37 aprdrg          $3.
  @64 aprdrg_severity $1.
  @69 srv_dt_adj      anydtdte8.
  @77 member_id          $11.;
run;

proc sort data=sample.from3m;
 by member_id srv_dt_adj;
run;

data sample.ip_drg;
 merge sample.ip_claims_goodadm(in=in1)
       sample.from3m;
 by member_id  srv_dt_adj;
 if in1 and first.srv_dt_adj;
run;

proc format;
 value $delivery
  '540','541','542','560' = 'Delivery APR-DRG'
  other = 'Other/missing APR-DRG';
run;

proc freq data=sample.ip_drg;
 title "Deliveries by month for 20&yy.";
 where "01jan20&yy."d le srv_end_dt_adj le "31dec20&yy."d and 
  aprdrg in ('540','541','542','560');
 tables srv_end_dt_adj  aprdrg/list missing;
 format aprdrg $delivery.
        srv_end_dt_adj monyy7.;
run;
ods pdf close;
%mend output3m;

/*-----------------------------------------------------------------------------------------------------*
* execute yearly ------------------------------------------------------------------------------*
*------------------------------------------------------------------------------------------------------*/

%ThreeMrun(yy=18);
%ThreeMrun(yy=17);
%ThreeMrun(yy=16);
%ThreeMrun(yy=15);
%ThreeMrun(yy=14);
%ThreeMrun_2014(yy=14); /*this version of the macro takes out a missing variable that we don't have on that year*/


%ThreeMrun(yy=12);
%ThreeMrun(yy=11);
%ThreeMrun(yy=10);
%ThreeMrun(yy=09);
%ThreeMrun(yy=08);
%ThreeMrun(yy=07);
%ThreeMrun(yy=06);


*These are run in order as a quick fix for
problem in which a 3m batch file
written by the 3m direct lines saves to the
drive where this program is, and the path 
dosen't read the right location if you do 
another year's input before completing
the set and output programs;

%make_3m_input(icd_version=icd10,yy=18)
%set_input_files_icd(yy=18,icd=10);
%output3m(yy=18);

%make_3m_input(icd_version=icd10,yy=17)
%set_input_files_icd(yy=17,icd=10);
%output3m(yy=17);
%make_3m_input(icd_version=icd10,yy=16)
%set_input_files_icd(yy=16,icd=10);
%output3m(yy=16);
%make_3m_input(icd_version=icd9,yy=15)
%make_3m_input(icd_version=icd10,yy=15)
%set_input_files(yy=15);
%output3m(yy=15);


%ThreeMrun(yy=14); 
%ThreeMrun(yy=13);

%make_3m_input(icd_version=icd9,yy=14)
%set_input_files_icd(yy=14,icd=09);
%output3m(yy=14);
%make_3m_input(icd_version=icd9,yy=13)
%set_input_files_icd(yy=13,icd=09);
%output3m(yy=13);


%make_3m_input(icd_version=icd9,yy=12)
%set_input_files_icd(yy=12,icd=09);
%output3m(yy=12);
%make_3m_input(icd_version=icd9,yy=11)
%set_input_files_icd(yy=11,icd=09);
%output3m(yy=11);
%make_3m_input(icd_version=icd9,yy=10)
%set_input_files_icd(yy=10,icd=09);
%output3m(yy=10);
%make_3m_input(icd_version=icd9,yy=09)
%set_input_files_icd(yy=09,icd=09);
%output3m(yy=09);
%make_3m_input(icd_version=icd9,yy=08)
%set_input_files_icd(yy=08,icd=09);
%output3m(yy=08);
%make_3m_input(icd_version=icd9,yy=07)
%set_input_files_icd(yy=07,icd=09);
%output3m(yy=07);
%make_3m_input(icd_version=icd9,yy=06)
%set_input_files_icd(yy=06,icd=09);
%output3m(yy=06);



*-----------------------------------------------------------------------------------------------------*
* stats all years ------------------------------------------------------------------------------------*
*-----------------------------------------------------------------------------------------------------;

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
*########################################################################################################
	NPI provider piece
*########################################################################################################;

proc sql;
create table mothers.ip_drg_prov_npis
as select distinct
bill_prov_id
,bill_npi
from mothers.ip_drg06to17v (where =('01jan2006'd le srv_end_dt_adj le '31dec2017'd and 
  aprdrg in ('540','541','542','560')));
quit;

proc sql;
create table mothers.ip_drg_prov_npis_xw
as select distinct
member_id
,srv_dt_adj
,bill_prov_id
,bill_npi
from mothers.ip_drg06to17v (where =('01jan2006'd le srv_end_dt_adj le '31dec2017'd and 
  aprdrg in ('540','541','542','560')));
quit;

data mothers.ip_drg_prov_npis_xw;
set mothers.ip_drg_prov_npis_xw;
pregnancy_id = cat(of member_Id, srv_dt_adj);
run;

data mothers.ip_drg_prov_npis_xw;
set mothers.ip_drg_prov_npis_xw (drop = birth_stay_st);
run;
*########################################################################################################
*########################################################################################################;
ods pdf file='CY2006-2017 Medicaid deliveries.pdf';

proc freq data=mothers.ip_drg06to17v;
 title 'Deliveries by month for 20&yy.';
 where '01jan2006'd le srv_end_dt_adj le '31dec2017'd and 
  aprdrg in ('540','541','542','560');
 tables srv_end_dt_adj*  aprdrg/list missing;
 format aprdrg $delivery.
        srv_end_dt_adj year.;
run;

ods pdf close;

proc sql;
select
	count(*)
	from mothers.ip_drg06to17v(where =('01jan2006'd le srv_end_dt_adj le '31dec2017'd and 
  aprdrg in ('540','541','542','560')));

select
	count(*)
from (select distinct member_id, srv_end_dt_adj from mothers.ip_drg06to17v(where=( '01jan2006'd le srv_end_dt_adj le '31dec2017'd and 
  aprdrg in ('540','541','542','560'))));
quit;

*1443807;
*1442143;

proc sql;
create view mothers.births as
select distinct member_id, max(srv_end_dt_adj) as birth_stay_end format = mmddyy., srv_dt_adj as birth_stay_st format = mmddyy. from 
mothers.ip_drg06to17v(where=( '01jan2006'd le srv_dt_adj le '31dec2017'd and 
  aprdrg in ('540','541','542','560')))
group by member_id, birth_stay_st;
quit;
*1442434;
proc sort nodupkey data = mothers.births out = births dupout=dupes; by member_id birth_stay_st; run;

*1442434; / no duplicates;

%macro split(yr=06);
data mothers.births&yr.;
set mothers.births(where=( "01jan20&yr."d le birth_stay_st le "31dec20&yr."d));
run;
%mend;
%split(yr=06);
%split(yr=07);
%split(yr=08);
%split(yr=09);
%split(yr=10);
%split(yr=11);
%split(yr=12);
%split(yr=13);
%split(yr=14);
%split(yr=15);
%split(yr=16);
%split(yr=17);
data mothers.births12to17/view = mothers.births12to17;
set 
mothers.births12
mothers.births13
mothers.births14
mothers.births15
mothers.births16
mothers.births17;

birth_datemo = intck('month','31dec1999'd,birth_stay_st);
run;

data mothers.births06to11/view = mothers.births06to11;
set 
mothers.births06
mothers.births07
mothers.births08
mothers.births09
mothers.births10
mothers.births11;

birth_datemo = intck('month','31dec1999'd,birth_stay_st);
run;

data mothers.births06to17/view = mothers.births06to17;
set 
mothers.births06
mothers.births07
mothers.births08
mothers.births09
mothers.births10
mothers.births11
mothers.births12
mothers.births13
mothers.births14
mothers.births15
mothers.births16
mothers.births17;

birth_datemo = intck('month','31dec1999'd,birth_stay_st);
run;

proc sql;
create table mothers.births12to17_count as
select distinct member_id,birth_stay_st
from  mothers.births12to17 
;
run;

*   716342;
proc sql;
create table mothers.births06to11_count as
select distinct member_id,birth_stay_st
from  mothers.births06to11
;
run;
* 726092;

proc freq data=mothers.births12to17;
 title 'Deliveries by year for 2012 to 2017';
 where '01jan2012'd le birth_stay_st lt '01jan2018'd;
 tables birth_stay_st/list missing;
        format birth_stay_st year.;
run;
proc freq data=mothers.births06to11;
 title 'Deliveries by year for 2006 to 2011';
 where '01jan2006'd le birth_stay_st lt '01jan2012'd;
 tables birth_stay_st/list missing;
        format birth_stay_st year.;
run;

proc freq data=mothers.births06to17;
 title 'Deliveries by year for 2006 to 2017';
 where '01jan2006'd le birth_stay_st lt '01jan2018'd;
 tables birth_stay_st/list missing;
        format birth_stay_st year.;
run;

*####################################################################################################################;
*####################################################################################################################;
*####################################################################################################################;

*Now using TM 3m delivery file 21Jan2019;
libname tm "D:\ProjectData\Intermediate\smm-data\3m-smm-data\smm transferred 21Jan2019";
libname old "D:\ProjectData\Intermediate\smm-data\before 21Jan2019";
*not using this after all -- see smm_combined_21January2020;


