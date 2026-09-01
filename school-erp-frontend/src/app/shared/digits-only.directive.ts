import { Directive, ElementRef, HostListener, Input, inject } from '@angular/core';
import { NgControl } from '@angular/forms';

/**
 * Restricts an input to digits, for fields that are numeric strings rather than numbers —
 * phone and pincode. `type="number"` is wrong for these: it strips leading zeros, accepts `e`,
 * `+` and `-`, and turns a scroll wheel over the field into a silent edit.
 *
 * Non-digit keystrokes are blocked outright; anything that still arrives (paste, autofill,
 * IME) is stripped on input and written back through `NgControl`, so the bound model never sees
 * a value the field would not accept from the keyboard.
 *
 *   <input class="input" appDigitsOnly="10" [(ngModel)]="form.phone" />
 */
@Directive({
  selector: 'input[appDigitsOnly]',
  standalone: true,
  host: { inputmode: 'numeric', autocomplete: 'off' },
})
export class DigitsOnlyDirective {
  private readonly el = inject<ElementRef<HTMLInputElement>>(ElementRef);
  private readonly control = inject(NgControl, { optional: true, self: true });

  /** Maximum digits to keep. Empty or 0 means no limit. */
  @Input('appDigitsOnly') maxDigits: number | string = '';

  @HostListener('keypress', ['$event'])
  onKeypress(e: KeyboardEvent): void {
    // Single printable characters only — this must not swallow Backspace, Tab, Enter or
    // Ctrl/Cmd shortcuts, all of which arrive with a multi-character key or a modifier.
    if (e.ctrlKey || e.metaKey || e.altKey || e.key.length !== 1) return;
    if (!/\d/.test(e.key)) e.preventDefault();
  }

  @HostListener('input')
  onInput(): void {
    const input = this.el.nativeElement;
    const raw = input.value ?? '';
    const max = Number(this.maxDigits) || 0;
    let clean = raw.replace(/\D+/g, '');
    if (max > 0) clean = clean.slice(0, max);
    if (clean === raw) return;

    // Keep the caret where the typing was, allowing for the characters just removed.
    const caret = Math.max(0, (input.selectionStart ?? clean.length) - (raw.length - clean.length));
    input.value = clean;
    input.setSelectionRange?.(caret, caret);
    // Write through the control so the bound model matches the box; the default emitEvent lets
    // (ngModelChange) fire, which is what clears the field's error message.
    this.control?.control?.setValue(clean);
  }
}
