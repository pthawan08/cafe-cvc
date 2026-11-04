-- =====================================================================
-- CVC Cafe - Supabase setup สำหรับฟีเจอร์ใหม่
-- วิธีใช้: Supabase Dashboard > SQL Editor > New query > วางทั้งไฟล์ > Run
-- รันซ้ำได้ปลอดภัย (ใช้ IF NOT EXISTS / DROP POLICY IF EXISTS)
-- =====================================================================

-- ---------- 1. ตารางท็อปปิ้ง (Dynamic Toppings) ----------
create table if not exists public.toppings (
    id serial primary key,
    name text not null,
    price integer not null default 0,
    is_active boolean not null default true
);

alter table public.toppings enable row level security;
drop policy if exists "toppings public select" on public.toppings;
drop policy if exists "toppings public all" on public.toppings;
create policy "toppings public select" on public.toppings for select using (true);
create policy "toppings public all" on public.toppings for all using (true) with check (true);

-- ใส่ท็อปปิ้งเริ่มต้น (เฉพาะตอนตารางยังว่าง)
insert into public.toppings (name, price)
select * from (values
    ('เพิ่มช็อตกาแฟ', 15),
    ('ไข่มุกบราวน์ชูการ์', 10),
    ('วิปครีม', 10),
    ('ชีสโฟม', 15)
) as v(name, price)
where not exists (select 1 from public.toppings);

-- ---------- 2. ลูกค้าสมาชิก (Loyalty) ----------
-- ตาราง customers มีอยู่แล้ว: line_uid, display_name, points, total_cups, phone
alter table public.customers add column if not exists picture_url text;
alter table public.customers add column if not exists updated_at timestamptz default now();
create unique index if not exists customers_line_uid_key on public.customers (line_uid);

alter table public.customers enable row level security;
drop policy if exists "customers public select" on public.customers;
drop policy if exists "customers public insert" on public.customers;
drop policy if exists "customers public update" on public.customers;
create policy "customers public select" on public.customers for select using (true);
create policy "customers public insert" on public.customers for insert with check (true);
create policy "customers public update" on public.customers for update using (true);

-- ---------- 3. ตั้งค่าร้าน (กติกาแต้ม) ----------
-- ตาราง settings มีอยู่แล้ว: setting_key, setting_value
alter table public.settings enable row level security;
drop policy if exists "settings public select" on public.settings;
-- อ่านได้เฉพาะค่าที่หน้าเว็บลูกค้าต้องใช้ ห้ามเปิดทั้งตาราง (มีค่าลับเช่นรหัสผ่านแอดมินอยู่ด้วย)
create policy "settings public select" on public.settings for select
    using (setting_key in ('points_per_reward', 'reward_value'));

insert into public.settings (setting_key, setting_value)
select * from (values
    ('points_per_reward', '10'),   -- สะสมกี่แต้มถึงแลกได้ 1 ครั้ง (1 แก้ว = 1 แต้ม)
    ('reward_value', '50')         -- แลกแล้วได้ส่วนลดกี่บาท
) as v(k, val)
where not exists (select 1 from public.settings s where s.setting_key = v.k);

-- ---------- 4. โค้ดส่วนลด / โปรโมชั่น ----------
create table if not exists public.promotions (
    code text primary key,                 -- เช่น 'WELCOME10' (ตัวพิมพ์ใหญ่)
    title text not null,                   -- ข้อความโชว์บนแบนเนอร์
    discount_type text not null default 'amount' check (discount_type in ('amount', 'percent')),
    discount_value integer not null default 0,
    min_total integer not null default 0,  -- ยอดขั้นต่ำ (บาท)
    is_active boolean not null default true
);

alter table public.promotions enable row level security;
drop policy if exists "promotions public select" on public.promotions;
create policy "promotions public select" on public.promotions for select using (true);

insert into public.promotions (code, title, discount_type, discount_value, min_total)
select * from (values
    ('WELCOME10', 'ลูกค้าใหม่ ลด 10% ทั้งบิล', 'percent', 10, 0),
    ('CVC20', 'ครบ 150 บาท ลดทันที 20 บาท', 'amount', 20, 150)
) as v(code, title, t, val, mt)
where not exists (select 1 from public.promotions);

-- ---------- 5. เก็บส่วนลดไว้ในออเดอร์ ----------
-- total_price เก็บยอดสุทธิหลังหักส่วนลดเหมือนเดิม (dashboard ไม่ต้องแก้)
alter table public.orders add column if not exists discount integer not null default 0;
alter table public.orders add column if not exists discount_note text;

-- ---------- 6. ให้ Realtime ส่งการเปลี่ยนแปลงท็อปปิ้ง ----------
do $$
begin
    alter publication supabase_realtime add table public.toppings;
exception when duplicate_object then null;
end $$;

-- ---------- 7. ที่เก็บรูปเมนู (Supabase Storage) ----------
-- admin_menu.html ย่อรูปแล้วอัปโหลดมาที่ bucket นี้ จากนั้นใส่ลิงก์ลง menu.image_url
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('menu-images', 'menu-images', true, 2097152, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

drop policy if exists "menu-images public read" on storage.objects;
drop policy if exists "menu-images public insert" on storage.objects;
drop policy if exists "menu-images public update" on storage.objects;
drop policy if exists "menu-images public delete" on storage.objects;
create policy "menu-images public read" on storage.objects for select using (bucket_id = 'menu-images');
create policy "menu-images public insert" on storage.objects for insert with check (bucket_id = 'menu-images');
create policy "menu-images public update" on storage.objects for update using (bucket_id = 'menu-images');
create policy "menu-images public delete" on storage.objects for delete using (bucket_id = 'menu-images');

-- ---------- 8. เวลาที่ทำออเดอร์เสร็จ (ใช้กับจอคิว) ----------
-- admin.html ใส่ค่านี้ตอนกด "ออเดอร์เสร็จแล้ว" — queue.html โชว์ "รับได้เลย" 30 นาทีนับจากเวลานี้
alter table public.orders add column if not exists done_at timestamptz;

-- ---------- 9. เพิ่มเมนูใหม่จากหน้า admin_menu.html ----------
drop policy if exists "menu public insert" on public.menu;
create policy "menu public insert" on public.menu for insert with check (true);
