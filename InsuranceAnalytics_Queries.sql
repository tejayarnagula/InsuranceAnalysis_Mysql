# create database insurance;
use insurance;
show tables;
										#-- ETL Part --#
 -- Fees --> 
#Extract csv file of fees
select * from fees;
describe fees;
alter table fees rename column income_due_date to idd;
alter table fees add column idate date default null;
alter table fees rename column `Account Executive` to Account_Executive;
set sql_safe_updates = 0;
update fees set idate = str_to_date(idd,'%m/%d/%Y');
alter table fees drop column idd;
alter table fees drop column client_name,drop column revenue_transaction_type;
select * from fees;

 -- Budget -->
 #Extract csv file of individual_budgets
alter table individual_budgets rename to budgets;
select * from budgets;
desc budgets;
delete from budgets where branch = '';
# remove spaces in column names by using back tick(`) symbole beside 1key
alter table budgets change `New Budget` new_budget text;
alter table budgets change `Cross sell bugdet` cross_sell_budget text;
alter table budgets change `Renewal Budget` renewal_budget text;
update budgets set new_budget = null where new_budget = '';
update budgets set cross_sell_budget = null where cross_sell_budget = '';
update budgets set renewal_budget = null where renewal_budget = '';
alter table budgets modify column new_budget double;
alter table budgets modify column cross_sell_budget double;
alter table budgets modify column renewal_budget double;
select * from budgets;

 -- Brokerage -->
#Extract csv file of Brokerage
 select * from brokerage limit 10;
 desc brokerage;
 update brokerage set Amount = null where Amount = '';
 alter table brokerage modify column Amount double;
 alter table brokerage add column income_date date default null;
 update brokerage set income_due_date = null where income_due_date = '';
 update brokerage set income_date = str_to_date(income_due_date,'%m/%d/%Y');
 alter table brokerage rename column income_date to idate;
 alter table brokerage drop column income_due_date;
 alter table brokerage drop column client_name, drop column policy_number,drop column policy_status, drop column policy_start_date,
 drop column policy_end_date, drop column product_group, drop column revenue_transaction_type, drop column renewal_status,
 drop column lapse_reason, drop column last_updated_date;
 
  -- Meeting -->
  #Extract csv file of Meeting
  select * from meeting;
  desc meeting;
  alter table meeting add column m_date date default null;
  update meeting set m_date = str_to_date(meeting_date,'%m/%d/%Y');
 alter table meeting drop column meeting_date;

 
   -- invoice -->
   #Extract csv file of invoice
   select * from invoice;
   desc invoice;
   
   -- Opportunity -->
   #Extract csv file of Opportunity
   select * from Opportunity;
   desc opportunity;
   
   										#-- KPI's Part --#
-- 1.No of invoice by Accnt executive
select * from invoice;
select `Account Executive`, count(`Account Executive`) as 'No.of Invoices' 
	from invoice 
    group by `Account Executive` 
    order by count(`Account Executive`) desc;
-----------------------

-- 2. Yearly Meeting Count
select * from meeting;
select year(m_date) as year,count(m_date) as 'Meeting_Count' 
	from meeting 
    group by year(m_date);
    
-----------------------
-- 3. Revenue By Income Class
 
 #Budget(Target)
select * from budgets;

with e as (select sum(new_budget) as 'New',sum(cross_sell_budget)as 'Cross Sell' ,sum(renewal_budget) as 'Renewal'
	from budgets) select * from e;
    
create table target(Income_class varchar(30), amount int);
insert into target values ('Cross_sell', (select sum(cross_sell_budget) from budgets));
insert into target values ('New', (select sum(new_budget) from budgets));
insert into target values ('Renewal', (select sum(renewal_budget) from budgets));
alter table target rename column amount to Target;

#Target
select * from target;

#Invoice
select income_class, sum(amount) as Invoice from invoice group by income_class;

#Achive(Brokerage+fees)
with A as (select * from brokerage union all select * from fees)
select income_class, sum(amount) as Achive from A group by income_class;


