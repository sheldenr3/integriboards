const escapeHtml = value => String(value ?? '').replace(/[&<>"']/g, char => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char]));
const round = value => Math.round((Number(value) + Number.EPSILON) * 100) / 100;

export function invoiceAmounts(invoice) {
  const rate = Number(invoice.tax_rate || 0);
  const rows = (invoice.billing_invoice_items || []).map(item => {
    const exclusive = round(Number(item.quantity) * Number(item.unit_price));
    return {...item, exclusive, inclusivePrice: Number(item.unit_price) * (1 + rate / 100)};
  });
  const exclusive = round(rows.reduce((sum, row) => sum + row.exclusive, 0));
  const grand = round(exclusive * (1 + rate / 100));
  // Allocate any rounding cent to the last line so printed lines equal the total.
  let allocated = 0;
  rows.forEach((row, index) => {
    row.inclusive = index === rows.length - 1 ? round(grand - allocated) : round(row.exclusive * (1 + rate / 100));
    allocated = round(allocated + row.inclusive);
  });
  return {rows, exclusive, vat: round(grand - exclusive), grand, balance: invoice.status === 'paid' || invoice.status === 'cancelled' ? 0 : grand};
}

export function invoiceMarkup(invoice) {
  const e = escapeHtml;
  const isQuote = invoice.document_type === 'quote';
  const business = invoice.business_snapshot || {};
  const customer = invoice.customer_snapshot || {};
  const logo = /^data:image\/(png|jpeg|webp);base64,[A-Za-z0-9+/=]+$/.test(business.logo_data || '') ? business.logo_data : '/integriboards-logo.svg';
  const amounts = invoiceAmounts(invoice);
  const currency = invoice.currency || 'ZAR';
  const cash = value => `${({ZAR:'R',USD:'$',GBP:'£',EUR:'€'})[currency] || currency}${Number(value).toLocaleString('en-US',{minimumFractionDigits:2,maximumFractionDigits:2})}`;
  const date = value => value ? value.split('-').reverse().join('/') : '';
  const address = (label, value) => `<div><h4>${label}</h4><p>${e(value)}</p></div>`;
  const party = (title, party, isBusiness) => `<section class="document-party"><span class="party-label">${title}</span><h2>${e(party.name || (isBusiness ? 'INTEGRI BOARDS' : ''))}</h2><p class="vat-number"><b>${isBusiness ? 'VAT NO:' : 'CUSTOMER VAT NO:'}</b> ${e(party.vat_number || party.registration || '')}</p><div class="document-addresses">${address('POSTAL ADDRESS:',party.postal_address || party.address || '')}${address('PHYSICAL ADDRESS:',party.physical_address || party.address || '')}</div></section>`;
  const pages = [];
  const perPage = amounts.rows.some(row => row.colour || row.size) ? 10 : 12;
  for(let offset = 0; offset < Math.max(amounts.rows.length,1); offset += perPage) pages.push(amounts.rows.slice(offset,offset + perPage));
  return pages.map((rows, index) => `<article class="invoice-paper reference-invoice">
    <header class="document-heading"><section><h1>${isQuote ? 'QUOTE' : 'INVOICE'}</h1><dl class="document-facts">
      <dt>NUMBER:</dt><dd><strong>${e(invoice.number)}</strong></dd>
      <dt>REFERENCE:</dt><dd>${e(invoice.reference || '')}</dd>
      <dt>DATE:</dt><dd><strong>${date(invoice.issued_on)}</strong></dd>
      <dt>${isQuote ? 'VALID UNTIL:' : 'DUE DATE:'}</dt><dd>${date(invoice.due_on)}</dd>
      <dt>SALES REP:</dt><dd>${e(invoice.sales_rep || '')}</dd>
      <dt>OVERALL DISCOUNT %:</dt><dd>0.00%</dd>
      <dt>PAGE:</dt><dd>${index + 1}/${pages.length}</dd>
    </dl></section><img class="document-logo" src="${e(logo)}" alt="${e(business.name || 'Integri Boards')} logo"></header>
    <div class="document-parties">${party('FROM',business,true)}${party('TO',customer,false)}</div>
    <table class="document-items"><colgroup><col style="width:33%"><col style="width:8%"><col style="width:12%"><col style="width:9%"><col style="width:8%"><col style="width:15%"><col style="width:15%"></colgroup><thead><tr><th>Description</th><th>Quantity</th><th>Incl. Price</th><th>Disc %</th><th>VAT %</th><th>Excl. Total</th><th>Incl. Total</th></tr></thead><tbody>${rows.map(row => `<tr><td>${e(row.description)}${row.colour || row.size ? `<small class="board-attributes">${[row.colour ? `Colour: ${e(row.colour)}` : '',row.size ? `Size: ${e(row.size)}` : ''].filter(Boolean).join(' · ')}</small>` : ''}</td><td>${Number(row.quantity).toLocaleString('en-US',{maximumFractionDigits:3})}</td><td>${cash(row.inclusivePrice)}</td><td>0.00%</td><td>${Number(invoice.tax_rate).toFixed(2)}%</td><td>${cash(row.exclusive)}</td><td><strong>${cash(row.inclusive)}</strong></td></tr>`).join('')}</tbody></table>
    <footer class="document-bottom"><div class="document-payment"><p>${e(business.bank_details || '')}</p>${invoice.notes ? `<div class="document-notes"><b>NOTES</b><p>${e(invoice.notes)}</p></div>` : ''}</div>${index === pages.length - 1 ? `<section class="document-totals"><dl><dt>Total Discount:</dt><dd>${cash(0)}</dd><dt>Total Exclusive:</dt><dd>${cash(amounts.exclusive)}</dd><dt>Total VAT:</dt><dd>${cash(amounts.vat)}</dd><dt>Sub Total:</dt><dd>${cash(amounts.grand)}</dd><dt class="grand-total">Grand Total:</dt><dd class="grand-total">${cash(amounts.grand)}</dd></dl><div class="balance-label">${invoice.status === 'cancelled' ? 'CANCELLED' : isQuote ? 'QUOTE TOTAL' : 'BALANCE DUE'}</div><div class="balance-amount">${cash(isQuote ? amounts.grand : amounts.balance)}</div></section>` : '<p class="document-continued">Continued on next page</p>'}</footer>
  </article>`).join('');
}
