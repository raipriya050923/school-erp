import { Component, Input } from '@angular/core';
import { DomSanitizer, SafeHtml } from '@angular/platform-browser';

/**
 * Lightweight inline-SVG icon set (Lucide-style, 24×24, currentColor stroke).
 * Add a key here and reference it by name — keeps every icon visually consistent.
 */
const PATHS: Record<string, string> = {
  grid: '<rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/>',
  school: '<path d="M3 21h18"/><path d="M5 21V8l7-4 7 4v13"/><path d="M9 21v-6h6v6"/><path d="M12 4v3"/>',
  tag: '<path d="M20.59 13.41 13.42 20.6a2 2 0 0 1-2.83 0L3 13V4a1 1 0 0 1 1-1h9l7.59 7.59a2 2 0 0 1 0 2.82z"/><circle cx="7.5" cy="7.5" r="1.5"/>',
  package: '<path d="M12 2 3 7v10l9 5 9-5V7l-9-5z"/><path d="M3 7l9 5 9-5"/><path d="M12 22V12"/>',
  card: '<rect x="2" y="5" width="20" height="14" rx="2"/><line x1="2" y1="10" x2="22" y2="10"/>',
  ticket: '<path d="M3 8a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2v2a2 2 0 0 0 0 4v2a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-2a2 2 0 0 0 0-4V8z"/>',
  users: '<path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>',
  teacher: '<path d="M22 10v6M2 10l10-5 10 5-10 5z"/><path d="M6 12v5c3 3 9 3 12 0v-5"/>',
  layers: '<polygon points="12 2 2 7 12 12 22 7 12 2"/><polyline points="2 17 12 22 22 17"/><polyline points="2 12 12 17 22 12"/>',
  clipboard: '<path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"/><rect x="8" y="2" width="8" height="4" rx="1"/><path d="M9 14l2 2 4-4"/>',
  chart: '<line x1="3" y1="21" x2="21" y2="21"/><rect x="6" y="11" width="3" height="7"/><rect x="11" y="7" width="3" height="11"/><rect x="16" y="13" width="3" height="5"/>',
  money: '<circle cx="12" cy="12" r="9"/><path d="M9.5 14.5c0 1 1 1.5 2.5 1.5s2.5-.6 2.5-1.8-1-1.6-2.5-2-2.5-.7-2.5-1.9S10.5 8.5 12 8.5s2.5.5 2.5 1.5"/><line x1="12" y1="6.5" x2="12" y2="8.5"/><line x1="12" y1="15.5" x2="12" y2="17.5"/>',
  exam: '<path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><path d="M9 15l2 2 4-4"/>',
  bell: '<path d="M18 8a6 6 0 0 0-12 0c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.7 21a2 2 0 0 1-3.4 0"/>',
  book: '<path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"/><path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"/>',
  calendar: '<rect x="3" y="4" width="18" height="18" rx="2"/><line x1="3" y1="9" x2="21" y2="9"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="16" y1="2" x2="16" y2="6"/>',
  presentation: '<path d="M2 3h20"/><path d="M3 3v11a1 1 0 0 0 1 1h16a1 1 0 0 0 1-1V3"/><path d="M12 15v6M9 21h6"/><path d="M8 11l3-3 2 2 3-4"/>',
  star: '<polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/>',
  user: '<path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/>',
  download: '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/>',
  cap: '<path d="M22 10 12 5 2 10l10 5 10-5z"/><path d="M6 12v5c0 1 2.7 3 6 3s6-2 6-3v-5"/>',
};

@Component({
  selector: 'app-icon',
  standalone: true,
  template: `<span class="ico" [style.width.px]="size" [style.height.px]="size" [innerHTML]="svg"></span>`,
  styles: [`
    .ico { display: inline-flex; align-items: center; justify-content: center; line-height: 0; }
    .ico ::ng-deep svg { width: 100%; height: 100%; }
  `],
})
export class IconComponent {
  private _name = '';
  svg: SafeHtml = '';

  @Input() size = 18;
  @Input() strokeWidth = 2;

  @Input() set name(value: string) {
    this._name = value;
    const inner = PATHS[value] ?? '';
    this.svg = this.sanitizer.bypassSecurityTrustHtml(
      `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="${this.strokeWidth}" stroke-linecap="round" stroke-linejoin="round">${inner}</svg>`,
    );
  }
  get name(): string { return this._name; }

  constructor(private sanitizer: DomSanitizer) {}
}
