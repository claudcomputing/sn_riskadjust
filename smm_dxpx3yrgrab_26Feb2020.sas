

*NOTE - if you already have the risk category lists, you might
want to do this in a different order (e.g., pull the claims for 
all mothers and label the claims using the risk category cross
walks first, then create indicators for birth, year by year of 
births.;

*Note: now using new 2013 flags and births and 
old 2014 and all other years flags and births.
Modify risk categories that touch 2013 in past
22 months  - re run for 3 years later if needed. 
rerunning for 2015, 2104 and 2013 because these
use the px and dx from 2013 for touching 22 months;

libname mothers "D:\ProjectData\Intermediate\smm-data";
libname m3 "D:\ProjectData\Intermediate\smm-data";

libname mothers1 "D:\ProjectData\Intermediate\smm-data\before 21Jan2019";
libname mothers2 "D:\ProjectData\Intermediate\smm-data\after21Jan2019";

libname claims06 "D:\Medicaid Data\2006";
libname claims07 "D:\Medicaid Data\2007";
libname claims08 "D:\Medicaid Data\2008";
libname claims09 "D:\Medicaid Data\2009";
libname claims10 "D:\Medicaid Data\2010";
libname claims11 "D:\Medicaid Data\2011";
libname claims12 "D:\Medicaid Data\2012";
libname claims13 "D:\Medicaid Data\2013 new";
libname claims14 "D:\Medicaid Data\2014";
libname claims15 "D:\Medicaid Data\2015";
libname claims16 "D:\Medicaid Data\2016";
libname claims17 "D:\Medicaid Data\2017";
libname claims18 "D:\Medicaid Data\2018";

*2017-2016 is getting the following error:  File CLAIMS13.DX_FINAL_CLEANED.DATA is damaged. I/O processing did not complete.
Trying to split this up;

data mothers.dxlookback17b1v/view = mothers.dxlookback17b1v;
set claims18.dx_final_cleaned
	claims17.dx_final_cleaned;
run;

data mothers.dxlookback17b2v/view = mothers.dxlookback17b2v;
set claims16.dx_final_cleaned
	claims15.dx_final_cleaned
	claims14.dx_final_cleaned;
run;



data mothers.dxlookback16b1v/view = mothers.dxlookback16b1v;
set 
	claims17.dx_final_cleaned
	claims16.dx_final_cleaned;
run;


data mothers.dxlookback16b2v/view = mothers.dxlookback16b2v;
set 
	claims15.dx_final_cleaned
	claims14.dx_final_cleaned
	claims13.dx_final_cleaned;
run;



data mothers.dxlookback15bv/view = mothers.dxlookback15bv;
set 
	claims16.dx_final_cleaned
	claims15.dx_final_cleaned
	claims14.dx_final_cleaned
	claims13.dx_final_cleaned
	claims12.dx_final_cleaned
	;
run;

data mothers.dxlookback14bv/view = mothers.dxlookback14bv;
set 
	claims15.dx_final_cleaned
	claims14.dx_final_cleaned
	claims13.dx_final_cleaned
	claims12.dx_final_cleaned
	claims11.dx_final_cleaned
	;
run;

data mothers.dxlookback13bv/view = mothers.dxlookback13bv;
set 
	claims14.dx_final_cleaned
	claims13.dx_final_cleaned
	claims12.dx_final_cleaned
	claims11.dx_final_cleaned
	claims10.dx_final_cleaned
	;
run;
data mothers.dxlookback12bv/view = mothers.dxlookback12bv;
set 
	claims13.dx_final_cleaned
	claims12.dx_final_cleaned
	claims11.dx_final_cleaned
	claims10.dx_final_cleaned
	claims09.dx_final_cleaned
	;
run;

data mothers.dxlookback11bv/view = mothers.dxlookback11bv;
set 
	claims12.dx_final_cleaned
	claims11.dx_final_cleaned
	claims10.dx_final_cleaned
	claims09.dx_final_cleaned
	claims08.dx_final_cleaned
	;
run;


data mothers.dxlookback10bv/view = mothers.dxlookback10bv;
set 
	claims11.dx_final_cleaned
	claims10.dx_final_cleaned
	claims09.dx_final_cleaned
	claims08.dx_final_cleaned
	claims07.dx_final_cleaned
	;
run;
data mothers.dxlookback09bv/view = mothers.dxlookback09bv;
set 
	claims09.dx_final_cleaned
	claims08.dx_final_cleaned
	claims07.dx_final_cleaned
	claims06.dx_final_cleaned;
run;

data mothers.dxlookback08bv/view = mothers.dxlookback08bv;
set 
	claims09.dx_final_cleaned
	claims08.dx_final_cleaned
	claims07.dx_final_cleaned
	claims06.dx_final_cleaned;
run;

data mothers.dxlookback07bv/view = mothers.dxlookback07bv;
set 
	claims08.dx_final_cleaned
	claims07.dx_final_cleaned
	claims06.dx_final_cleaned;
run;

data mothers.dxlookback06bv/view = mothers.dxlookback06bv;
set 
	claims07.dx_final_cleaned
	claims06.dx_final_cleaned;
run;


%macro dxyear3(yr=06,folder=); *pick up dx and pxs in the past 3 years and 0 year ahead;
	proc sql;
			create table mothers.b_3dx&yr. as 
				select distinct a.*
					, a.birth_stay_st
					, a.birth_stay_end
					, b.srv_dt_adj as event_dt
					, b.dx_cd
					, b.cos_final
					, b.ccs_cat
				from mothers&folder..births&yr.  a 
				left join mothers.dxlookback&yr.bv
	(keep = member_id dx_cd srv_dt_adj srv_end_dt_adj cos_final ccs_cat) b
					on a.member_id= b.member_id
					and a.birth_stay_st -1095 < b.srv_dt_adj <a.birth_stay_st;
				quit;
%mend dxyear3;

/*	%dxyear3(yr=06);*/
/*	%dxyear3(yr=07);*/
/*	%dxyear3(yr=08);*/
/*	%dxyear3(yr=09);*/
/*	%dxyear3(yr=10);*/
/*	%dxyear3(yr=11);*/

	*%dxyear3(yr=12);
	%dxyear3(yr=13,folder=2);
	%dxyear3(yr=14,folder=1);
	%dxyear3(yr=15,folder=1);


	*dxlookback17b1v;

%macro dxyear3_split(yr=16); *pick up dx and pxs in the past 3 years and 1 year ahead;
	proc sql;
			create table mothers.b_3dx&yr.a as 
				select distinct a.*
					, a.birth_stay_st
					, a.birth_stay_end
					, b.srv_dt_adj as event_dt
					, b.dx_cd
					, b.cos_final
					, b.ccs_cat
				from mothers.births&yr.  a 
				left join mothers.dxlookback&yr.b1v
	(keep = member_id dx_cd srv_dt_adj srv_end_dt_adj cos_final ccs_cat) b
					on a.member_id= b.member_id
					and a.birth_stay_st -1095 < b.srv_dt_adj <a.birth_stay_st;
				quit;
				%mend;
%macro dxyear3_split(yr=16, folder=); 
	proc sql;
			create table mothers.b_3dx&yr.b as 
				select distinct a.*
					, a.birth_stay_st
					, a.birth_stay_end
					, b.srv_dt_adj as event_dt
					, b.dx_cd
					, b.cos_final
					, b.ccs_cat
				from mothers&folder..births&yr.  a 
				left join mothers.dxlookback&yr.b2v
	(keep = member_id dx_cd srv_dt_adj srv_end_dt_adj cos_final ccs_cat) b
					on a.member_id= b.member_id
					and a.birth_stay_st -1095 < b.srv_dt_adj <a.birth_stay_st;
				quit;
%mend dxyear3_split;	
%dxyear3_split(yr=16);	

data mothers.b_3dx16/view =mothers.b_3dx16;
	set mothers1.b_3dx16a
	mothers3.b_3dx16b;
	
if dx_cd = "" then dx_cd = "NoDXclaims";
	run;


	
	*%dxyear3_split(yr=17);

*################################## setting NO dx claims for mothers with no dx files ###############################;

%macro set2nothing(yr=17);
data mothers.b_3dx&yr.;
set mothers.b_3dx&yr.;
if dx_cd = "" then dx_cd = "NoDXclaims";
run;
%mend set2nothing;
/**/
/*%set2nothing(yr=06);*/
/*%set2nothing(yr=07);*/
/*%set2nothing(yr=08);*/
/*%set2nothing(yr=09);*/
/*%set2nothing(yr=10);*/
/*%set2nothing(yr=11);*/
/*%set2nothing(yr=12);*/
%set2nothing(yr=13);
%set2nothing(yr=14);
%set2nothing(yr=15);

/*%set2nothing2(yr=16);*/
/*%set2nothing2(yr=17);*/






	
