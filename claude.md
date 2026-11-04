# Project Context: CVC Cafe - Real-Time Ordering & POS System

## 1. Project Overview
ระบบสั่งเครื่องดื่มออนไลน์หน้าร้าน (POS) และผ่าน LINE LIFF แบบ Real-time สำหรับร้าน **CVC Cafe** ทำงานด้วยสถาปัตยกรรม Multi-page Static Web App (HTML/CSS/Vanilla JS) เชื่อมต่อฐานข้อมูลและระบบ Real-time ผ่าน **Supabase** โดยตรง และ Deploy ขึ้น **Vercel** ผ่าน GitHub

- **Production URL:** `https://cafe-cvc.vercel.app`
- **Design System / Theme:**
  - Font: Google Fonts `'Kanit', sans-serif`
  - Colors: `--primary: #A07855`, `--bg: #FBF9F6`, `--text: #4A4A4A`, `--light: #F2EFE9`, `--accent: #D5BDAF`, `--new: #E74C3C`, `--doing: #F39C12`, `--done: #27AE60`

---

## 2. Tech Stack & Credentials
- **Frontend:** Vanilla HTML5, CSS3, JavaScript (ES6+), no bundler/framework required.
- **External SDKs (loaded via CDN):**
  - Supabase JS v2: `<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>`
  - LINE LIFF SDK v2: `<script src="https://static.line-scdn.net/liff/edge/2/sdk.js"></script>`
- **Supabase Configuration:**
  - `SUPABASE_URL`: `https://zkjnamlcnffsuqzvkznx.supabase.co`
  - `SUPABASE_KEY` (anon public): `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inpram5hbWxjbmZmc3VxenZrem54Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk3MTk3MjIsImV4cCI6MjEwNTI5NTcyMn0.yUCmqbe5_tjsOBNEfx7qPXkmUiuoL5IX_y-tdjJuITY`
  - **CRITICAL JS RULE:** ห้ามประกาศตัวแปรชื่อ `const supabase = ...` เพราะจะชนกับ Global Object `window.supabase` จาก CDN ให้ใช้ชื่อตัวแปร `supabaseClient` เสมอ:
    ```javascript
    const supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_KEY);
    ```

---

## 3. Database Schema & RLS Policies (Supabase PostgreSQL)

### 3.1 Table: `menu`
เก็บรายการเครื่องดื่มทั้งหมดของร้าน (เริ่มต้น 30 เมนู)
- `menu_id` (text, Primary Key) — รหัสเมนู เช่น `'M001'`, `'M002'`
- `name` (text) — ชื่อเมนู เช่น `'เอสเพรสโซ'`, `'ชาองุ่น ครีมชีส'`
- `category` (text) — หมวดหมู่ (`'กาแฟ'`, `'ชา/นม'`, `'ชาผลไม้'`, `'สมูทตี้'`, `'โซดา'`)
- `price_hot` (int4, nullable) — ราคาเมนูร้อน (ถ้าไม่มีจะเป็น null)
- `price_ice` (int4, nullable) — ราคาเมนูเย็น (ถ้าไม่มีจะเป็น null)
- `price_frappe` (int4, nullable) — ราคาเมนูปั่น (ถ้าไม่มีจะเป็น null)
- `image_url` (text, nullable) — เก็บ Emoji หรือ URL รูปภาพเมนู
- `is_active` (bool, default: true) — สถานะเปิดขาย (`true` = ขาย, `false` = ของหมด/ซ่อนจากหน้าร้าน)
- **RLS Policies:** เปิด Public `SELECT` และ `UPDATE` ไว้แล้ว

### 3.2 Table: `orders`
เก็บรายการสั่งซื้อทั้งหมด ทั้งจาก LINE LIFF และ POS หน้าร้าน
- `order_id` (text, Primary Key) — รหัสออเดอร์:
  - สั่งจาก LINE: `ORD-YYMMDD-XXXX` (เช่น `ORD-260918-7603`)
  - สั่งจาก POS หน้าร้าน: `POS-YYMMDD-XXXX`
