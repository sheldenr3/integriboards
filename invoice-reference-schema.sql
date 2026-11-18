begin;
alter table public.billing_customers add column if not exists vat_number text not null default '', add column if not exists physical_address text not null default '';
alter table public.billing_settings add column if not exists vat_number text not null default '', add column if not exists physical_address text not null default '', add column if not exists logo_data text not null default '';
alter table public.billing_invoices add column if not exists reference text not null default '', add column if not exists sales_rep text not null default '';
create or replace function public.billing_create_invoice(payload jsonb) returns uuid language plpgsql security invoker set search_path='' as $$
declare inv uuid; customer jsonb; business jsonb; item jsonb; prod public.billing_products; begin
 if auth.uid() is null then raise exception 'Sign in first'; end if;
 select to_jsonb(c) - 'user_id' into customer from public.billing_customers c where id=(payload->>'customer_id')::uuid and user_id=auth.uid();
 if customer is null then raise exception 'Customer not found'; end if;
 select to_jsonb(s) - 'user_id' into business from public.billing_settings s where user_id=auth.uid();
 if jsonb_array_length(payload->'items') is null or jsonb_array_length(payload->'items')<1 then raise exception 'Add at least one product'; end if;
 insert into public.billing_invoices(number,customer_id,customer_snapshot,business_snapshot,issued_on,due_on,currency,notes,tax_rate,status,reference,sales_rep)
 values(payload->>'number',(payload->>'customer_id')::uuid,customer,coalesce(business,'{"name":"My business"}'::jsonb),(payload->>'issued_on')::date,(payload->>'due_on')::date,payload->>'currency',coalesce(payload->>'notes',''),(payload->>'tax_rate')::numeric,'draft',coalesce(payload->>'reference',''),coalesce(payload->>'sales_rep','')) returning id into inv;
 for item in select * from jsonb_array_elements(payload->'items') loop
 select * into prod from public.billing_products where id=(item->>'product_id')::uuid and user_id=auth.uid();
 if not found then raise exception 'Product not found'; end if;
 insert into public.billing_invoice_items(invoice_id,product_id,description,quantity,unit_price) values(inv,prod.id,prod.name,(item->>'quantity')::numeric,prod.price);
 end loop;
 return inv; end $$;
revoke all on function public.billing_create_invoice(jsonb) from public,anon;
grant execute on function public.billing_create_invoice(jsonb) to authenticated;
notify pgrst, 'reload schema';
commit;
