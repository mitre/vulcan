# Toast Contract

Every JSON mutation endpoint in Vulcan returns a canonical toast object for user-facing feedback. This contract is enforced at construction time by the `Toast` value object.

## The Shape

```json
{
  "toast": {
    "title": "Short title.",
    "message": ["Detail line 1.", "Detail line 2."],
    "variant": "success"
  }
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `title` | string | yes | Short heading (e.g. "Component added.") |
| `message` | array of strings | yes | Detail lines. Always an array, never a bare string. |
| `variant` | string | yes | Bootstrap variant: `success`, `danger`, `warning`, `info` |

## Backend: Creating Toasts

### Option 1: `render_toast` helper (preferred for simple responses)

```ruby
render_toast(title: 'Component added.',
             message: 'Successfully added component.',
             variant: 'success', status: :ok)
```

`render_toast` is defined in `ApplicationController`. It wraps `Toast.new` and renders JSON with the correct status code. The `message` parameter accepts a string or array — `Toast.new` normalizes it to an array.

### Option 2: `Toast.new` inline (for multi-key responses)

```ruby
render json: {
  toast: Toast.new(title: 'Token revoked.', message: ["'#{name}' revoked."], variant: 'success'),
  user: UserBlueprint.render_as_hash(user)
}, status: :ok
```

Use this when the response includes data alongside the toast (e.g. `toast` + `user`, `toast` + `summary`).

### The `Toast` Value Object

`app/models/toast.rb` enforces the contract at construction time:

- `message` is always wrapped in `Array()` and frozen
- `variant` defaults to `'danger'` if not specified
- `nil` message becomes `[]`
- `as_json` returns string-keyed hash (matches what `render json:` produces)

## Frontend: Consuming Toasts

`AlertMixin.vue` processes toast responses in `alertOrNotifyResponse()`:

1. Extracts `response.data.toast` or `response.response.data.toast` (for error responses)
2. Expects a plain object with `title`, `message` (array), `variant`
3. Joins the `message` array via `arrayToMessage()` for display in `$bvToast`

The string-handling branch was removed in PR #717. If a backend returns `toast: "string"` instead of the canonical object, the toast silently fails to render and an error appears in the console.

`Toaster.vue` handles Rails flash messages (non-AJAX page loads) by wrapping the flash string into the canonical shape: `message: [this.notice]`.

## Rules

1. **Never hand-build a toast hash** — always use `Toast.new()` or `render_toast`
2. **Never return `toast: "string"`** — the frontend expects the object shape
3. **Message is always an array** — even for single-line messages
4. **Use `render_toast` for simple responses** — less boilerplate
5. **Use `Toast.new` inline for multi-key responses** — when returning toast + data

## Testing

The `ToastResponse` OpenAPI schema validates the shape in contract tests. The shared example `it_behaves_like 'a canonical toast response'` verifies any endpoint returns the correct structure.

```ruby
expect(response.parsed_body['toast']['message']).to include(a_string_including('expected text'))
expect(response.parsed_body['toast']['variant']).to eq('success')
```

Use `a_string_including()` for substring matches on the message array — `include('text')` does exact element matching which fails on arrays.
