import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable, of, shareReplay } from 'rxjs';
import { environment } from '../../environments/environment';

export interface Country { id: number; name: string; iso2: string; phoneCode: string | null; currency: string | null; isActive: boolean; }
export interface StateRegion { id: number; countryId: number; countryName: string | null; name: string; code: string | null; isActive: boolean; }
export interface City { id: number; stateId: number; stateName: string | null; countryName: string | null; name: string; isActive: boolean; }

/**
 * The shared geography master, read side.
 *
 * Lists are cached per parent id — a picker re-opening the same country should not
 * re-fetch its states — and the cache is keyed so switching countries still works.
 */
@Injectable({ providedIn: 'root' })
export class GeographyService {
  private readonly http = inject(HttpClient);
  private readonly base = environment.geographyApi;

  private countries$?: Observable<Country[]>;
  private readonly statesByCountry = new Map<number, Observable<StateRegion[]>>();
  private readonly citiesByState = new Map<number, Observable<City[]>>();

  countries(): Observable<Country[]> {
    this.countries$ ??= this.http.get<Country[]>(`${this.base}/countries`).pipe(shareReplay(1));
    return this.countries$;
  }

  /**
   * States in a country, or every state when `countryId` is null — the student and
   * teacher forms have no country of their own, so they suggest across the board
   * rather than showing nothing.
   */
  states(countryId: number | null): Observable<StateRegion[]> {
    const key = countryId ?? 0;
    let cached = this.statesByCountry.get(key);
    if (!cached) {
      let params = new HttpParams();
      if (countryId) params = params.set('countryId', countryId);
      cached = this.http
        .get<StateRegion[]>(`${this.base}/states`, { params })
        .pipe(shareReplay(1));
      this.statesByCountry.set(key, cached);
    }
    return cached;
  }

  cities(stateId: number | null): Observable<City[]> {
    if (!stateId) return of([]);
    let cached = this.citiesByState.get(stateId);
    if (!cached) {
      cached = this.http
        .get<City[]>(`${this.base}/cities`, { params: new HttpParams().set('stateId', stateId) })
        .pipe(shareReplay(1));
      this.citiesByState.set(stateId, cached);
    }
    return cached;
  }

  /** Drops the cache after a super admin edits the master, so pickers pick up the change. */
  invalidate(): void {
    this.countries$ = undefined;
    this.statesByCountry.clear();
    this.citiesByState.clear();
  }
}