- `created_at` (timestamptz, default: `now()`) — เวลาที่สร้างออเดอร์
- `customer_uid` (text) — LINE `userId` ของลูกค้า หรือ `'walk-in'` สำหรับหน้าร้าน
- `customer_name` (text) — ชื่อ LINE `displayName` หรือชื่อ/หมายเลขคิวที่แคชเชียร์กรอก
- `order_details` (text) — รายการเครื่องดื่มที่สั่ง คั่นแต่ละรายการด้วย `' | '`
  - **CRITICAL FORMAT RULE:** รูปแบบข้อความคือ `"${qty}x ${name} (${serveType}) หวาน${sweet} (${toppings})"` เช่น `"1x ชาองุ่น ครีมชีส (ปั่น) หวานปกติ | 2x ชาไทย (เย็น) หวานน้อย (ไข่มุกบราวน์ชูการ์)"`
  - หน้า `dashboard.html` และ `admin.html` ใช้ `.split(' | ')` และ Regex `/^(\d+)x\s+(.+)$/` ในการแยกจำนวนแก้วและชื่อเมนู ห้ามเปลี่ยนโครงสร้าง String นี้โดยไม่อัปเดตตัว Parser
- `total_price` (int4/numeric) — ยอดเงินรวมทั้งบิล (บาท)
- `status` (text) — สถานะออเดอร์ มี 3 ค่า: `'New'`, `'Doing'`, `'Done'`
- `payment_method` (text) — ช่องทางชำระเงิน เช่น `'Cash'`, `'Transfer'`
- **Realtime & RLS:** เปิด `supabase_realtime` บนตาราง `orders` แล้ว และเปิด RLS Public สำหรับ `SELECT`, `INSERT`, `UPDATE` เรียบร้อยแล้ว

> **Setup:** ตาราง/คอลัมน์ใหม่ทั้งหมดอยู่ใน `supabase_setup.sql` (รันซ้ำได้) — ต้องรันใน Supabase SQL Editor ก่อน ไม่งั้นท็อปปิ้งใช้รายการสำรอง และโปรโมชั่น/แต้มจะไม่ทำงาน

### 3.3 Table: `toppings`
- `id` (serial, Primary Key)
- `name` (text) — ชื่อท็อปปิ้ง เช่น `'ไข่มุกบราวน์ชูการ์'`, `'เพิ่มช็อตกาแฟ'`
- `price` (integer) — ราคาท็อปปิ้ง เช่น `10`, `15`
- `is_active` (boolean, default: true)
- **RLS Policies:** เปิด Public `SELECT` และ `ALL`

### 3.4 Table: `customers` (Loyalty)
- `line_uid` (text, unique) — LINE `userId`, `display_name`, `points` (แต้มคงเหลือ), `total_cups`, `phone`, `picture_url`, `updated_at`
- กติกา: 1 แก้ว = 1 แต้ม, แลก `points_per_reward` แต้ม ได้ส่วนลด `reward_value` บาท (index.html อัปเดตแต้มหลังส่งออเดอร์สำเร็จ)

### 3.5 Table: `settings`
- `setting_key` / `setting_value` (text) — ตอนนี้ใช้ `points_per_reward` (ค่าเริ่มต้น 10) และ `reward_value` (ค่าเริ่มต้น 50)

### 3.6 Table: `promotions`
- `code` (text PK), `title`, `discount_type` (`'amount'`|`'percent'`), `discount_value`, `min_total`, `is_active`
- ยังไม่มีหน้าจัดการ ต้องเพิ่ม/แก้ใน Supabase Table Editor

### 3.7 คอลัมน์เพิ่มใน `orders`
- `discount` (int, default 0) และ `discount_note` (text) — `total_price` ยังเป็นยอดสุทธิหลังหักส่วนลด
- ค่า `sweet` ที่บันทึกคือ `'0%'`, `'น้อย'`, `'ปกติ'` → ได้ `หวาน0%`, `หวานน้อย`, `หวานปกติ` (ข้อมูลเก่าก่อน 2026-11 อาจเป็น `หวานหวานน้อย`)

---

## 4. Existing Application Files

