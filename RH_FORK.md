# Resident Help fork of DocuSeal

This repository is a fork of [docusealco/docuseal](https://github.com/docusealco/docuseal)
maintained by swy-ventures for the Resident Help client portal (residenthelp.org).
It is licensed under AGPL-3.0 with DocuSeal's additional attribution term
(see `LICENSE` and `LICENSE_ADDITIONAL_TERMS`). The DocuSeal attribution in the
user interface is retained.

The modified source corresponding to the running service is this repository.
Anyone interacting with the signing pages may obtain it here, which satisfies
AGPL section 13.

## What differs from upstream

| Area | Change | Files |
|---|---|---|
| Signing form framing | When `RH_FRAME_ANCESTORS` is set, `/s/:slug` (and its completed/success pages) drop `X-Frame-Options` and send `Content-Security-Policy: frame-ancestors 'self' <origins>` so the client portal can render the form in an iframe. | `app/controllers/concerns/rh_embeddable.rb`, `app/controllers/submit_form_controller.rb` |
| Template from PDF by API | `POST /api/templates/pdf` creates a template from https URL(s), mirroring the web upload path (`TemplatesUploadsController#create`). Imports AcroForm fields when present. | `app/controllers/api/templates_pdf_controller.rb`, `config/routes.rb` |

Everything else is upstream. The Pro embedded web component is not part of this
fork; the portal uses a plain `<iframe>` against the signing URL.

## Environment

```
RH_FRAME_ANCESTORS="https://residenthelp.org https://www.residenthelp.org"
```

Unset = upstream behaviour.

## Build and run (HP host)

```
cd /opt/docuseal-src
git fetch origin && git checkout rh/embed-and-api && git pull --ff-only
docker build -t docuseal-rh:local .
# /opt/docuseal/compose.yml: image: docuseal-rh:local, add RH_FRAME_ANCESTORS to environment
sudo systemctl reload docuseal
curl -sI http://127.0.0.1:3001/up
```

Keep the last known-good `docuseal/docuseal:<tag>` in compose comments as rollback.

## Tracking upstream

```
git remote add upstream https://github.com/docusealco/docuseal.git   # once
git fetch upstream
git checkout rh/embed-and-api
git rebase upstream/master
# resolve conflicts (expected to be rare: 1 include, 1 route line, 2 new files)
git push --force-with-lease
```

Then rebuild as above.
