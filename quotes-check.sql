begin;
insert into auth.users(id,email) values ('00000000-0000-4000-8000-000000000011','quote-check-1@example.invalid'),('00000000-0000-4000-8000-000000000012','quote-check-2@example.invalid');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000011',true);
insert into public.billing_customers(id,name) values ('00000000-0000-4000-8000-000000000013','Original quote customer');
insert into public.billing_products(id,name,price) values ('00000000-0000-4000-8000-000000000014','Original quote product',125.50);
insert into public.billing_settings(name) values('Original business');
do $$ declare q uuid; inv uuid; again uuid; cancelled uuid; begin
 q:=public.billing_create_invoice('{"number":"QUOTE-CHECK","document_type":"quote","customer_id":"00000000-0000-4000-8000-000000000013","issued_on":"2026-11-18","due_on":"2026-12-18","currency":"ZAR","tax_rate":15,"reference":"Customer PO","sales_rep":"Sales rep","notes":"Quote notes","items":[{"product_id":"00000000-0000-4000-8000-000000000014","quantity":2}]}');
 if (select document_type from public.billing_invoices where id=q)<>'quote' then raise exception 'Quote creation failed'; end if;
 update public.billing_products set price=999,name='Changed product' where id='00000000-0000-4000-8000-000000000014';
 update public.billing_customers set name='Changed customer' where id='00000000-0000-4000-8000-000000000013';
 update public.billing_settings set name='Changed business';
 inv:=public.billing_invoice_from_quote(q,'INVOICE-CHECK','2026-11-19','2026-12-19');
 if not exists(select from public.billing_invoices where id=inv and source_quote_id=q and document_type='invoice' and status='draft' and customer_snapshot->>'name'='Original quote customer' and business_snapshot->>'name'='Original business' and tax_rate=15 and reference='Customer PO' and sales_rep='Sales rep' and notes='Quote notes' and issued_on='2026-11-19' and due_on='2026-12-19') then raise exception 'Converted invoice details incorrect'; end if;
 if not exists(select from public.billing_invoice_items where invoice_id=inv and description='Original quote product' and quantity=2 and unit_price=125.50) then raise exception 'Quote prices were not preserved'; end if;
 if not exists(select from public.billing_invoices where id=q and document_type='quote') then raise exception 'Original quote missing'; end if;
 again:=public.billing_invoice_from_quote(q,'SECOND-INVOICE','2026-11-19','2026-12-19');
 if again<>inv or (select count(*) from public.billing_invoices where source_quote_id=q)<>1 then raise exception 'Duplicate invoice created'; end if;
 begin
 perform public.billing_invoice_from_quote(inv,'WRONG','2026-11-19','2026-12-19');
 raise exception 'An invoice was converted'; exception when raise_exception then if sqlerrm<>'Quote not found' then raise; end if; end;
 cancelled:=public.billing_create_invoice('{"number":"QUOTE-CANCELLED-CHECK","document_type":"quote","customer_id":"00000000-0000-4000-8000-000000000013","issued_on":"2026-11-18","due_on":"2026-12-18","currency":"ZAR","tax_rate":15,"items":[{"product_id":"00000000-0000-4000-8000-000000000014","quantity":1}]}');
 update public.billing_invoices set status='cancelled' where id=cancelled;
 begin
 perform public.billing_invoice_from_quote(cancelled,'CANCELLED-INVOICE','2026-11-19','2026-12-19');
 raise exception 'Cancelled quote converted'; exception when raise_exception then if sqlerrm<>'A cancelled quote cannot be converted' then raise; end if; end;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000012',true);
 if exists(select from public.billing_invoices where id in (q,inv)) then raise exception 'Cross-account read allowed'; end if;
 begin
 perform public.billing_invoice_from_quote(q,'OTHER-ACCOUNT-INVOICE','2026-11-19','2026-12-19');
 raise exception 'Cross-account conversion allowed'; exception when raise_exception then if sqlerrm<>'Quote not found' then raise; end if; end;
end $$;
reset role;
select 'PASS: quote creation, conversion, snapshot and price preservation, duplicate prevention, cancelled quote rejection, account isolation' as result;
rollback;
