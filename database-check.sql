begin;
insert into auth.users(id,email) values ('00000000-0000-4000-8000-000000000001','billing-check-1@example.invalid'),('00000000-0000-4000-8000-000000000002','billing-check-2@example.invalid');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
insert into public.billing_customers(id,name) values ('00000000-0000-4000-8000-000000000003','Verification customer');
insert into public.billing_products(id,name,price) values ('00000000-0000-4000-8000-000000000004','Verification product',125.50);
select public.billing_create_invoice('{"number":"VERIFY-001","customer_id":"00000000-0000-4000-8000-000000000003","issued_on":"2026-11-18","due_on":"2026-12-18","currency":"ZAR","tax_rate":15,"items":[{"product_id":"00000000-0000-4000-8000-000000000004","quantity":2}]}');
do $$ begin
 if (select count(*) from public.billing_invoices where number='VERIFY-001')<>1 then raise exception 'Invoice creation failed'; end if;
 if (select sum(quantity*unit_price) from public.billing_invoice_items where product_id='00000000-0000-4000-8000-000000000004')<>251 then raise exception 'Invoice amount incorrect'; end if;
 begin
 perform public.billing_create_invoice('{"number":"VERIFY-FAIL","customer_id":"00000000-0000-4000-8000-000000000003","issued_on":"2026-11-18","due_on":"2026-12-18","currency":"ZAR","tax_rate":0,"items":[{"product_id":"00000000-0000-4000-8000-000000000004","quantity":0}]}');
 raise exception 'Invalid quantity was accepted';
 exception when check_violation then null; end;
 if exists(select from public.billing_invoices where number='VERIFY-FAIL') then raise exception 'Atomic rollback failed'; end if;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',true);
do $$ begin
 if exists(select from public.billing_invoices where number='VERIFY-001') then raise exception 'Invoice isolation failed'; end if;
 if exists(select from public.billing_customers where id='00000000-0000-4000-8000-000000000003') then raise exception 'Customer isolation failed'; end if;
 if exists(select from public.billing_products where id='00000000-0000-4000-8000-000000000004') then raise exception 'Product isolation failed'; end if;
 begin
 insert into public.billing_customers(user_id,name) values('00000000-0000-4000-8000-000000000001','Cross-user write');
 raise exception 'Cross-user write allowed'; exception when insufficient_privilege then null; end;
end $$;
reset role;
select 'PASS: invoice creation, amounts, atomic rollback, account isolation and write protection' as result;
rollback;
