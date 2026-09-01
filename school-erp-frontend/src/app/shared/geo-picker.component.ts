import { Component, EventEmitter, Input, OnInit, Output, inject } from '@angular/core';
import { City, Country, GeographyService, StateRegion } from '../core/geography.service';
import { AutocompleteComponent } from './autocomplete.component';

/** What the picker reports back: ids when the master matched, text either way. */
export interface GeoValue {
  countryId: number | null;
  stateId: number | null;
  cityId: number | null;
  country: string;
  state: string;
  city: string;
}

/**
 * Cascading Country → State → City picker over the shared master.
 *
 * Deliberately permissive: the boxes suggest from the master, but anything typed is
 * kept. A value that matches an entry sends its id (the server then stores the FK);
 * a value that matches nothing sends text only, and the server records it with a
 * null FK. That way an admin is never blocked by a town the master has not got yet.
 *
 *   <app-geo-picker [countryId]="f.countryId" [state]="f.state" (changed)="apply($event)" />
 */
@Component({
  selector: 'app-geo-picker',
  standalone: true,
  imports: [AutocompleteComponent],
  template: `
    <div class="form-row">
      @if (showCountry) {
        <div class="field">
          <label>Country @if (required) { <span class="req">*</span> }</label>
          <app-autocomplete
            [options]="countryNames"
            [value]="country"
            [invalid]="invalidCountry"
            placeholder="Start typing…"
            (valueChange)="onCountry($event)" />
        </div>
      }
      <div class="field">
        <label>State / Province @if (required) { <span class="req">*</span> }</label>
        <app-autocomplete
          [options]="stateNames"
          [value]="state"
          [invalid]="invalidState"
          [placeholder]="statePlaceholder"
          (valueChange)="onState($event)" />
      </div>
      <div class="field">
        <label>City @if (required) { <span class="req">*</span> }</label>
        <app-autocomplete
          [options]="cityNames"
          [value]="city"
          [invalid]="invalidCity"
          [placeholder]="cityPlaceholder"
          (valueChange)="onCity($event)" />
      </div>
    </div>
    @if (unmatched.length) {
      <div class="field-hint">
        Not in the master list: {{ unmatched.join(', ') }}. It will be saved as typed —
        ask the platform admin to add it so everyone gets the same spelling.
      </div>
    }
  `,
})
export class GeoPickerComponent implements OnInit {
  /** Hidden on student/teacher forms, which inherit the school's country. */
  @Input() showCountry = true;
  @Input() required = false;
  @Input() invalidCountry = false;
  @Input() invalidState = false;
  @Input() invalidCity = false;

  @Input() countryId: number | null = null;
  @Input() stateId: number | null = null;
  @Input() cityId: number | null = null;
  @Input() country = '';
  @Input() state = '';
  @Input() city = '';

  @Output() changed = new EventEmitter<GeoValue>();

  private readonly geo = inject(GeographyService);
  private countries: Country[] = [];
  private states: StateRegion[] = [];
  private cities: City[] = [];

  ngOnInit(): void {
    this.geo.countries().subscribe(list => {
      this.countries = list;
      // Editing an existing record: fill the name from the id it was saved with.
      if (this.countryId && !this.country) {
        this.country = list.find(c => c.id === this.countryId)?.name ?? '';
      }
      this.loadStates();
    });
  }

  get countryNames(): string[] { return this.countries.map(c => c.name); }
  get stateNames(): string[] { return this.states.map(s => s.name); }
  get cityNames(): string[] { return this.cities.map(c => c.name); }

  get statePlaceholder(): string {
    return this.states.length ? 'Start typing…' : 'Type a state';
  }
  get cityPlaceholder(): string {
    if (!this.stateId) return 'Choose a state first';
    return this.cities.length ? 'Start typing…' : 'Type a city';
  }

  /** Names typed that the master does not know — surfaced so the admin is not surprised. */
  get unmatched(): string[] {
    const out: string[] = [];
    if (this.showCountry && this.country && !this.countryId) out.push(this.country);
    if (this.state && !this.stateId) out.push(this.state);
    if (this.city && !this.cityId) out.push(this.city);
    return out;
  }

  onCountry(value: string): void {
    this.country = value;
    this.countryId = this.matchId(this.countries, value);
    // A different country invalidates whatever was chosen below it.
    this.stateId = null; this.state = '';
    this.cityId = null; this.city = '';
    this.cities = [];
    this.loadStates();
    this.emit();
  }

  onState(value: string): void {
    this.state = value;
    this.stateId = this.matchId(this.states, value);
    this.cityId = null; this.city = '';
    this.loadCities();
    this.emit();
  }

  onCity(value: string): void {
    this.city = value;
    this.cityId = this.matchId(this.cities, value);
    this.emit();
  }

  private loadStates(): void {
    this.geo.states(this.showCountry ? this.countryId : null).subscribe(list => {
      this.states = list;
      if (this.stateId && !this.state) {
        this.state = list.find(s => s.id === this.stateId)?.name ?? '';
      }
      this.loadCities();
    });
  }

  private loadCities(): void {
    this.geo.cities(this.stateId).subscribe(list => {
      this.cities = list;
      if (this.cityId && !this.city) {
        this.city = list.find(c => c.id === this.cityId)?.name ?? '';
      }
    });
  }

  /** Exact, case-insensitive name match, or null when the master has no such entry. */
  private matchId(list: { id: number; name: string }[], value: string): number | null {
    const q = value.trim().toLowerCase();
    if (!q) return null;
    return list.find(x => x.name.toLowerCase() === q)?.id ?? null;
  }

  private emit(): void {
    this.changed.emit({
      countryId: this.countryId, stateId: this.stateId, cityId: this.cityId,
      country: this.country, state: this.state, city: this.city,
    });
  }
}
