begin;
alter table public.billing_invoices add column if not exists document_type text not null default 'invoice' check(document_type in ('invoice','quote'));
alter table public.billing_invoices add column if not exists source_quote_id uuid unique;
alter table public.billing_invoices add constraint billing_invoices_source_quote_owner_fk foreign key(source_quote_id,user_id) references public.billing_invoices(id,user_id);
create index if not exists billing_invoices_source_quote_owner_idx on public.billing_invoices(source_quote_id,user_id);
create or replace function public.billing_create_invoice(payload jsonb) returns uuid language plpgsql security invoker set search_path='' as $$
declare inv uuid; customer jsonb; business jsonb; item jsonb; prod public.billing_products; begin
 if auth.uid() is null then raise exception 'Sign in first'; end if;
 select to_jsonb(c) - 'user_id' into customer from public.billing_customers c where id=(payload->>'customer_id')::uuid and user_id=auth.uid();
 if customer is null then raise exception 'Customer not found'; end if;
 select to_jsonb(s) - 'user_id' into business from public.billing_settings s where user_id=auth.uid();
 if jsonb_array_length(payload->'items') is null or jsonb_array_length(payload->'items')<1 then raise exception 'Add at least one product'; end if;
 insert into public.billing_invoices(number,customer_id,customer_snapshot,business_snapshot,issued_on,due_on,currency,notes,tax_rate,status,reference,sales_rep,document_type)
 values(payload->>'number',(payload->>'customer_id')::uuid,customer,coalesce(business,'{"name":"My business"}'::jsonb),(payload->>'issued_on')::date,(payload->>'due_on')::date,payload->>'currency',coalesce(payload->>'notes',''),(payload->>'tax_rate')::numeric,'draft',coalesce(payload->>'reference',''),coalesce(payload->>'sales_rep',''),coalesce(payload->>'document_type','invoice')) returning id into inv;
 for item in select * from jsonb_array_elements(payload->'items') loop
 select * into prod from public.billing_products where id=(item->>'product_id')::uuid and user_id=auth.uid();
 if not found then raise exception 'Product not found'; end if;
 insert into public.billing_invoice_items(invoice_id,product_id,description,quantity,unit_price) values(inv,prod.id,prod.name,(item->>'quantity')::numeric,prod.price);
 end loop;
 return inv; end $$;
create function public.billing_invoice_from_quote(p_quote_id uuid,p_number text,p_issued_on date,p_due_on date) returns uuid
language plpgsql security invoker set search_path='' as $$
declare quote public.billing_invoices; inv uuid; begin
 if auth.uid() is null then raise exception 'Sign in first'; end if;
 select * into quote from public.billing_invoices where id=p_quote_id and user_id=auth.uid() and document_type='quote' for update;
 if not found then raise exception 'Quote not found'; end if;
 select id into inv from public.billing_invoices where source_quote_id=quote.id and user_id=auth.uid();
 if inv is not null then return inv; end if;
 if quote.status='cancelled' then raise exception 'A cancelled quote cannot be converted'; end if;
 if length(trim(coalesce(p_number,'')))=0 then raise exception 'Enter an invoice number'; end if;
 if p_due_on<p_issued_on then raise exception 'Due date must be on or after the issue date'; end if;
 if not exists(select from public.billing_invoice_items where invoice_id=quote.id and user_id=auth.uid()) then raise exception 'Quote has no products'; end if;
 insert into public.billing_invoices(user_id,number,customer_id,customer_snapshot,business_snapshot,issued_on,due_on,currency,notes,tax_rate,status,reference,sales_rep,document_type,source_quote_id)
 values(auth.uid(),p_number,quote.customer_id,quote.customer_snapshot,quote.business_snapshot,p_issued_on,p_due_on,quote.currency,quote.notes,quote.tax_rate,'draft',quote.reference,quote.sales_rep,'invoice',quote.id) returning id into inv;
 insert into public.billing_invoice_items(user_id,invoice_id,product_id,description,quantity,unit_price)
 select auth.uid(),inv,product_id,description,quantity,unit_price from public.billing_invoice_items where invoice_id=quote.id and user_id=auth.uid();
 return inv;
end $$;
revoke all on function public.billing_create_invoice(jsonb) from public,anon;
revoke all on function public.billing_invoice_from_quote(uuid,text,date,date) from public,anon;
grant execute on function public.billing_create_invoice(jsonb) to authenticated;
grant execute on function public.billing_invoice_from_quote(uuid,text,date,date) to authenticated;
notify pgrst,'reload schema';
commit;
