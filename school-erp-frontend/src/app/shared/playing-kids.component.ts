import { Component } from '@angular/core';

/**
 * Four children along the bottom of the auth panel: two at play, two at work.
 * One bounces a ball, one reads cross-legged, one writes at a desk, one flies
 * a kite — a school day is both halves, and a scene of nothing but play sells
 * an administration product oddly.
 *
 * Hand-drawn inline SVG, for the same reason the doodle field is — a login page
 * should not fetch artwork, and stock illustration carries a licence question
 * this does not. Flat geometric shapes keep the figures legible at 100px tall.
 *
 * Layout safety: the figures anchor to the bottom edge, and the login hero
 * reserves matching bottom padding so the copy column can never run into them.
 * Both the band and the reserved space drop away together on short or narrow
 * viewports, where there is no room for a scene.
 */
@Component({
  selector: 'app-playing-kids',
  standalone: true,
  template: `
    <div class="kids" aria-hidden="true">

      <!-- ---- bouncing a ball ---- -->
      <svg class="kid kid-ball" viewBox="0 0 96 104" fill="none">
        <ellipse class="shadow" cx="40" cy="99" rx="19" ry="4" />
        <rect x="31" y="66" width="8" height="26" rx="4" fill="#334155" />
        <rect x="42" y="66" width="8" height="26" rx="4" fill="#334155" />
        <rect x="28" y="90" width="14" height="7" rx="3.5" fill="#1f2937" />
        <rect x="40" y="90" width="14" height="7" rx="3.5" fill="#1f2937" />
        <rect x="28" y="36" width="25" height="33" rx="10" fill="#2563eb" />
        <rect x="22" y="40" width="7" height="22" rx="3.5" fill="#f2b58c" />
        <rect class="arm" x="52" y="38" width="7" height="21" rx="3.5" fill="#f2b58c" />
        <circle cx="40" cy="24" r="13" fill="#f2b58c" />
        <path d="M27 23a13 13 0 0 1 26 0c0-9-5-13-13-13s-13 4-13 13z" fill="#3f3a36" />
        <circle cx="35" cy="25" r="1.6" fill="#1f2937" />
        <circle cx="45" cy="25" r="1.6" fill="#1f2937" />
        <path d="M36 30c1.6 1.7 6.4 1.7 8 0" stroke="#1f2937" stroke-width="1.6" stroke-linecap="round" />
        <g class="ball">
          <circle cx="74" cy="86" r="11" fill="#f59e0b" />
          <path d="M74 75v22M63 86h22" stroke="#b45309" stroke-width="1.6" stroke-linecap="round" />
        </g>
      </svg>

      <!-- ---- reading, sitting cross-legged ---- -->
      <svg class="kid kid-read" viewBox="0 0 96 104" fill="none">
        <ellipse class="shadow" cx="46" cy="99" rx="24" ry="4" />
        <!-- folded legs read as one low, wide mass rather than two limbs -->
        <path d="M22 96c0-9 11-14 24-14s24 5 24 14z" fill="#334155" />
        <rect x="34" y="50" width="25" height="34" rx="10" fill="#0ca30c" />
        <!-- both arms angle down to hold the book open in the lap -->
        <rect x="26" y="58" width="7" height="22" rx="3.5" fill="#d99a6c" transform="rotate(18 29 69)" />
        <rect x="60" y="58" width="7" height="22" rx="3.5" fill="#d99a6c" transform="rotate(-18 63 69)" />
        <g class="reader-head">
          <circle cx="46" cy="38" r="13" fill="#d99a6c" />
          <path d="M33 37a13 13 0 0 1 26 0c0-9-5-13-13-13s-13 4-13 13z" fill="#2a2521" />
          <!-- eyes drawn as downward arcs: the child is looking at the page -->
          <path d="M39 41c1.2-1.6 3.4-1.6 4.6 0M49 41c1.2-1.6 3.4-1.6 4.6 0"
                stroke="#1f2937" stroke-width="1.6" stroke-linecap="round" />
          <path d="M43 47c1.5 1.4 5 1.4 6.5 0" stroke="#1f2937" stroke-width="1.5" stroke-linecap="round" />
        </g>
        <g class="book">
          <path d="M23 79 46 72v16l-23 7z" fill="#fdfdfe" stroke="#cbd5e1" stroke-width="1.4" stroke-linejoin="round" />
          <path d="M69 79 46 72v16l23 7z" fill="#fdfdfe" stroke="#cbd5e1" stroke-width="1.4" stroke-linejoin="round" />
          <path class="page" d="M46 72l23 7v16l-23-7z" fill="#eef2f7" stroke="#cbd5e1" stroke-width="1.2" stroke-linejoin="round" />
          <path d="M46 72v16" stroke="#94a3b8" stroke-width="1.6" stroke-linecap="round" />
        </g>
      </svg>

      <!-- ---- writing at a desk ---- -->
      <svg class="kid kid-write" viewBox="0 0 118 108" fill="none">
        <ellipse class="shadow" cx="58" cy="103" rx="30" ry="4" />
        <!-- child first, so the desk overlaps and the figure sits behind it -->
        <rect x="40" y="46" width="26" height="32" rx="10" fill="#7c3aed" />
        <circle cx="53" cy="32" r="13" fill="#f2b58c" />
        <path d="M40 31a13 13 0 0 1 26 0c0-9-5-13-13-13s-13 4-13 13z" fill="#4a3b2a" />
        <path d="M46 35c1.2-1.6 3.4-1.6 4.6 0M56 35c1.2-1.6 3.4-1.6 4.6 0"
              stroke="#1f2937" stroke-width="1.6" stroke-linecap="round" />
        <path d="M50 41c1.5 1.4 5 1.4 6.5 0" stroke="#1f2937" stroke-width="1.5" stroke-linecap="round" />
        <!-- far arm steadies the page -->
        <rect x="32" y="52" width="7" height="20" rx="3.5" fill="#f2b58c" transform="rotate(22 35 62)" />
        <!-- desk -->
        <rect x="18" y="72" width="82" height="7" rx="2.5" fill="#c88f5d" />
        <rect x="24" y="79" width="6" height="23" rx="2" fill="#a97445" />
        <rect x="88" y="79" width="6" height="23" rx="2" fill="#a97445" />
        <rect x="34" y="66" width="26" height="7" rx="1.5" fill="#fdfdfe" stroke="#cbd5e1" stroke-width="1.2" />
        <!-- writing hand and pencil travel together across the page -->
        <g class="writing">
          <rect x="62" y="54" width="7" height="18" rx="3.5" fill="#f2b58c" transform="rotate(-16 65 63)" />
          <path d="M74 52l5 4-12 14-6 1 2-6z" fill="#fab219" />
          <path d="M63 65l-2 5 6-1z" fill="#3f3a36" />
        </g>
      </svg>

      <!-- ---- flying a kite ---- -->
      <svg class="kid kid-kite" viewBox="0 0 110 132" fill="none">
        <ellipse class="shadow" cx="34" cy="127" rx="18" ry="4" />
        <rect x="26" y="94" width="8" height="24" rx="4" fill="#1f2937" />
        <rect x="36" y="94" width="8" height="24" rx="4" fill="#1f2937" />
        <rect x="23" y="116" width="14" height="7" rx="3.5" fill="#334155" />
        <rect x="35" y="116" width="14" height="7" rx="3.5" fill="#334155" />
        <rect x="23" y="64" width="25" height="33" rx="10" fill="#2563eb" />
        <rect x="17" y="68" width="7" height="21" rx="3.5" fill="#d99a6c" />
        <rect x="46" y="48" width="7" height="24" rx="3.5" fill="#d99a6c" transform="rotate(20 49 60)" />
        <circle cx="35" cy="52" r="13" fill="#d99a6c" />
        <path d="M22 51a13 13 0 0 1 26 0c0-9-5-13-13-13s-13 4-13 13z" fill="#2a2521" />
        <circle cx="31" cy="53" r="1.6" fill="#1f2937" />
        <circle cx="41" cy="53" r="1.6" fill="#1f2937" />
        <path d="M32 58c1.5 1.7 6 1.7 7.5 0" stroke="#1f2937" stroke-width="1.6" stroke-linecap="round" />
        <g class="kite">
          <path d="M55 46C66 36 74 28 82 20" stroke="#94a3b8" stroke-width="1.4" stroke-linecap="round" />
          <path d="M82 4 96 18 82 32 68 18z" fill="#ef4444" />
          <path d="M82 4v28M68 18h28" stroke="#b91c1c" stroke-width="1.2" />
          <path d="M82 32c-3 4 3 6 0 10" stroke="#f59e0b" stroke-width="1.8" stroke-linecap="round" />
        </g>
      </svg>
    </div>
  `,
  styles: [`
    .kids {
      position: absolute;
      left: 0; right: 0; bottom: 0;
      height: 132px;
      pointer-events: none;   /* decoration must never intercept a click */
      z-index: 0;
      animation: kids-in 900ms ease both;
    }

    .kid { position: absolute; bottom: 0; height: auto; }
    .kid-ball  { left: 4%;  width: 86px; }
    .kid-read  { left: 26%; width: 92px; }
    .kid-write { left: 51%; width: 112px; }
    .kid-kite  { right: 4%; width: 104px; }

    .shadow { fill: #0f172a; opacity: 0.10; }

    /* ---- ball: a real bounce needs different easing each way. Gravity
           accelerates on the way down and decelerates on the way up; a single
           ease-in-out gives a floaty, weightless ball. ---- */
    .ball {
      animation: bounce 1100ms infinite;
      transform-origin: 74px 86px;
    }
    @keyframes bounce {
      0%   { transform: translateY(0)     scaleY(0.88) scaleX(1.12); }
      12%  { transform: translateY(-14px) scaleY(1) scaleX(1); animation-timing-function: cubic-bezier(0.33, 0, 0.67, 0.4); }
      50%  { transform: translateY(-46px) scaleY(1.04) scaleX(0.96); animation-timing-function: cubic-bezier(0.33, 0.6, 0.67, 1); }
      88%  { transform: translateY(-14px) scaleY(1) scaleX(1); }
      100% { transform: translateY(0)     scaleY(0.88) scaleX(1.12); }
    }

    /* The hand keeps time with the ball rather than moving on its own clock. */
    .arm {
      animation: tap 1100ms ease-in-out infinite;
      transform-origin: 55px 40px;
    }
    @keyframes tap {
      0%, 100% { transform: rotate(6deg); }
      50%      { transform: rotate(-16deg); }
    }

    /* ---- reader: a page narrows to nothing and opens again, hinged on the
           spine, which is what a turning page does when seen side-on ---- */
    .page {
      animation: page-turn 5.5s ease-in-out infinite;
      transform-origin: 46px 80px;
    }
    @keyframes page-turn {
      0%, 62%   { transform: scaleX(1); }
      78%       { transform: scaleX(0.04); }
      94%, 100% { transform: scaleX(1); }
    }
    /* Eyes track down the page and back to the top of the next one. */
    .reader-head {
      animation: read-bob 5.5s ease-in-out infinite;
      transform-origin: 46px 50px;
    }
    @keyframes read-bob {
      0%, 100% { transform: rotate(-2deg) translateY(0); }
      45%      { transform: rotate(2deg)  translateY(2px); }
      78%      { transform: rotate(-3deg) translateY(-1px); }
    }

    /* ---- writer: the hand crosses the page, then jumps back to start the
           next line, rather than sliding smoothly both ways ---- */
    .writing {
      animation: write 3.2s infinite;
      transform-origin: 65px 63px;
    }
    @keyframes write {
      0%   { transform: translate(0, 0) rotate(0deg); }
      70%  { transform: translate(-17px, 1px) rotate(-4deg); animation-timing-function: ease-in-out; }
      78%  { transform: translate(2px, 3px) rotate(2deg); }
      100% { transform: translate(0, 0) rotate(0deg); }
    }

    /* ---- kite: hinged at the child's hand, so the string stays attached ---- */
    .kite {
      animation: sway 5s ease-in-out infinite;
      transform-origin: 55px 46px;
    }
    @keyframes sway {
      0%, 100% { transform: rotate(-5deg) translateY(0); }
      50%      { transform: rotate(6deg)  translateY(-5px); }
    }

    @keyframes kids-in { from { opacity: 0; transform: translateY(14px); } to { opacity: 1; transform: none; } }

    @media (prefers-reduced-motion: reduce) {
      .kids, .ball, .arm, .page, .reader-head, .writing, .kite { animation: none; }
    }

    /* No room for a scene on a short or narrow panel. The hero drops its
       reserved bottom padding at the same breakpoints, so nothing is left
       holding space for figures that are not drawn. */
    @media (max-width: 900px), (max-height: 780px) {
      .kids { display: none; }
    }

    /* Four figures need more width than three. Below this the two at play keep
       the ends of the scene and the two at work step out. */
    @media (max-width: 1180px) {
      .kid-read, .kid-write { display: none; }
    }
  `],
})
export class PlayingKidsComponent {}
