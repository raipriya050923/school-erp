import { Injectable, signal } from '@angular/core';

/**
 * The four appearances, lightest first.
 *
 *   light   neutral, the default
 *   bright  the same ground with the school's colour washed through it
 *   dark    the deep one
 *   dim     a softer dark, for a room that is lit
 */
export type ThemeMode = 'light' | 'bright' | 'dark' | 'dim';

/** Which family a mode belongs to. Most of the stylesheet only needs this. */
export type ThemeScheme = 'light' | 'dark';

const STORAGE_KEY = 'erp.mode';

const MODES: ThemeMode[] = ['light', 'bright', 'dark', 'dim'];
const DARK_MODES: ThemeMode[] = ['dark', 'dim'];

/** What earlier versions wrote. `system` was a choice; now it is only the default. */
const RENAMED: Record<string, ThemeMode> = { midnight: 'dim' };

/**
 * Appearance, for this person on this device.
 *
 * Deliberately not the same thing as the school's palette: the palette is a
 * tenant setting an admin picks for everyone, while whether the screen is dark
 * is a property of the room you are sitting in. One teacher marking attendance
 * at 6am should not have to change what the whole school sees to do it.
 *
 * Two attributes go on <html>, because almost every rule cares only whether it
 * is dark and only a handful care which dark:
 *
 *   data-mode   light | bright | dark | dim   — the exact mode
 *   data-scheme light | dark                  — the family it belongs to
 *
 * Nothing stored means the device decides, which is why there is no "System"
 * button: following the operating system is the starting state, not a fifth
 * thing to pick. Choosing any of the four settles it.
 *
 * A matching snippet in index.html applies both attributes before Angular
 * boots, so the page never flashes light on its way to dark. The two must stay
 * in step.
 */
@Injectable({ providedIn: 'root' })
export class ThemeModeService {
  readonly mode = signal<ThemeMode>('light');

  /** True while nothing has been chosen here and the device is deciding. */
  private following = true;

  constructor() {
    const stored = this.read();
    this.following = stored === null;
    this.apply(stored ?? this.systemDefault());

    // While the person has not chosen, follow the device if it changes under
    // us — which is what a scheduled "dark after sunset" setting does.
    window.matchMedia?.('(prefers-color-scheme: dark)')
      .addEventListener?.('change', () => {
        if (this.following) this.apply(this.systemDefault());
      });
  }

  set(mode: ThemeMode): void {
    this.following = false;
    try { localStorage.setItem(STORAGE_KEY, mode); } catch { /* private mode */ }
    this.apply(mode);
  }

  isChosen(mode: ThemeMode): boolean { return this.mode() === mode; }

  get scheme(): ThemeScheme { return DARK_MODES.includes(this.mode()) ? 'dark' : 'light'; }

  private apply(mode: ThemeMode): void {
    this.mode.set(mode);
    const root = document.documentElement;
    root.setAttribute('data-mode', mode);
    root.setAttribute('data-scheme', DARK_MODES.includes(mode) ? 'dark' : 'light');
  }

  private read(): ThemeMode | null {
    try {
      const v = localStorage.getItem(STORAGE_KEY);
      if (!v) return null;
      const renamed = RENAMED[v];
      if (renamed) {
        // Rewrite it, so the old name does not sit in storage forever.
        try { localStorage.setItem(STORAGE_KEY, renamed); } catch { /* private mode */ }
        return renamed;
      }
      return MODES.includes(v as ThemeMode) ? v as ThemeMode : null;
    } catch { return null; }
  }

  private systemDefault(): ThemeMode {
    return window.matchMedia?.('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  }
}
