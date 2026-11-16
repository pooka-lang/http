# http

[![Package Version](https://img.shields.io/hexpm/v/pooka_http?style=for-the-badge&color=75618E)](https://hex.pm/packages/pooka_http)
[![Hex Docs](https://img.shields.io/website?url=https%3A%2F%2Fpooka-http.hexdocs.pm%2F&style=for-the-badge&label=hex&up_message=docs&up_color=FF891F&down_message=not%20found&down_color=lightgrey)](https://pooka-http.hexdocs.pm/)
[![Tests](https://img.shields.io/github/actions/workflow/status/pooka-lang/http/test.yml?style=for-the-badge&label=tests)](https://github.com/pooka-lang/http/actions/workflows/test.yml)

HTTP requests, responses, cookies and URLs for Pooka.

```sh
pooka add pooka_http
```

```pooka
module main

import pooka/http

main() {
  let assert Ok(request) = http.get("https://example.org/birds?q=owl")
  assert request.query_param("q") == Some("owl")
}
```

Shared HTTP vocabulary without a server or client. Header lookup ignores case. Checked component and cookie helpers report invalid input; `Request.validate()` checks a request before it goes on the wire.

See the [API documentation](https://pooka-http.hexdocs.pm/) for the rest.

## Licence

Licensed under the [Apache License, Version 2.0](LICENSE).
