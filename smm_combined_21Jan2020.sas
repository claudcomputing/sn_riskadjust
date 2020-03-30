*Now using TM 3m delivery file 21Jan2019;
libname tm "D:\ProjectData\Intermediate\smm-data\3m-smm-data\smm transferred 21Jan2019";
libname old "D:\ProjectData\Intermediate\smm-data\before 21Jan2019";
libname m2 "D:\ProjectData\Intermediate\smm-data\after21Jan2019";

proc sql;
 create table tm.idid as
 select mbr_id
       ,srv_dt_adj
       ,count(distinct bill_npi) as npi_num
       ,count(distinct bill_prov_id) as provid_num
 from tm.deliveries_12_17
 group by mbr_id,srv_dt_adj;
quit;
data tm.deliveries_12_17miss/ view = tm.deliveries_12_17miss;
set tm.deliveries_12_17;
if bill_npi = . then bill_npi = 0;
run;

proc sql;
 create table tm.idid2 as
 select mbr_id
       ,srv_dt_adj
       ,max(bill_npi) as a_npi
       ,count(distinct bill_npi) as npi_num
 from tm.deliveries_12_17miss
 group by mbr_id,srv_dt_adj;
quit;

proc freq data = tm.idid2;
table npi_num;
run;
data tm.anymissingnpis;
set tm.idid2;
if a_npi ne 0 then delete;
run;
* 766/603038 = .001;

proc freq data = tm.idid;
table npi_num;
run;
proc sort data=tm.idid;
 by mbr_id srv_dt_adj;
run;


data m2.births12to17/view = m2.births12to17;
set 
old.births12
old.births13
old.births14
old.births15
old.births16
old.births17;

birth_datemo = intck('month','31dec1999'd,birth_stay_st);
srv_dt_adj = birth_stay_st;
length mrn $ 21;
 mrn = cats(member_id,put(srv_dt_adj,mmddyy10.));
run;

proc sql; 
select count(*) as numrows_old from m2.births12to17 ; *716,342;
proc sql; 
select count(*) as numrows_new from tm.idid(where = (year(srv_dt_adj)<2018)); *603,033;
quit; 
data tm.idid;
set tm.idid;
 length mrn $ 21;
 mrn = cats(mbr_id,put(srv_dt_adj,mmddyy10.));
 run;
 
proc sort data=tm.idid;
 by mrn;
run;
proc sort data = m2.births12to17 out = m2.birts12to17sort;
by mrn;
run;

data m2.overlap;
merge m2.birts12to17sort(in=C) tm.idid (in=T);
by mrn;
Cin=C; Tin=T;
run;

proc freq data = m2.overlap;
table Cin*Tin / missing; run;


proc freq data = m2.overlap;
table Cin*Tin*srv_dt_adj / nocol norow nopct missing; 
format srv_dt_adj year.;
run;



proc freq data = tm.idid;
table srv_dt_adj / nocol norow nopct missing; 
format srv_dt_adj year.;
run;

proc freq data = tm.idid;
table srv_dt_adj / nocol norow nopct missing; 
format srv_dt_adj monyy.;
run;
