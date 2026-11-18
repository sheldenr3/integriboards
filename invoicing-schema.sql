begin;
create table public.billing_customers (
 id uuid primary key default gen_random_uuid(), user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 name text not null check(length(trim(name))>0), email text not null default '', phone text not null default '', address text not null default '', created_at timestamptz not null default now(), unique(id,user_id)
);
create table public.billing_products (
 id uuid primary key default gen_random_uuid(), user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 name text not null check(length(trim(name))>0), sku text not null default '', description text not null default '', price numeric(14,2) not null check(price>=0), created_at timestamptz not null default now(), unique(id,user_id)
);
create table public.billing_invoices (
 id uuid primary key default gen_random_uuid(), user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 number text not null, customer_id uuid not null, customer_snapshot jsonb not null, business_snapshot jsonb not null,
 issued_on date not null, due_on date not null check(due_on>=issued_on), currency text not null default 'ZAR' check(currency in ('ZAR','USD','GBP','EUR')),
 status text not null default 'draft' check(status in ('draft','sent','paid','cancelled')), notes text not null default '', tax_rate numeric(5,2) not null default 0 check(tax_rate between 0 and 100),
 created_at timestamptz not null default now(), unique(user_id,number), unique(id,user_id), foreign key(customer_id,user_id) references public.billing_customers(id,user_id)
);
create table public.billing_invoice_items (
 id uuid primary key default gen_random_uuid(), user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 invoice_id uuid not null, product_id uuid, description text not null, quantity numeric(12,3) not null check(quantity>0), unit_price numeric(14,2) not null check(unit_price>=0),
 foreign key(invoice_id,user_id) references public.billing_invoices(id,user_id) on delete cascade,
 foreign key(product_id,user_id) references public.billing_products(id,user_id)
);
create table public.billing_settings (
 user_id uuid primary key default auth.uid() references auth.users(id) on delete cascade, name text not null default 'My business', email text not null default '', phone text not null default '', address text not null default '', registration text not null default '', bank_details text not null default ''
);
do $$ declare t text; begin foreach t in array array['billing_customers','billing_products','billing_invoices','billing_invoice_items','billing_settings'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('create policy owner_access on public.%I for all to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id)',t);
 execute format('grant select,insert,update,delete on public.%I to authenticated',t);
 execute format('revoke all on public.%I from anon',t);
 end loop; end $$;
create index on public.billing_customers(user_id);
create index on public.billing_products(user_id);
create index on public.billing_invoices(user_id,created_at desc);
create index on public.billing_invoices(customer_id,user_id);
create index on public.billing_invoice_items(invoice_id,user_id);
create index on public.billing_invoice_items(product_id,user_id);
create index on public.billing_invoice_items(user_id);
create function public.billing_create_invoice(payload jsonb) returns uuid language plpgsql security invoker set search_path='' as $$
declare inv uuid; customer jsonb; business jsonb; item jsonb; prod public.billing_products; begin
 if auth.uid() is null then raise exception 'Sign in first'; end if;
 select to_jsonb(c) - 'user_id' into customer from public.billing_customers c where id=(payload->>'customer_id')::uuid and user_id=auth.uid();
 if customer is null then raise exception 'Customer not found'; end if;
 select to_jsonb(s) - 'user_id' into business from public.billing_settings s where user_id=auth.uid();
 if jsonb_array_length(payload->'items') is null or jsonb_array_length(payload->'items')<1 then raise exception 'Add at least one product'; end if;
 insert into public.billing_invoices(number,customer_id,customer_snapshot,business_snapshot,issued_on,due_on,currency,notes,tax_rate,status)
 values(payload->>'number',(payload->>'customer_id')::uuid,customer,coalesce(business,'{"name":"My business"}'::jsonb),(payload->>'issued_on')::date,(payload->>'due_on')::date,payload->>'currency',coalesce(payload->>'notes',''),(payload->>'tax_rate')::numeric,'draft') returning id into inv;
 for item in select * from jsonb_array_elements(payload->'items') loop
 select * into prod from public.billing_products where id=(item->>'product_id')::uuid and user_id=auth.uid();
 if not found then raise exception 'Product not found'; end if;
 insert into public.billing_invoice_items(invoice_id,product_id,description,quantity,unit_price) values(inv,prod.id,prod.name,(item->>'quantity')::numeric,prod.price);
 end loop;
 return inv; end $$;
revoke all on function public.billing_create_invoice(jsonb) from public,anon;
grant execute on function public.billing_create_invoice(jsonb) to authenticated;
commit;