## Integrating the Target,Achive,Invoice values into single table
create table Revenue_by_Class( Income_class varchar(30), Target double, Achieve double, Invoice double);
alter table revenue_by_class rename column achive to achieve;
#queries to insert records into integrated table
select target from target where income_class = 'New';
select target from target where income_class = 'Cross Sell';
select target from target where income_class = 'Invoice';
with z as (select income_class, sum(amount) as Invoice from invoice group by income_class) select Invoice from z where income_class = 'New';
with z as (select income_class, sum(amount) as Invoice from invoice group by income_class) select Invoice from z where income_class = 'Cross Sell';
with z as (select income_class, sum(amount) as Invoice from invoice group by income_class) select Invoice from z where income_class = 'Invoice';
with f as (with A as (select * from brokerage union all select * from fees)
select income_class, sum(amount) as Achive from A group by income_class) select
achive from f where income_class = 'New';
with f as (with A as (select * from brokerage union all select * from fees)
select income_class, sum(amount) as Achive from A group by income_class) select
achive from f where income_class = 'Cross Sell';
with f as (with A as (select * from brokerage union all select * from fees)
select income_class, sum(amount) as Achive from A group by income_class) select
achive from f where income_class = 'Invoice';

#inserting those records into table corresponding to income class and type of revenue
insert into Revenue_by_Class values
('Cross_sell',
	(select target from target where income_class = 'Cross_sell'),
    (with f as (with A as (select * from brokerage union all select * from fees)
select income_class, sum(amount) as Achive from A group by income_class) select
achive from f where income_class = 'Cross Sell'),
(with z as (select income_class, sum(amount) as Invoice from invoice group by income_class) select Invoice from z where income_class = 'Cross Sell')
);

insert into Revenue_by_Class values
('New',
	(select target from target where income_class = 'New'),
    (with f as (with A as (select * from brokerage union all select * from fees)
select income_class, sum(amount) as Achive from A group by income_class) select
achive from f where income_class = 'New'),
(with z as (select income_class, sum(amount) as Invoice from invoice group by income_class) select Invoice from z where income_class = 'New')
);

insert into Revenue_by_Class values
('Renewal',
	(select target from target where income_class = 'Renewal'),
    (with f as (with A as (select * from brokerage union all select * from fees)
select income_class, sum(amount) as Achive from A group by income_class) select
achive from f where income_class = 'Renewal'),
(with z as (select income_class, sum(amount) as Invoice from invoice group by income_class) select Invoice from z where income_class = 'Renewal')
);

select * from Revenue_by_Class;
-----------------------
    
-- 4. Revenue by stage
select * from opportunity;
select stage, sum(revenue_amount) as revenue from opportunity group by stage;
-----------------------

-- 5. No.of Meetings by Accnt executive
select * from meeting;
select `Account Executive`, count(`Account Executive`) as 'No.of_Meetings' 
	from meeting 
    group by `Account Executive`
    order by count(`Account Executive`) desc;
-----------------------
    
-- 6. Top Open Opportunity
select * from opportunity;
select opportunity_name, sum(revenue_amount) as 'Top_Opportunity' 
from opportunity 
where stage = 'Qualify Opportunity' or stage = 'Propose Solution' 
group by opportunity_name 
order by sum(revenue_amount) desc limit 5;

-----------------------

-- 7. Percentage of Achievement (Achive/Target)
select Income_class, achieve/Target as '%_of_Achivement' from revenue_by_class;

-----------------------

-- 8. No.of Total & Open Opportunities
select count(opportunity_id) as 'Total Opportunities', 
(select count(stage) from opportunity 
where stage = 'Qualify Opportunity' or stage = 'Propose Solution') 
as 'Total Open Opportunities' from opportunity;
-----------------------
    
-- 9. No.of Opportunities by product
select distinct product_group,count(product_group) as 'No.of_Opportunities' 
from opportunity group by product_group order by count(product_group)desc;
-----------------------

-- 10. Percentage of Invoice Achievement (Achive/Target)
select Income_class, Invoice/Target as '%_of_InvoiceAchivement' from revenue_by_class;