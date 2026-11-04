// =====================================================================
// CVC Cafe - ระบบพิมพ์ใบเสร็จ (Thermal Printer 58mm / 80mm)
// ใช้ใน pos.html และ admin.html:
//   <script src="receipt.js"></script>
//   printReceipt(order, items?)
//     order = แถวจากตาราง orders (order_id, created_at, customer_name, order_details,
//             total_price, payment_method, discount, discount_note)
//     items = (ไม่บังคับ) [{ label, price }] ถ้ามีจะโชว์ราคาต่อรายการ
// ขนาดกระดาษจำไว้ใน localStorage ('cvc_receipt_width' = '58' | '80')
// =====================================================================

const RECEIPT_SHOP_NAME = 'CVC Cafe';
const RECEIPT_FOOTER = 'ขอบคุณที่อุดหนุนค่ะ 🤎';

function getReceiptWidth() {
    try { return localStorage.getItem('cvc_receipt_width') === '58' ? '58' : '80'; } catch (e) { return '80'; }
}

function setReceiptWidth(width) {
    try { localStorage.setItem('cvc_receipt_width', width); } catch (e) { /* ไม่มี storage ก็ใช้ค่าเริ่มต้น */ }
}

function receiptEscape(str) {
    return String(str ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

function ensureReceiptStyles() {
    if (document.getElementById('receipt-style')) return;
    const style = document.createElement('style');
    style.id = 'receipt-style';
    style.textContent = `
        #receipt-root { display: none; }
        @media print {
            @page { margin: 0; }
            html, body { background: white !important; padding: 0 !important; margin: 0 !important; height: auto !important; display: block !important; }
            body > *:not(#receipt-root) { display: none !important; }
            #receipt-root { display: block !important; color: #000; font-family: 'Kanit', sans-serif; font-size: 12px; line-height: 1.35; padding: 3mm; }
            #receipt-root.w58 { width: 58mm; font-size: 11px; }
            #receipt-root.w80 { width: 80mm; }
            .rc-center { text-align: center; }
            .rc-shop { font-size: 1.6em; font-weight: 600; }
            .rc-sub { font-size: 0.9em; }
            .rc-hr { border-top: 1px dashed #000; margin: 2mm 0; }
            .rc-row { display: flex; justify-content: space-between; gap: 2mm; }
            .rc-row > span:last-child { white-space: nowrap; }
            .rc-item { margin-bottom: 1mm; }
            .rc-total { font-size: 1.35em; font-weight: 600; }
            .rc-queue { font-size: 1.5em; font-weight: 600; text-align: center; margin: 1mm 0; }
        }
    `;
    document.head.appendChild(style);
}

function printReceipt(order, items) {
    ensureReceiptStyles();

    let root = document.getElementById('receipt-root');
    if (!root) {
        root = document.createElement('div');
        root.id = 'receipt-root';
        document.body.appendChild(root);
    }
    root.className = 'w' + getReceiptWidth();

    const created = order.created_at ? new Date(order.created_at) : new Date();
    const dateStr = created.toLocaleDateString('th-TH', { day: '2-digit', month: '2-digit', year: 'numeric' });
    const timeStr = created.toLocaleTimeString('th-TH', { hour: '2-digit', minute: '2-digit' });

    const lines = items && items.length
        ? items
        : (order.order_details || '').split(' | ').filter(Boolean).map(label => ({ label, price: null }));

    const itemsHtml = lines.map(i => `
        <div class="rc-row rc-item">
            <span>${receiptEscape(i.label.trim())}</span>
            <span>${i.price != null ? i.price.toLocaleString() : ''}</span>
        </div>`).join('');

    const discount = Number(order.discount) || 0;
    const discountHtml = discount > 0 ? `
        <div class="rc-row"><span>รวม</span><span>${(order.total_price + discount).toLocaleString()}</span></div>
        <div class="rc-row"><span>ส่วนลด${order.discount_note ? ' (' + receiptEscape(order.discount_note) + ')' : ''}</span><span>-${discount.toLocaleString()}</span></div>` : '';

    const paymentLabel = { Cash: 'เงินสด', Transfer: 'โอนเงิน / QR' }[order.payment_method] || order.payment_method || '-';

    root.innerHTML = `
        <div class="rc-center rc-shop">${receiptEscape(RECEIPT_SHOP_NAME)}</div>
        <div class="rc-center rc-sub">ใบเสร็จรับเงิน</div>
        <div class="rc-hr"></div>
        <div class="rc-queue">${receiptEscape(order.customer_name || 'ลูกค้าทั่วไป')}</div>
        <div class="rc-row"><span>เลขที่</span><span>${receiptEscape(order.order_id)}</span></div>
        <div class="rc-row"><span>วันที่</span><span>${dateStr} ${timeStr}</span></div>
        <div class="rc-hr"></div>
        ${itemsHtml}
        <div class="rc-hr"></div>
        ${discountHtml}
        <div class="rc-row rc-total"><span>ยอดสุทธิ</span><span>฿${Number(order.total_price || 0).toLocaleString()}</span></div>
        <div class="rc-row"><span>ชำระโดย</span><span>${receiptEscape(paymentLabel)}</span></div>
        <div class="rc-hr"></div>
        <div class="rc-center">${receiptEscape(RECEIPT_FOOTER)}</div>
    `;

    // รอฟอนต์โหลดเสร็จก่อนสั่งพิมพ์ ไม่งั้นบางเครื่องจะพิมพ์ฟอนต์สำรอง
    const doPrint = () => setTimeout(() => window.print(), 50);
    if (document.fonts && document.fonts.ready) document.fonts.ready.then(doPrint); else doPrint();
}
