*aha data;


proc import out = work.aha datafile = "D:\ProjectOutput\nyshf-smm-output\SMM AHA 2013_2016.xlsx" 
	dbms=xlsx replace;
	sheet = "AHA2013_2016";
	getnames = yes;
run;

proc print data = work.aha (obs=1); run;

proc print data = work.aha(keep=aha_id--npi_merge9 perinatal_level_nys obs=1); run;

proc freq data = work.aha(keep=aha_id--npi_merge9 perinatal_level_nys);
table perinatal_level_nys;
run;

proc freq data = work.aha(keep=aha_id--npi_merge9 perinatal_level_nys where=(NPI_MERGE1 ne .));
table perinatal_level_nys;
run;

*see rows 108 to 118 in smm_flags for source of this view file;

proc contents data =  mothers2.births12to17; run;
proc contents data =  mothers2.births12; run;
proc contents data = yr12.ip_drg; run;

proc contents data = yr12.ip_drg; run;

proc freq data = mothers2.births;
table birth_stay_st / nocol norow nopct missing; 
format birth_stay_st year.;
run;

*note this is pulling from 13 14 old folders that did not have the error;

	data mothers2.ip_drg12to17v(where=( '01jan2012'd le srv_dt_adj le '31dec2017'd and 
  aprdrg in ('540','541','542','560'))) / view = mothers2.ip_drg12to17v;
	set
	yr12.ip_drg
	yr13.ip_drg
	yr14.ip_drg
	yr15.ip_drg
	yr16.ip_drg
	yr17.ip_drg;
	run;

proc freq data = mothers2.ip_drg12to17v;
table srv_dt_adj / nocol norow nopct missing; 
format srv_dt_adj year.;
run;


proc sql;
create view mothers2.births_allnpis as
select distinct member_id, bill_npi, max(srv_end_dt_adj) as birth_stay_end format = mmddyy., srv_dt_adj as birth_stay_st format = mmddyy. from 
mothers2.ip_drg12to17v(where=( '01jan2012'd le srv_dt_adj le '31dec2017'd and 
  aprdrg in ('540','541','542','560')))
group by member_id, birth_stay_st;
quit;

proc contents data =  work.aha(keep=aha_id--npi_merge9 perinatal_level_nys where=(NPI_MERGE1 ne .)) ; run;
proc sql;
create table work.ahajoin1
as select a.*,b.*
from  mothers2.births_allnpis a left join work.aha(keep=aha_id--npi_merge9 perinatal_level_nys where=(NPI_MERGE1 ne .)) b
on input(a.bill_npi,BEST.) eq b.npi_merge1;
quit;

proc sql;
create table work.ahajoin2
as select a.,b.*
from  mothers2.births_allnpis a left join work.aha(keep=aha_id--npi_merge9 perinatal_level_nys where=(NPI_MERGE1 ne .)) b
on input(a.bill_npi,BEST.) eq b.npi_merge1;
quit;



proc sort data = work.ahajoin1 out = work.ahajoin2; by member_id birth_stay_st descending npi_merge1 npi_merge2; run;
proc sort nodupkey data = work.ahajoin2 out = work.ahajoin3 dupout=dupes2; by member_id birth_stay_st; run;

proc freq data = work.ahajoin3;
table npi_merge1;
run;


proc freq data = work.ahajoin3(where = (bill_npi ne ""));
table npi_merge1;
run;


*######################################################################################################;




proc import out = work.aha datafile = "D:\ProjectOutput\nyshf-smm-output\SMM AHA 2013_2016.xlsx" 
	dbms=xlsx replace;
	sheet = "AHA2013_2016";
	getnames = yes;
run;

proc import out = work.xw datafile = "D:\ProjectOutput\nyshf-smm-output\Copy of Delivery QC_with manual matching01222020_csr6Feb2020.xlsx" 
	dbms=xlsx replace;
	sheet = "xw";
	getnames = yes;
run;

proc sql;
create table work.qctm2aha
as select a.*, b.*
from work.xw a left join work.aha b
on a.aha_id eq b.aha_id;
quit; 

*#### get births with NPIs from data ####;
proc sql;
create table mothers2.ips12t17wAHAid
as select a.*, b.*
from mothers2.ip_drg12to17v a left join work.xw b
on input(a.bill_npi,BEST.)eq b.npi_num;
quit;


proc sql;
create table mothers2.ip12t17wAHAid_bl
as select member_id
       ,srv_dt_adj
       ,max(bill_npi) as a_npi
       ,count(distinct bill_npi) as npi_count
from mothers2.ips12t17wAHAid
 group by mbr_id,srv_dt_adj;
quit;

proc freq data = mothers2.ip12t17wAHAid_bl;
table npi_count;
run;


data tm.anymissingnpis;
set tm.idid2;
if a_npi ne 0 then delete;
run;

*because the Ips the older 3m CSR version only takes good admit = Y,
join with member id and date to TM 3m deliveries version instead. This
other on is missing a 38% of NPIs.;

*Tm idid or deliveries_12_17miss;

*starting with the simplified v wiht any npi;
proc sql;
create table mothers2.bs12t17wTMnpis
as select a.*, b.*
from mothers2.births12to17 a left join tm.idid2 b
on a.member_id eq b.mbr_id and a.srv_dt_adj eq b.srv_dt_adj;
quit;


proc import out = work.ahaj datafile = "D:\Project Code\smm-Code\npi aha join\AHA_NPI_joined_csr7Feb2020.xlsx" 
	dbms=xlsx replace;
	sheet = "Raw";
	getnames = yes;
run;

proc print data=ahaj(obs=4);run;
proc print data=mothers2.bs12t17wTMnpis (obs=4); run;
title ;

proc contents data=ahaj; run;
proc contents data=mothers2.bs12t17wTMnpis; run;
data ahaj;
set ahaj;
format npi $10.;
npi=put(bill_npi, $10.);
run;

proc sql;
create table mothers2.bs12t17wTMnpiswAHA
as select a.*, b.*
from mothers2.bs12t17wTMnpis a left join ahaj b
on a.a_npi eq b.npi;
quit;
*716342 -- 716342;
proc print data=mothers2.bs12t17wTMnpiswAHA (obs=4); run;

proc freq data=mothers2.bs12t17wTMnpiswAHA;
run;

*check that really only .001 have no NPI still;

data notmissingnpis;
set mothers2.bs12t17wTMnpiswAHA;
if a_npi eq 0 | a_npi = "" then delete;
run;
*  570698
 / 716342 = 80%;




*now try all npis picked from for TM's data quality check;
