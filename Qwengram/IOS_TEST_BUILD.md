# Qwengram iPhone test build

Run **Qwengram iPhone Test Build** manually from the GitHub Actions page. It
checks out `qwengram/main`, builds the physical-device `debug_arm64` target,
and publishes the `Qwengram-iPhone-test` artifact when successful.

Configure these repository secrets before running it:

- `QWENGRAM_TELEGRAM_API_ID`
- `QWENGRAM_TELEGRAM_API_HASH`

Download `Qwengram-iPhone-test` from the completed workflow run. It contains
the generated `Telegram.ipa` for development testing.

The workflow deliberately disables extensions and provisioning profiles and
does not import Apple certificates, profiles, Apple IDs, or passwords. The IPA
is unsigned and is not directly installable; sign or sideload it separately for
your own iPhone.