1. **`index.html` (Customer Frontend - LINE LIFF)**
   - เชื่อมต่อ LINE LIFF ดึงโปรไฟล์ลูกค้า (`displayName`, `pictureUrl`, `userId`)
   - ดึงเมนูจากตาราง `menu` เฉพาะที่ `is_active === true` แยกตามแท็บหมวดหมู่
   - มี Modal เลือกร้อน/เย็น/ปั่น (สร้างปุ่มอัตโนมัติตามราคาที่ไม่ใช่ null), เลือกความหวาน (0%, 50%, 100%), เลือกท็อปปิ้ง และปรับจำนวนแก้ว
   - มีระบบตะกร้าสินค้า (`cart` array) และปุ่มกดยืนยันเพื่อ `INSERT` ลงตาราง `orders`

2. **`pos.html` (Walk-in POS Frontend สำหรับ iPad หน้าร้าน)**
   - โครงสร้างคล้าย `index.html` แต่ขยายความกว้างเป็น `600px` สำหรับแท็บเล็ต และตัด LINE LIFF ออก
   - ใน Modal ตะกร้าสินค้ามีช่อง `<input id="pos-customer-name">` ให้พนักงานพิมพ์ชื่อลูกค้าหรือหมายเลขป้ายคิว
   - บันทึกออเดอร์โดยใช้รหัส `POS-YYMMDD-XXXX` และ `customer_uid: 'walk-in'`

3. **`admin.html` (Barista KDS / Kanban Board)**
   - แสดงผล 3 คอลัมน์: `New` (ออเดอร์ใหม่), `Doing` (กำลังทำ), `Done` (เสร็จแล้ว) ดึงข้อมูล 50 รายการล่าสุด
   - ใช้ Supabase Realtime (`postgres_changes` บนตาราง `orders`) + เรียก `fetchOrders()` ทันทีหลังกดปุ่มอัปเดตสถานะ
   - มีปุ่มกดเปลี่ยนสถานะจาก `New` -> `Doing` และ `Doing` -> `Done`

4. **`queue.html` (Customer Queue Display สำหรับจอทีวี/iPad หน้าร้าน)**
   - แสดงผล 2 คอลัมน์ฟอนต์ขนาดใหญ่: `กำลังเตรียม (Preparing)` (`status === 'Doing'`) และ `เชิญรับเครื่องดื่ม (Ready)` (`status === 'Done'` แสดง 5 คิวล่าสุด)
   - อัปเดตอัตโนมัติผ่าน Supabase Realtime

5. **`dashboard.html` (Daily Sales Dashboard)**
   - ดึงออเดอร์เฉพาะของวันนี้ (`created_at >= YYYY-MM-DDT00:00:00+07:00`)
   - คำนวณ: ยอดขายรวมวันนี้ (บาท), จำนวนที่ขายได้ (แก้ว), จำนวนออเดอร์ (บิล) และจัดอันดับ Top 5 เมนูขายดีประจำวัน

6. **`admin_menu.html` (Back-office Menu Management)**
   - แท็บเมนู: Toggle `is_active` ของตาราง `menu`
   - แท็บท็อปปิ้ง: เพิ่ม / แก้ชื่อ-ราคา / ลบ / Toggle `is_active` ของตาราง `toppings`

7. **`receipt.js` (Shared Receipt Printing)**
   - `printReceipt(order, items?)` ใช้ใน `pos.html` (พิมพ์อัตโนมัติหลังส่งออเดอร์) และ `admin.html` (ปุ่ม 🖨️ บนการ์ด)
   - Layout `@media print` ขนาด 80mm/58mm (เลือกได้ จำไว้ใน localStorage `cvc_receipt_width`)

8. **`supabase_setup.sql`** — สคริปต์สร้างตาราง/Policy/ข้อมูลเริ่มต้นสำหรับฟีเจอร์ข้างบน

---

## 5. Status / Roadmap

ทำเสร็จแล้ว (2026-11-04): Dynamic Toppings, Receipt Printing, Loyalty Points, Repeat Order, Favorite (เก็บใน localStorage ต่อเครื่อง), Promotion codes, ค้นหาเมนู, ประวัติการสั่ง

งานที่เหลือ / ไอเดียต่อไป:
- หน้าจัดการโปรโมชั่นใน `admin_menu.html`
- ความปลอดภัย: ตอนนี้ทุกตารางเปิด Public write ด้วย anon key — ใครก็แก้แต้ม/เมนูได้ถ้ารู้ key ควรย้ายการบวกแต้มไปเป็น Postgres function (RPC) และใส่ Supabase Auth ให้หน้า admin
