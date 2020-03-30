*Note: now using new 2013 flags and births and 
old 2014 and all other years flags and births.
Modify risk categories that touch 2013 in past
10 months only - if ever need to go back 3 years
then do so;

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


data mothers.dxlookback14bv/view = mothers.dxlookback14bv;
set 
	claims14.dx_final_cleaned
	claims13.dx_final_cleaned	;
run;

data mothers.dxlookback13bv/view = mothers.dxlookback13bv;
set 

	claims13.dx_final_cleaned
	claims12.dx_final_cleaned;
run;

data mothers.pxlookback14bv/view = mothers.pxlookback14bv;
set 
	claims14.px_final_cleaned_020617dd
	claims13.px_final_cleaned_020617dd	;
run;

data mothers.pxlookback13bv/view = mothers.pxlookback13bv;
set 

	claims13.px_final_cleaned_020617dd
	claims12.px_final_cleaned_020617dd;
run;

%macro dxyear3(yr=, folder=);
	proc sql;
			create table mothers.b_3dx&yr. as 
				select distinct a.*
					, a.birth_stay_st
					, a.birth_stay_end
					, b.srv_dt_adj as event_dt
					, b.dx_cd
					, b.cos_final
				from mothers&folder..births&yr.  a 
				left join mothers.dxlookback&yr.bv
	(keep = member_id dx_cd srv_dt_adj srv_end_dt_adj cos_final) b
					on a.member_id= b.member_id
					and a.birth_stay_st -365 < b.srv_dt_adj <a.birth_stay_st;
				quit;
%mend dxyear3;
%macro pxyear3(yr=06, folder=);
	proc sql;
			create table mothers.b_3px&yr. as 
				select distinct a.*
					, a.birth_stay_st
					, a.birth_stay_end
					, c.srv_dt_adj as event_dt
					, c.proc_cd
					, c.cos_final
				from mothers&folder..births&yr.  a 
				left join mothers.pxlookback&yr.bv
	(keep = member_id proc_cd srv_dt_adj srv_end_dt_adj cos_final) c
					on a.member_id= c.member_id
					and a.birth_stay_st  -365 < c.srv_dt_adj <a.birth_stay_st;
				quit;
%mend pxyear3;

%dxyear3(yr=14,folder=1);
%dxyear3(yr=13,folder=2);

%pxyear3(yr=14,folder=1);
%pxyear3(yr=13,folder=2);


%macro set2nothing(yr=17);
data mothers.b_3dx&yr.;
set mothers.b_3dx&yr.;
if dx_cd = "" then dx_cd = "NoDXclaims";
run;
%mend set2nothing;

%set2nothing(yr=13);
%set2nothing(yr=14);

