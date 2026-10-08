import { Component, Input } from '@angular/core';
import { IconComponent } from './icon.component';

/**
 * A drifting field of school glyphs, for the background of the auth pages.
 *
 * Everything is inline SVG from the app's own icon set — no Lottie, no GIFs, no
 * CDN. A login screen is the one page that must paint before anything else is
 * warm, so it earns no network requests, and drawing from `app-icon` keeps the
 * decoration in the same visual language as the rest of the product.
 *
 * Only `transform` and `opacity` are animated, so the whole layer stays on the
 * compositor and never triggers layout. It is `aria-hidden` and click-through:
 * it decorates, it does not inform, and a screen reader announcing "book, bell,
 * bus, calendar" before the username field would be pure noise.
 */
interface Doodle {
  /** Key from the shared icon set. */
  readonly name: string;
  readonly top: string;
  readonly left: string;
  readonly size: number;
  /** 1-3, picking one of the three drift paths so the field never pulses in unison. */
  readonly path: 1 | 2 | 3;
  readonly delay: string;
  readonly duration: string;
  readonly opacity: number;
  readonly tint: string;
}

/* Positions hug the outer bands and the top strip, and deliberately avoid the
   middle. The copy sets in a 508px column centred in a panel around 755px wide,
   which means roughly 16%-84% of the width sits behind text - and now that the
   glyphs are strong enough to see, anything drifting through there competes with
   the headline instead of framing it. The bottom is left clear for the figures. */
const DOODLES: readonly Doodle[] = [
  /* left band */
  { name: 'cap',          top: '9%',  left: '4%',  size: 42, path: 1, delay: '0s',    duration: '11s', opacity: 0.16, tint: '#2563eb' },
  { name: 'presentation', top: '29%', left: '2%',  size: 30, path: 2, delay: '-7s',   duration: '15s', opacity: 0.12, tint: '#0ca30c' },
  { name: 'bell',         top: '50%', left: '5%',  size: 30, path: 3, delay: '-1.2s', duration: '10s', opacity: 0.14, tint: '#7c3aed' },
  { name: 'chart',        top: '70%', left: '2%',  size: 30, path: 2, delay: '-5.5s', duration: '12s', opacity: 0.12, tint: '#2563eb' },
  { name: 'teacher',      top: '19%', left: '13%', size: 24, path: 3, delay: '-4.4s', duration: '13s', opacity: 0.11, tint: '#1d4ed8' },

  /* right band */
  { name: 'book',         top: '11%', left: '88%', size: 36, path: 2, delay: '-2.5s', duration: '13s', opacity: 0.15, tint: '#7c3aed' },
  { name: 'school',       top: '33%', left: '90%', size: 40, path: 1, delay: '-6s',   duration: '12s', opacity: 0.14, tint: '#1d4ed8' },
  { name: 'calendar',     top: '55%', left: '87%', size: 34, path: 3, delay: '-4s',   duration: '14s', opacity: 0.13, tint: '#2563eb' },
  { name: 'users',        top: '73%', left: '91%', size: 26, path: 2, delay: '-1.8s', duration: '11s', opacity: 0.12, tint: '#0ca30c' },

  /* top strip, clear of the copy */
  { name: 'star',         top: '3%',  left: '30%', size: 22, path: 3, delay: '-3.4s', duration: '9s',  opacity: 0.13, tint: '#fab219' },
  { name: 'exam',         top: '2%',  left: '58%', size: 24, path: 1, delay: '-8s',   duration: '13s', opacity: 0.11, tint: '#2563eb' },
  { name: 'star',         top: '6%',  left: '73%', size: 18, path: 2, delay: '-2s',   duration: '10s', opacity: 0.10, tint: '#fab219' },
];

@Component({
  selector: 'app-school-doodles',
  standalone: true,
  imports: [IconComponent],
  template: `
    <div class="doodle-layer" aria-hidden="true">
      @for (d of doodles; track $index) {
        <span class="doodle" [class]="'doodle p' + d.path"
              [style.top]="d.top" [style.left]="d.left"
              [style.color]="d.tint" [style.opacity]="d.opacity"
              [style.animationDelay]="d.delay" [style.animationDuration]="d.duration">
          <!-- strokeWidth before name on purpose: IconComponent builds its SVG string
               inside the "name" setter, so any input declared after it is read too
               late and silently ignored. Angular assigns inputs in template order. -->
          <app-icon [strokeWidth]="1.5" [size]="d.size" [name]="d.name" />
        </span>
      }
    </div>
  `,
  styles: [`
    .doodle-layer {
      position: absolute;
      inset: 0;
      overflow: hidden;
      pointer-events: none;   /* never steals a click from the form behind it */
      z-index: 0;
      animation: layer-in 1400ms ease both;
    }

    .doodle {
      position: absolute;
      display: block;
      line-height: 0;
      animation-timing-function: ease-in-out;
      animation-iteration-count: infinite;
    }

    /* Three drift paths, assigned round-robin. One shared keyframe would make the
       whole field breathe in lockstep, which reads as a glitch rather than motion. */
    .doodle.p1 { animation-name: drift-1; }
    .doodle.p2 { animation-name: drift-2; }
    .doodle.p3 { animation-name: drift-3; }

    @keyframes drift-1 {
      0%, 100% { transform: translate3d(0, 0, 0) rotate(0deg); }
      50%      { transform: translate3d(0, -20px, 0) rotate(5deg); }
    }
    @keyframes drift-2 {
      0%, 100% { transform: translate3d(0, 0, 0) rotate(0deg); }
      50%      { transform: translate3d(8px, 16px, 0) rotate(-6deg); }
    }
    @keyframes drift-3 {
      0%, 100% { transform: translate3d(0, 0, 0) scale(1); }
      50%      { transform: translate3d(-10px, -12px, 0) scale(1.08); }
    }

    @keyframes layer-in { from { opacity: 0; } to { opacity: 1; } }

    /* Motion here is pure decoration, so it is the first thing to go when the
       reader has asked the OS for less of it. The glyphs stay; they just settle. */
    @media (prefers-reduced-motion: reduce) {
      .doodle-layer, .doodle { animation: none; }
    }

    /* On a phone the panel is short and the glyphs crowd the copy. */
    @media (max-width: 900px) {
      .doodle-layer { display: none; }
    }
  `],
})
export class SchoolDoodlesComponent {
  /** Override the default field if a page wants a sparser one. */
  @Input() doodles: readonly Doodle[] = DOODLES;
}
