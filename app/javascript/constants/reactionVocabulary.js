// Single source of truth for reaction vocabulary in the frontend.
// Mirrors config/locales/en.yml#vulcan.reaction and Reaction::KIND_LABELS
// in Ruby. spec/locales/reaction_keys_spec.rb asserts the three stay in
// sync.

export const REACTION_KINDS = Object.freeze(["up", "down"]);

export const REACTION_LABELS = Object.freeze({
  up: "Thumbs up",
  down: "Thumbs down",
});

export const REACTION_ICONS = Object.freeze({
  up: "hand-thumbs-up",
  down: "hand-thumbs-down",
});
