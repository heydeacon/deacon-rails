# deacon-rails

[Deacon](https://heydeacon.com) is an AI support agent that answers questions from your own docs and content, and says when it doesn't know. This gem adds its chat widget to every page of a Rails app.

You need a Deacon account, and there's a free plan.

## Install

```sh
bundle add deacon-rails
```

## Set it up

Put the helper in the `<head>` of `app/views/layouts/application.html.erb`:

```erb
<head>
  <%# ...the rest of your head %>
  <%= javascript_importmap_tags %>
  <%= deacon_widget_tag %>
</head>
```

Then give it your key, in the `DEACON_KEY` environment variable:

```sh
DEACON_KEY=pk_your_widget_key
```

Or in an initializer, such as `config/initializers/deacon.rb`, which wins over `DEACON_KEY`:

```ruby
Rails.application.config.deacon.key = "pk_your_widget_key"
```

To find your key, open Install from the button at the top of the Deacon dashboard. The snippet there has it in `data-key`, and it starts with `pk_`. It isn't a secret: every visitor's browser reads it. If the key is missing, the helper prints nothing and logs a warning that says why, so your pages still render. An option of the wrong type raises an `ArgumentError` that says why.

Deacon only runs on the sites listed on Install. A listed domain covers its subdomains, so `example.com` covers `app.example.com`. If your app lives somewhere else, such as `example.fly.dev`, add that address on Install too.

When you run `bin/rails server`, Install notices the widget on `localhost:3000` and lets you add it in one click. Chats on localhost don't count towards your plan.

## Who is signed in

When someone is signed in to your app, the tag tells Deacon their id, email and name, so their conversations show who they are. To have Deacon trust that, rather than take the page's word for it, give the gem your secret in the `DEACON_SECRET` environment variable:

```sh
DEACON_SECRET=deacon_identity_your_secret
```

To make one, open Install in Deacon and use Make a secret under Verify who's signed in. You see it once. The key the gem signs with is the whole string exactly as Install shows it, `deacon_identity_` and all, not decoded or shortened. Keep it on the server: unlike the `pk_` key, anyone who has it can tell Deacon they are any of your users.

With the secret set, the gem does the rest:

- Above the widget's tag it prints `window.deaconUser`, with the user's id, email and name and a `token` function.
- When the chat opens, `token` posts to `/deacon/token`, a route the gem adds to your app. It answers with a token signed with `DEACON_SECRET` that names the user and this chat and lasts 10 minutes. With nobody signed in, or no secret, it answers 204 and signs nothing. Its answers are never cached and carry no CORS headers, so only your own pages can read them.
- On a page where nobody is signed in, it prints `window.deaconUser = null` and `Deacon.identify(null)` instead, so signing out ends what Deacon knew about the last person, and the next person on that computer starts fresh.

If your layout sets `window.deaconUser` itself, from an earlier version of Deacon's install guide, take that script out: the tag prints it now.

### Finding the user

The gem asks your controllers for `current_user`, which Devise and most sign-in gems provide. Rails 8's built-in authentication has no `current_user`, so tell the gem how to find the user with a lambda, which runs inside the controller:

```ruby
Rails.application.config.deacon.current_user = -> { Current.user if authenticated? }
```

Or give it the name of a method, such as `:current_member`. The id it sends is the user's `id`, so it must name one person across your whole app. The email is the user's `email`, or `email_address` with Rails 8's built-in authentication, and the name is their `name`, when they have one.

The token route's controller inherits your `ApplicationController`, so it finds the user just as your pages do. It skips `require_authentication` (Rails 8) and `authenticate_user!` (Devise), so someone who has signed out gets a 204 rather than a redirect to your sign-in page. If your `ApplicationController` requires sign-in under another name, skip that for the route too:

```ruby
Rails.application.config.to_prepare do
  Deacon::Rails::TokensController.skip_before_action :require_login
end
```

### CSRF

The route checks your app's CSRF token, as every other POST in your app does, and the `token` function sends it in the `X-CSRF-Token` header. The route changes nothing, and with no CORS headers another site couldn't read its answer, so exempting it would be safe too. Keeping the check means a page on another site can't get your server to sign anything at all, and nothing in your app is exempt from it.

### Staging and development

Give staging its own Deacon team, with its own key and secret, or leave `DEACON_SECRET` unset there so the route answers 204. Never copy production's secret to staging or a laptop: whoever runs that server could sign a token for any of your users.

### Signing in in the browser

If your app learns who is signed in in the browser, such as a React front end on a JSON API, the server sees nobody on every page, and the sign-out line would start everyone afresh on every page load. Turn it off, and tell Deacon from your own code with `Deacon.identify`, as [Deacon's install guide](https://heydeacon.com/agent/install.md) shows:

```ruby
Rails.application.config.deacon.signed_in = false
```

## Options

Set them on `config.deacon`, in an initializer or in `config/application.rb`.

| Option         | Type              | Default        | What it does |
| -------------- | ----------------- | -------------- | ------------ |
| `key`          | string            | `DEACON_KEY`   | Your Deacon key. |
| `context`      | hash              | none           | Details Deacon takes into account when it answers, the same on every page, such as `{ product: "api", docs_version: "3.2" }`. Up to 12 keys, each value a string, number or boolean. Anyone can read them in the page's HTML, so never put a secret here. |
| `page_views`   | boolean           | `true`         | The same script counts visits for Deacon's website analytics. Set this to `false` to send no page views or JavaScript errors from your app. Chat still works. |
| `signed_in`    | boolean           | `true`         | Tell Deacon who is signed in, and sign them out of Deacon on pages where nobody is. Set this to `false` if your app signs people in in the browser. |
| `current_user` | symbol or lambda  | `current_user` | How to find the signed-in user: the name of a method on your controllers, or a lambda that runs inside one. |

```ruby
Rails.application.config.deacon.key = "pk_your_widget_key"
Rails.application.config.deacon.context = { product: "api", docs_version: "3.2" }
Rails.application.config.deacon.page_views = false
Rails.application.config.deacon.current_user = -> { Current.user if authenticated? }
```

The secret has no option, only `DEACON_SECRET`, so it stays out of your code.

## Turbo

Turbo Drive swaps the `<body>` on each visit and keeps the `<head>`, so in the head the tag runs once. Deacon puts its chat on `<html>`, outside the body, so the widget stays in place as people move between pages. The signed-in script is different on every page, so Turbo runs it on each visit, and a sign-in or sign-out without a full page load still reaches Deacon.

## Content Security Policy

If your app gives each request a nonce, with `config.content_security_policy_nonce_generator`, the tag carries it, on the signed-in script too. With Turbo, also put `<%= csp_meta_tag %>` in the head, which Turbo reads to run the signed-in script again on each visit. The policy also needs Deacon's address, `https://heydeacon.com`, in `script-src`, `connect-src` and `frame-src`, and `'unsafe-inline'` in `style-src`, because the widget writes its styles where a nonce can't reach. Keep the nonce to `script-src`, since a nonce in `style-src` makes browsers ignore `'unsafe-inline'`:

```ruby
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.script_src  :self, "https://heydeacon.com"
    policy.style_src   :self, :unsafe_inline
    policy.connect_src :self, "https://heydeacon.com"
    policy.frame_src   "https://heydeacon.com"
  end

  config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
  config.content_security_policy_nonce_directives = %w(script-src)
end
```

## Opening the chat from your own button

The widget comes with its own button. To use one of yours instead, hide Deacon's in Appearance in the dashboard and call `window.Deacon.open()` from your button or link. `Deacon.close()` and `Deacon.toggle()` work too.

## What it adds

The helper prints the same tag Install gives you:

```html
<script src="https://heydeacon.com/widget/v1/loader.js" data-key="pk_your_widget_key" async></script>
```

It loads in the background without holding up the page. Above it, when someone is signed in, goes the signed-in script, here spread over lines:

```html
<script data-deacon-render="3f9c0a71d2e4b856">
  window.deaconUser = {
    id: "7",
    email: "ana@studio.com",
    name: "Ana Ruiz",
    token: (nonce) => fetch("/deacon/token", {
      method: "POST",
      credentials: "same-origin",
      headers: { "Content-Type": "application/json", "X-CSRF-Token": "…" },
      body: JSON.stringify({ nonce }),
    }).then((r) => (r.status === 200 ? r.text() : "")),
  };
  window.Deacon?.identify(window.deaconUser);
</script>
```

Works with Rails 8.0 and later, on Ruby 3.3 and later.

## License

MIT
