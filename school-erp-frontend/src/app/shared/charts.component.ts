import { Component, Input } from '@angular/core';
import { DecimalPipe } from '@angular/common';

export interface TrendPoint { label: string; value: number; sub?: string; }
export interface DonutSlice { label: string; value: number; color: string; }

/**
 * Single-series trend line with a filled area, hairline grid and a hover crosshair.
 *
 * Drawn as inline SVG on a fixed viewBox scaled to 100% width — no chart library, so it
 * inherits the page's fonts and theme and adds nothing to the bundle. One series means no
 * legend: the card title names it.
 */
@Component({
  selector: 'app-trend-chart',
  standalone: true,
  template: `
    @if (points.length < 2) {
      <div class="empty">Not enough data yet to plot a trend.</div>
    } @else {
      <svg class="chart" [attr.viewBox]="'0 0 ' + W + ' ' + H" preserveAspectRatio="xMidYMid meet"
           role="img" [attr.aria-label]="ariaLabel"
           (mousemove)="onMove($event)" (mouseleave)="hover = -1">
        <!-- horizontal grid + y labels -->
        @for (t of ticks; track t) {
          <line [attr.x1]="PL" [attr.x2]="W - PR" [attr.y1]="y(t)" [attr.y2]="y(t)" class="grid" />
          <text [attr.x]="PL - 8" [attr.y]="y(t) + 4" class="axis" text-anchor="end">{{ t }}{{ unit }}</text>
        }

        <path [attr.d]="areaPath" class="area" />
        <path [attr.d]="linePath" class="line" />

        <!-- x labels: first, middle and last only, so they never collide -->
        @for (i of xLabelIndexes; track i) {
          <text [attr.x]="x(i)" [attr.y]="H - 8" class="axis"
                [attr.text-anchor]="i === 0 ? 'start' : (i === points.length - 1 ? 'end' : 'middle')">{{ points[i].label }}</text>
        }

        @if (hover >= 0) {
          <line [attr.x1]="x(hover)" [attr.x2]="x(hover)" [attr.y1]="PT" [attr.y2]="H - PB" class="crosshair" />
          <circle [attr.cx]="x(hover)" [attr.cy]="y(points[hover].value)" r="5" class="dot" />
          <g [attr.transform]="'translate(' + tipX + ',' + tipY + ')'">
            <rect class="tip" [attr.width]="tipW" height="42" rx="8" />
            <text class="tip-title" x="12" y="18">{{ points[hover].label }}</text>
            <text class="tip-value" x="12" y="34">{{ points[hover].value | number:'1.0-1' }}{{ unit }}<tspan class="tip-sub">{{ points[hover].sub ? '  ·  ' + points[hover].sub : '' }}</tspan></text>
          </g>
        }
      </svg>
    }
  `,
  imports: [DecimalPipe],
  styles: [`
    .chart { width: 100%; height: auto; display: block; overflow: visible; }
    .grid { stroke: #eef0f4; stroke-width: 1; }
    .axis { font-size: 11px; fill: #9299a5; font-family: inherit; }
    /* Through the accent tokens, so the attendance trend follows the school's palette
       instead of staying blue under a green sidebar. */
    .area { fill: var(--brand-tint); }
    .line { fill: none; stroke: var(--brand); stroke-width: 2; stroke-linejoin: round; stroke-linecap: round; }
    .crosshair { stroke: #c7cdd6; stroke-width: 1; }
    .dot { fill: var(--brand); stroke: #fff; stroke-width: 2; }
    .tip { fill: #111827; opacity: 0.95; }
    .tip-title { font-size: 11px; fill: #d1d5db; font-family: inherit; }
    .tip-value { font-size: 13px; font-weight: 700; fill: #fff; font-family: inherit; }
    .tip-sub { font-size: 11px; font-weight: 500; fill: #9ca3af; }
    .empty { padding: 28px; text-align: center; color: #9299a5; font-size: 13px; }
  `],
})
export class TrendChartComponent {
  @Input() points: TrendPoint[] = [];
  @Input() unit = '%';
  @Input() max = 100;
  @Input() ariaLabel = 'Trend chart';

  readonly W = 720; readonly H = 240;
  readonly PL = 42; readonly PR = 12; readonly PT = 12; readonly PB = 28;
  hover = -1;

  get ticks(): number[] { return [0, 0.25, 0.5, 0.75, 1].map(f => Math.round(this.max * f)); }

  get xLabelIndexes(): number[] {
    const last = this.points.length - 1;
    const mid = Math.floor(last / 2);
    return last <= 1 ? [0, last] : [0, mid, last];
  }

  x(i: number): number {
    const span = Math.max(1, this.points.length - 1);
    return this.PL + (i / span) * (this.W - this.PL - this.PR);
  }
  y(v: number): number {
    const clamped = Math.min(this.max, Math.max(0, v));
    return this.H - this.PB - (clamped / this.max) * (this.H - this.PT - this.PB);
  }

