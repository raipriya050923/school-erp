import { Component, ElementRef, EventEmitter, Input, Output, inject } from '@angular/core';
import { DatePipe, DecimalPipe } from '@angular/common';

/** One head's share of what the invoice was raised for. */
export interface ReceiptLine { description: string; amount: number; }

/** Everything printed on a receipt. Shaped by the API; see FeeReceiptDto. */
export interface FeeReceipt {
  schoolName: string;
  schoolAddress: string | null;
  schoolPhone: string | null;
  schoolEmail: string | null;
  paymentId: number;
  receiptNo: string;
  paidDate: string | null;
  issuedAt: string;
  studentName: string;
  admissionNo: string | null;
  classLabel: string | null;
  invoiceNo: string | null;
  month: string | null;
  lines: ReceiptLine[];
  amountPaid: number;
  amountInWords: string;
  method: string | null;
  reference: string | null;
  invoiceTotal: number;
  paidToDate: number;
  balanceAfter: number;
}

/**
 * A printable receipt for one payment.
 *
 * One component for both portals on purpose: the copy the office prints and the copy the parent
 * prints have to be the same document, down to the receipt number, or the two get produced
 * against each other in an argument about what was paid.
 *
 * Printing copies the sheet into an isolated iframe rather than trying to hide the page around
 * it. Hiding with visibility leaves every element occupying its space, so printing from a long
 * list produced the receipt followed by a hundred blank sheets; hiding with display cannot be
 * applied wholesale because the sheet lives in the same tree. An iframe has no host page to
 * fight, so what prints is exactly the receipt.
 */
@Component({
  selector: 'app-fee-receipt',
  standalone: true,
  imports: [DecimalPipe, DatePipe],
  template: `
    <div class="modal-backdrop receipt-backdrop">
      <div class="modal receipt-modal">
        <div class="modal-head no-print">
          <h2>Receipt {{ r.receiptNo }}</h2>
          <button class="modal-close" (click)="closed.emit()">✕</button>
        </div>

        <div class="modal-body receipt-body">
          <div class="receipt-sheet">
            <!-- Header: who issued it -->
            <div class="rc-head">
              <div class="rc-school">
                <div class="rc-name">{{ r.schoolName }}</div>
                @if (r.schoolAddress) { <div class="rc-sub">{{ r.schoolAddress }}</div> }
                <div class="rc-sub">
                  @if (r.schoolPhone) { <span>{{ r.schoolPhone }}</span> }
                  @if (r.schoolPhone && r.schoolEmail) { <span> · </span> }
                  @if (r.schoolEmail) { <span>{{ r.schoolEmail }}</span> }
                </div>
              </div>
              <div class="rc-stamp">
                <div class="rc-title">FEE RECEIPT</div>
                <div class="rc-no">{{ r.receiptNo }}</div>
                <div class="rc-sub">{{ (r.paidDate || r.issuedAt) | date:'d MMM yyyy' }}</div>
              </div>
            </div>

            <!-- Who paid, and what for -->
            <table class="rc-meta">
              <tr>
                <td><span class="rc-label">Received from</span><span class="rc-value">{{ r.studentName }}</span></td>
                <td><span class="rc-label">Admission no</span><span class="rc-value">{{ r.admissionNo || '—' }}</span></td>
              </tr>
              <tr>
                <td><span class="rc-label">Class</span><span class="rc-value">{{ r.classLabel || '—' }}</span></td>
                <td><span class="rc-label">Invoice</span><span class="rc-value">{{ r.invoiceNo || '—' }}@if (r.month) { · {{ r.month }} }</span></td>
              </tr>
            </table>

            <!-- What the invoice was raised for -->
            @if (r.lines.length) {
              <table class="rc-lines">
                <thead><tr><th>Particulars</th><th class="num">Amount</th></tr></thead>
                <tbody>
                  @for (l of r.lines; track l.description) {
                    <tr><td>{{ l.description }}</td><td class="num">₹{{ l.amount | number:'1.2-2' }}</td></tr>
                  }
                </tbody>
                <tfoot>
                  <tr><td>Invoice total</td><td class="num">₹{{ r.invoiceTotal | number:'1.2-2' }}</td></tr>
                </tfoot>
              </table>
            }

            <!-- The money: what this receipt acknowledges, and nothing else. -->
            <table class="rc-money">
              <tr class="rc-paid">
                <td>Paid</td>
                <td class="num">₹{{ r.amountPaid | number:'1.2-2' }}</td>
              </tr>
            </table>

            <!-- Words beside figures: what stops a 1 becoming a 7 after it leaves the office. -->
            <div class="rc-words">{{ r.amountInWords }}</div>

            <table class="rc-meta">
              <tr>
                <td><span class="rc-label">Paid by</span><span class="rc-value">{{ method }}</span></td>
                <td><span class="rc-label">Reference</span><span class="rc-value">{{ r.reference || '—' }}</span></td>
              </tr>
            </table>

            <div class="rc-foot">
              <div class="rc-note">
                This is a system-generated receipt and does not require a signature.
              </div>
            </div>
          </div>
        </div>

        <div class="modal-foot no-print">
          <button class="btn btn-ghost" (click)="closed.emit()">Close</button>
          <button class="btn btn-primary" (click)="print()">Print receipt</button>
        </div>
      </div>
    </div>
  `,
  styles: [`
    .receipt-modal { max-width: 620px; }
    .receipt-body { background: var(--neutral-tint); }
    .receipt-sheet {
      background: #fff; color: #1f2733; padding: 22px 24px;
      border: 1px solid var(--border); border-radius: 10px;
      font-size: 13px; line-height: 1.5;
    }

    .rc-head { display: flex; justify-content: space-between; gap: 18px; align-items: flex-start;
               border-bottom: 2px solid #1f2733; padding-bottom: 12px; margin-bottom: 14px; }
    .rc-name { font-size: 17px; font-weight: 800; letter-spacing: -0.01em; }
    .rc-sub { font-size: 11.5px; color: #6b7684; margin-top: 2px; }
    .rc-stamp { text-align: right; white-space: nowrap; }
    .rc-title { font-size: 11px; font-weight: 800; letter-spacing: 0.12em; color: #6b7684; }
    .rc-no { font-size: 15px; font-weight: 800; font-family: Consolas, Menlo, monospace; margin-top: 2px; }

    .rc-meta { width: 100%; border-collapse: collapse; margin-bottom: 12px; }
    .rc-meta td { padding: 4px 0; vertical-align: top; width: 50%; }
    .rc-label { display: block; font-size: 10.5px; text-transform: uppercase; letter-spacing: 0.06em; color: #8a94a2; }
    .rc-value { display: block; font-weight: 600; }

    .rc-lines, .rc-money { width: 100%; border-collapse: collapse; margin-bottom: 12px; }
    .rc-lines th, .rc-lines td, .rc-money td { padding: 6px 0; border-bottom: 1px solid #eef1f6; }
    .rc-lines th { font-size: 10.5px; text-transform: uppercase; letter-spacing: 0.06em;
                   color: #8a94a2; text-align: left; border-bottom: 1px solid #d7dde6; }
    .rc-lines .num, .rc-money .num { text-align: right; font-variant-numeric: tabular-nums; }
    .rc-lines tfoot td { font-weight: 700; border-bottom: 0; }

    .rc-paid td { font-size: 15px; font-weight: 800; border-bottom: 0; }

    .rc-words { background: #f7f9fc; border: 1px solid #e3e8ef; border-radius: 8px;
                padding: 9px 12px; font-size: 12.5px; font-style: italic; margin-bottom: 14px; }

    /* Centred now that nothing sits opposite it — right-aligned text with empty space to its
       left reads as a column that lost its partner. */
    .rc-foot { margin-top: 26px; padding-top: 12px; border-top: 1px solid #eef1f6; }
    .rc-note { font-size: 10.5px; color: #8a94a2; text-align: center; line-height: 1.5; }
  `],
})
export class FeeReceiptComponent {
  @Input({ required: true }) r!: FeeReceipt;
  @Output() closed = new EventEmitter<void>();

