import { Component } from '@angular/core';
import { RouterOutlet } from '@angular/router';
import { environment } from '../environments/environment';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [RouterOutlet],
  template: '<router-outlet />',
})
export class AppComponent {
  constructor() {
    // Stamped once, at the root, so stylesheets can differ per client without a
    // component ever branching on which client it is. The brand layer in
    // angular.json scopes its tokens to this attribute.
    document.documentElement.setAttribute('data-brand', environment.brand);
  }
}