  get linePath(): string {
    return this.points.map((p, i) => `${i ? 'L' : 'M'}${this.x(i).toFixed(1)},${this.y(p.value).toFixed(1)}`).join(' ');
  }
  get areaPath(): string {
    const base = this.H - this.PB;
    return `${this.linePath} L${this.x(this.points.length - 1).toFixed(1)},${base} L${this.x(0).toFixed(1)},${base} Z`;
  }

  /** Tooltip is ~150px wide; flip it left of the crosshair near the right edge. */
  get tipW(): number { return 150; }
  get tipX(): number {
    const px = this.x(this.hover);
    return px + this.tipW + 14 > this.W ? px - this.tipW - 10 : px + 10;
  }
  get tipY(): number { return Math.max(this.PT, this.y(this.points[this.hover].value) - 52); }

  /** Snap to the nearest point so the whole plot area is a hit target. */
  onMove(e: MouseEvent): void {
    const svg = e.currentTarget as SVGSVGElement;
    const rect = svg.getBoundingClientRect();
    const px = ((e.clientX - rect.left) / rect.width) * this.W;
    const span = Math.max(1, this.points.length - 1);
    const step = (this.W - this.PL - this.PR) / span;
    const i = Math.round((px - this.PL) / step);
    this.hover = Math.min(this.points.length - 1, Math.max(0, i));
  }
}

/**
 * Part-to-whole donut with a hero total in the hole and a labelled legend.
 * Every slice carries its label and value in the legend, so colour never carries meaning alone.
 */
@Component({
  selector: 'app-donut-chart',
  standalone: true,
  template: `
    <div class="donut-wrap">
      <svg class="donut" viewBox="0 0 200 200" role="img" [attr.aria-label]="ariaLabel">
        <circle cx="100" cy="100" [attr.r]="R" class="track" [attr.stroke-width]="TH" />
        @for (s of arcs; track s.label) {
          <circle cx="100" cy="100" [attr.r]="R" fill="none" [attr.stroke]="s.color" [attr.stroke-width]="TH"
                  [attr.stroke-dasharray]="s.dash" [attr.stroke-dashoffset]="s.offset"
                  transform="rotate(-90 100 100)" stroke-linecap="butt">
            <title>{{ s.label }}: {{ s.pct }}%</title>
          </circle>
        }
        <text x="100" y="96" class="hole-value" text-anchor="middle">{{ centerValue }}</text>
        <text x="100" y="116" class="hole-label" text-anchor="middle">{{ centerLabel }}</text>
      </svg>

      <ul class="legend">
        @for (s of arcs; track s.label) {
          <li>
            <span class="swatch" [style.background]="s.color"></span>
            <span class="legend-label">{{ s.label }}</span>
            <span class="legend-value">{{ prefix }}{{ s.value | number:'1.0-0' }} <span class="legend-pct">({{ s.pct }}%)</span></span>
          </li>
        }
      </ul>
    </div>
  `,
  imports: [DecimalPipe],
  styles: [`
    .donut-wrap { display: flex; align-items: center; gap: 22px; flex-wrap: wrap; }
    .donut { width: 172px; height: 172px; flex: none; }
    .track { fill: none; stroke: #eef0f4; }
    .hole-value { font-size: 20px; font-weight: 800; fill: #111827; font-family: inherit; }
    .hole-label { font-size: 11px; fill: #9299a5; font-family: inherit; }
    .legend { list-style: none; margin: 0; padding: 0; flex: 1; min-width: 190px; display: flex; flex-direction: column; gap: 12px; }
    .legend li { display: flex; align-items: center; gap: 10px; font-size: 13px; }
    .swatch { width: 10px; height: 10px; border-radius: 50%; flex: none; }
    .legend-label { color: #4b5563; font-weight: 500; }
    .legend-value { margin-left: auto; font-weight: 700; font-variant-numeric: tabular-nums; }
    .legend-pct { font-weight: 500; color: #9299a5; }
  `],
})
export class DonutChartComponent {
  @Input() slices: DonutSlice[] = [];
  @Input() centerValue = '';
  @Input() centerLabel = '';
  @Input() prefix = '';
  @Input() ariaLabel = 'Breakdown';

  readonly R = 76;
  readonly TH = 22;
  private readonly GAP = 2;   // surface-coloured gap between segments

  get total(): number { return this.slices.reduce((sum, s) => sum + Math.max(0, s.value), 0); }

  get arcs(): { label: string; value: number; color: string; pct: number; dash: string; offset: number }[] {
    const circumference = 2 * Math.PI * this.R;
    const total = this.total;
    let consumed = 0;
    return this.slices.map(s => {
      const value = Math.max(0, s.value);
      const share = total ? value / total : 0;
      const len = Math.max(0, share * circumference - (share > 0 ? this.GAP : 0));
      const arc = {
        label: s.label,
        value,
        color: s.color,
        pct: total ? Math.round(share * 1000) / 10 : 0,
        dash: `${len.toFixed(2)} ${(circumference - len).toFixed(2)}`,
        offset: -consumed,
      };
      consumed += share * circumference;
      return arc;
    });
  }
}