  /** Payment methods are stored as slugs; a receipt should not read "bank_transfer". */
  get method(): string {
    const m = (this.r.method ?? '').replace(/_/g, ' ').trim();
    return m ? m.charAt(0).toUpperCase() + m.slice(1) : '—';
  }

  private readonly host = inject(ElementRef<HTMLElement>);

  /**
   * Prints the sheet alone.
   *
   * The iframe is given copies of the document's stylesheets so the receipt looks the same on
   * paper as on screen — component styles are attribute-scoped, and the attributes travel with
   * the cloned markup, so they still match. It is removed once the print dialog has been
   * dismissed; removing it earlier cancels the print in some browsers.
   */
  print(): void {
    const sheet = (this.host.nativeElement as HTMLElement).querySelector('.receipt-sheet');
    if (!sheet) return;

    const styles = Array.from(document.querySelectorAll('style, link[rel="stylesheet"]'))
      .map(node => node.outerHTML)
      .join('\n');

    const frame = document.createElement('iframe');
    // Off-screen rather than display:none: a hidden frame does not lay out, and a frame with no
    // layout prints an empty page.
    frame.setAttribute('aria-hidden', 'true');
    frame.style.cssText = 'position:fixed;right:0;bottom:0;width:0;height:0;border:0;';
    document.body.appendChild(frame);

    const doc = frame.contentDocument;
    if (!doc) { frame.remove(); return; }

    doc.open();
    doc.write(`<!doctype html><html><head><meta charset="utf-8">
      <title>${this.r.receiptNo}</title>
      ${styles}
      <style>
        @page { margin: 14mm; }
        html, body { margin: 0; padding: 0; background: #fff; }
        .receipt-sheet { border: 0; border-radius: 0; box-shadow: none; padding: 0; }
      </style>
    </head><body>${sheet.outerHTML}</body></html>`);
    doc.close();

    const go = () => {
      frame.contentWindow?.focus();
      frame.contentWindow?.print();
      // The dialog is modal, so this runs once it closes. The delay covers browsers that return
      // from print() immediately.
      setTimeout(() => frame.remove(), 1000);
    };

    // Stylesheets arrive as <link>s in a development build, so printing before they load would
    // put an unstyled receipt on paper.
    if (frame.contentWindow?.document.readyState === 'complete') setTimeout(go, 150);
    else frame.onload = () => setTimeout(go, 150);
  }
}
