# AIM — Anomaly Information Module

AIM is a small open-source terminal reader for Minecraft 1.12.2
OpenComputers. Enter `173` or `SCP-173`, and AIM retrieves the current article
text from Crom, shows it in a paged terminal view, and includes author, source,
and licence attribution.

This is deliberately a tight MVP. It has no bundled SCP database, no
persistent article cache, no background sync, and no unrelated system
changes.

## Requirements

- Minecraft 1.12.2 with OpenComputers and OpenOS
- An Internet Card with HTTP enabled by the server
- Access to `apiv1.crom.avn.sh` while AIM runs
- Access to `raw.githubusercontent.com` while installing or upgrading
- OpenComputers 1.8.3 or newer is strongly recommended because it includes an
  Internet Card security fix

The built-in OpenComputers runtime is Lua 5.2. AIM uses only OpenOS libraries
and a small bundled JSON codec. Crom's API is alpha and may change or later
require authorization; AIM reports API and network failures without keeping a
stale cache.

## Install or upgrade

Run the published Pastebin installer:

```sh
wget -f https://pastebin.com/raw/wHutR5DR /tmp/aim-installer.lua
lua /tmp/aim-installer.lua
```

Alternatively, download the same wizard directly from GitHub:

```sh
wget -f https://raw.githubusercontent.com/matesaman9910/AIM-OpenComputers/main/installer.lua /tmp/aim-installer.lua
lua /tmp/aim-installer.lua
```

Select **1** to install or upgrade. The wizard downloads into a staging folder,
keeps a rollback copy while activating the new files, and only manages the
fixed directory `/home/aim`.

Run AIM with:

```sh
lua /home/aim/aim.lua
```

Run the wizard again and select **2** to remove only AIM's known files. If
`/home/aim` contains an unrelated file, the directory is deliberately left in
place.

## Use

1. Select **Look up an SCP designation**.
2. Enter a number such as `173` or a designation such as `SCP-173`.
3. Use Enter or `N` for the next page, `P` for the previous page, and `Q` to
   return to the menu.

AIM 0.1 supports numeric English-branch designations from SCP-001 through
SCP-9999. It retrieves the plain `textContent` supplied by Crom; complex page
layouts, interactive components, images, tables, and custom formatting are not
rendered in this MVP.

## Verified API shape

Verified anonymously against the live endpoint on 2026-11-18:

```graphql
query AimArticle($url: URL!) {
  page(url: $url) {
    url
    wikidotInfo { title textContent }
    attributions { type user { name } }
  }
}
```

Endpoint: `https://apiv1.crom.avn.sh/graphql`

Using `http://scp-wiki.wikidot.com/scp-173`, Crom returned title `SCP-173`,
1,388 characters of plain text, and author attribution `Moto42` without
authentication. That is a point-in-time compatibility check, not a promise
that the alpha API will remain unchanged.

## Licences and attribution

- AIM's source code is GPL-3.0-or-later. See `LICENSE`.
- Retrieved SCP Wiki article content is separate content under CC BY-SA 3.0.
  AIM displays the author(s), source URL, and licence URL on every article.
- AIM does not retrieve images. In particular, it does not use the former
  SCP-173 image, which is not CC BY-SA content.

See `NOTICE.md` for the complete separation and attribution notice.

## Development test

With Lua available on the development machine:

```sh
lua tests/run.lua
```

The tests cover JSON, designation normalization, Crom response parsing, page
wrapping, and installer scope. A real OpenComputers machine or emulator is
still required for final Internet Card and screen interaction testing.
