import { Component, ElementRef, EventEmitter, Input, Output, ViewChild } from '@angular/core';

/**
 * Type-to-search combo box over a fixed list of options.
 *
 * Behaves like a text box (the typed value is emitted as-is) but suggests matching
 * options as you type, so callers that store a plain string — e.g. a student's
 * class name — need no other changes.
 *
 *   <app-autocomplete [options]="classNames" [(value)]="form.className" placeholder="Grade 8" />
 */
@Component({
  selector: 'app-autocomplete',
  standalone: true,
  template: `
    <div class="ac">
      <input
        #box
        class="input"
        [class.invalid]="invalid"
        role="combobox"
        aria-autocomplete="list"
        [attr.aria-expanded]="open"
        autocomplete="off"
        [placeholder]="placeholder"
        [disabled]="disabled"
        [value]="value"
        (input)="onInput(box.value)"
        (focus)="openList()"
        (click)="openList()"
        (blur)="onBlur()"
        (keydown)="onKeydown($event)" />

      <button type="button" class="ac-toggle" tabindex="-1" [disabled]="disabled"
              (mousedown)="$event.preventDefault()" (click)="toggle()" aria-label="Show options">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="6 9 12 15 18 9"/></svg>
      </button>

      @if (open) {
        <div class="ac-menu" role="listbox">
          @for (o of matches; track o; let i = $index) {
            <button type="button" class="ac-option" role="option"
                    [class.active]="i === activeIndex"
                    [attr.aria-selected]="o === value"
                    (mousedown)="$event.preventDefault()"
                    (mouseenter)="activeIndex = i"
                    (click)="pick(o)">{{ o }}</button>
          } @empty {
            <div class="ac-empty">
              {{ value.trim() ? 'No match for "' + value + '"' : (emptyHint || 'No options available') }}
              @if (noMatchHint && value.trim()) { <div class="ac-hint">{{ noMatchHint }}</div> }
            </div>
          }
        </div>
      }
    </div>
  `,
  styles: [`
    .ac { position: relative; }
    .ac .input { width: 100%; padding-right: 32px; }
    .ac-toggle {
      position: absolute; top: 0; right: 0; height: 100%; width: 30px;
      display: flex; align-items: center; justify-content: center;
      background: none; border: none; padding: 0; cursor: pointer; color: var(--muted);
    }
    .ac-toggle svg { width: 16px; height: 16px; }
    .ac-toggle:disabled { cursor: default; opacity: 0.5; }
    .ac-menu {
      position: absolute; top: calc(100% + 4px); left: 0; right: 0; z-index: 60;
      max-height: 220px; overflow-y: auto;
      background: var(--surface); border: 1px solid var(--border);
      border-radius: 10px; box-shadow: var(--shadow-lg); padding: 5px;
    }
    .ac-option {
      display: block; width: 100%; text-align: left;
      padding: 8px 10px; border: none; background: transparent; border-radius: 7px;
      font-family: inherit; font-size: 13px; font-weight: 500; color: var(--ink-2); cursor: pointer;
    }
    .ac-option:hover, .ac-option.active { background: var(--neutral-tint); color: var(--ink); }
    .ac-empty { padding: 9px 10px; font-size: 12.5px; color: var(--muted); }
    .ac-hint { margin-top: 4px; color: var(--crit-text); font-weight: 500; }
  `],
})
export class AutocompleteComponent {
  @Input() options: string[] = [];
  @Input() value = '';
  @Input() placeholder = '';
  @Input() invalid = false;
  @Input() disabled = false;
  /** Shown when the option list itself is empty. */
  @Input() emptyHint = '';
  /** Extra line shown under "No match for …" — e.g. where to go to create the missing record. */
  @Input() noMatchHint = '';
  @Output() valueChange = new EventEmitter<string>();
  /** Fires only when an option is chosen from the list (not on every keystroke). */
  @Output() selected = new EventEmitter<string>();

  @ViewChild('box') private box?: ElementRef<HTMLInputElement>;
  open = false;
  activeIndex = -1;

  /** Options containing the typed text; the full list while the box is empty. */
  get matches(): string[] {
    const q = this.value.trim().toLowerCase();
    if (!q) return this.options;
    return this.options.filter(o => o.toLowerCase().includes(q));
  }

  onInput(v: string): void {
    this.value = v;
    this.open = true;
    this.activeIndex = -1;
    this.valueChange.emit(v);
  }

  openList(): void { if (!this.disabled) this.open = true; }

  toggle(): void {
    this.open = !this.open;
    if (this.open) this.box?.nativeElement.focus();
  }

  /** Deferred so a click on an option lands before the menu unmounts. */
  onBlur(): void { setTimeout(() => { this.open = false; this.activeIndex = -1; }, 120); }

  pick(o: string): void {
    this.value = o;
    this.open = false;
    this.activeIndex = -1;
    this.valueChange.emit(o);
    this.selected.emit(o);
    this.box?.nativeElement.focus();
  }

  onKeydown(e: KeyboardEvent): void {
    const list = this.matches;
    switch (e.key) {
      case 'ArrowDown':
        e.preventDefault();
        this.open = true;
        if (list.length) this.activeIndex = (this.activeIndex + 1) % list.length;
        break;
      case 'ArrowUp':
        e.preventDefault();
        this.open = true;
        if (list.length) this.activeIndex = (this.activeIndex <= 0 ? list.length : this.activeIndex) - 1;
        break;
      case 'Enter':
        if (this.open && this.activeIndex >= 0 && list[this.activeIndex]) {
          e.preventDefault();
          this.pick(list[this.activeIndex]);
        }
        break;
      case 'Escape':
        if (this.open) { e.stopPropagation(); this.open = false; this.activeIndex = -1; }
        break;
    }
  }
}
