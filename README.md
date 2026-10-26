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

## Options

Set them on `config.deacon`, in an initializer or in `config/application.rb`.

| Option       | Type    | Default      | What it does |
| ------------ | ------- | ------------ | ------------ |
| `key`        | string  | `DEACON_KEY` | Your Deacon key. |
| `context`    | hash    | none         | Details Deacon takes into account when it answers, the same on every page, such as `{ product: "api", docs_version: "3.2" }`. Up to 12 keys, each value a string, number or boolean. Anyone can read them in the page's HTML, so never put a secret here. |
| `page_views` | boolean | `true`       | The same script counts visits for Deacon's website analytics. Set this to `false` to send no page views or JavaScript errors from your app. Chat still works. |

```ruby
Rails.application.config.deacon.key = "pk_your_widget_key"
Rails.application.config.deacon.context = { product: "api", docs_version: "3.2" }
Rails.application.config.deacon.page_views = false
```

## Turbo

Turbo Drive swaps the `<body>` on each visit and keeps the `<head>`, so in the head the tag runs once. Deacon puts its chat on `<html>`, outside the body, so the widget stays in place as people move between pages.

## Content Security Policy

If your app gives each request a nonce, with `config.content_security_policy_nonce_generator`, the tag carries it, so `script-src` doesn't need Deacon's address. The chat still needs `https://heydeacon.com` in `connect-src` and `frame-src`, and `'unsafe-inline'` in `style-src`, because the widget writes its styles where a nonce can't reach. Keep the nonce to `script-src`, since a nonce in `style-src` makes browsers ignore `'unsafe-inline'`:

```ruby
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.script_src  :self
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

It loads in the background without holding up the page. Works with Rails 8.0 and later, on Ruby 3.3 and later.

## License

MIT
