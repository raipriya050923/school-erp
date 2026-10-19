import { Component } from '@angular/core';
import { environment } from '../../environments/environment';
import { MastheadShellComponent } from './shells/masthead-shell.component';
import { RailShellComponent } from './shells/rail-shell.component';

// Re-exported so the route files keep importing NavItem from one place.
export type { NavItem } from './shells/masthead-shell.component';

/**
 * Picks the shell this build wears.
 *
 * Every portal routes to this one component, so the four route files know nothing
 * about which client they are building for. The shells differ only in where the
 * navigation lives — one puts it in a left rail, the other across the top — and
 * both end in the same <router-outlet>, so all 34 pages are written once and
 * rendered by either.
 *
 * The choice is a build-time constant rather than a runtime setting: the two
 * clients are two products with their own domains, and shipping both shells to
 * both of them would mean every page carrying CSS it can never use.
 */
@Component({
  selector: 'app-portal-layout',
  standalone: true,
  imports: [MastheadShellComponent, RailShellComponent],
  template: `
    @if (useRail) { <app-rail-shell /> } @else { <app-masthead-shell /> }
  `,
})
export class PortalLayoutComponent {
  readonly useRail = environment.shell === 'rail';
}
