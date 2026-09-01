/**
 * Per-field validation messages for a modal form.
 *
 * Forms here are plain `[(ngModel)]` objects rather than reactive groups, so there was nowhere to
 * hang a message except one shared `formError` line at the foot of the dialog — which tells an
 * admin something is wrong but not which of a dozen boxes. This holds a message per field so the
 * error can sit under the box it belongs to.
 *
 * Usage in a component:
 *
 *   readonly err = new FieldErrors();
 *
 *   save(): void {
 *     this.err.reset();
 *     this.err.require('firstName', this.form.firstName, 'First name is required.');
 *     if (this.err.any) return;
 *     ...
 *   }
 *
 * and in the template:
 *
 *   <input class="input" [class.invalid]="err.has('firstName')"
 *          [(ngModel)]="form.firstName" (ngModelChange)="err.clear('firstName')" />
 *   @if (err.has('firstName')) { <div class="field-error">{{ err.get('firstName') }}</div> }
 */
export class FieldErrors {
  private messages: Record<string, string> = {};

  has(field: string): boolean { return !!this.messages[field]; }
  get(field: string): string { return this.messages[field] ?? ''; }
  set(field: string, message: string): void { this.messages[field] = message; }
  /** Clears one field, or every field when called with no argument. */
  clear(field?: string): void {
    if (field === undefined) this.messages = {};
    else delete this.messages[field];
  }
  reset(): void { this.messages = {}; }
  get any(): boolean { return Object.keys(this.messages).length > 0; }

  /** Flags the field when the value is empty or whitespace. Returns true when it is present. */
  require(field: string, value: unknown, message: string): boolean {
    const empty = value === null || value === undefined || String(value).trim() === '';
    if (empty) this.set(field, message);
    return !empty;
  }

  /** Flags the field when `ok` is false. Skips a field that already has a message. */
  check(field: string, ok: boolean, message: string): boolean {
    if (!ok && !this.has(field)) this.set(field, message);
    return ok;
  }

  /**
   * Records a server-side message against a field. The API validates independently of the UI,
   * and a rejection an admin cannot see next to the box it concerns is as good as no message.
   */
  fromServer(field: string, message: string): void { this.set(field, message); }
}

/** Digits, 10 of them — an Indian mobile number as the school forms collect it. */
export function isValidPhone(value: string | null | undefined): boolean {
  return /^\d{10}$/.test((value ?? '').trim());
}

/** Six digits, as issued by India Post. */
export function isValidPincode(value: string | null | undefined): boolean {
  const v = (value ?? '').trim();
  return v === '' || /^\d{6}$/.test(v);
}

export function isValidEmail(value: string | null | undefined): boolean {
  const v = (value ?? '').trim();
  return v === '' || /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(v);
}
