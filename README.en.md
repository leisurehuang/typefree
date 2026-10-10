<p align="center">
  <img src="readme-assets/icon.png" width="96" height="96" alt="Typefree">
</p>

<h1 align="center">Typefree</h1>

<p align="center"><b>AI voice input for macOS: hold, talk, release — the text is already cleaned up and sitting at your cursor.</b></p>

<p align="center">
  <a href="https://github.com/kdsz001/typefree/releases/latest"><img src="https://img.shields.io/github/v/release/kdsz001/typefree?label=release&color=1d1d1f" alt="Latest release"></a>
  <a href="mac/LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-1d1d1f" alt="GPL-3.0"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-1d1d1f" alt="macOS 14+">
</p>

<p align="center">
  <a href="https://github.com/kdsz001/typefree/releases/latest/download/Typefree.dmg"><b>Download for Mac</b></a> ·
  <a href="https://typefree.app/index.en.html">Website</a> ·
  <a href="https://typefree.app/setup-guide.en.html">API key setup guide</a> ·
  <a href="README.md">中文</a>
</p>

<p align="center">
  <img src="readme-assets/en-mouse.gif" width="768" alt="Hold the mouse button in a text field and talk; release and the cleaned-up text is typed. Drag down to lock, drag away to cancel.">
</p>

## What it does

In any app's text field, hold a hotkey or the left mouse button and talk. When you let go, the transcript goes through an LLM that strips filler words, fixes the sentence, adds punctuation and paragraphs, and types the result at your cursor. Say it once, no editing afterwards.

- **Voice to text** — recognition and cleanup in one step; works in chat apps, notes, browsers and code editors
- **Hold the mouse to talk** — no hotkey needed; drag down a little to lock if you want to let go mid-sentence, drag far away to cancel
- **Ask AI anywhere** — hold the mouse on empty space and ask; the answer appears in the top-right corner, with follow-ups and pinning
- **Voice translation** — end your sentence with "in Chinese" (or "Japanese", "Korean"…) and it is typed in that language
- **Learns from your fixes** — correct a misheard name or product term once and it is recognized next time; you can also add words to your vocabulary
- **History** — everything you dictate is stored encrypted on your Mac, exportable, kept as long as you choose
- **Multiple providers** — Volcengine for speech recognition, Qwen for cleanup, with the model picked automatically by quality and speed; this fork additionally accepts any OpenAI-compatible endpoint (see below)

## Fork differences (vs upstream [kdsz001/typefree](https://github.com/kdsz001/typefree))

Everything upstream is preserved; on top of that (each item ships with an OpenSpec spec and tests, archived under `openspec/changes/archive/`):

| Feature | Notes |
|---|---|
| **Custom polish / ask-AI model** | A "Custom" provider in Settings → Models → Speech cleanup: enter Base URL + model + API key to use any OpenAI-compatible endpoint (DeepSeek, Kimi, OpenRouter, local Ollama, …). The model can be typed by hand or fetched from `/models`; once configured it counts as bring-your-own-key and connects directly |
| **Custom speech recognition** | A "Custom" provider for recognition: standard `POST {Base}/audio/transcriptions` with WAV upload — works with SiliconFlow SenseVoice-Small (free, strong for Chinese), Groq whisper-large-v3-turbo (free tier) and any compatible endpoint. No hot-word biasing; vocabulary-based post-correction still applies |
| **Update channel points at this repo** | Sparkle reads this repo's `appcast.xml` (signed and committed by CI on each release) with a fork-specific Ed25519 key — no more being upgraded to the official build and losing the custom features |
| **GitHub Actions CI** | Pushes run tests + build; pushing a `v*` tag publishes a Release end to end: tests → build → ad-hoc signing → DMG → appcast update |

API keys still live only in the local keychain and never pass through any middleman. CI builds are ad-hoc signed — right-click → Open on first launch. Upstream changes are synced periodically by merging `kdsz001:main`.

Chinese and English speech are both supported. The cleanup prompts are tuned first for Chinese, so that is where it shines most.

## Three ways to use it

| | How to start | Cost |
|---|---|---|
| **Free trial** | [Download the DMG](https://github.com/kdsz001/typefree/releases/latest/download/Typefree.dmg) and start talking — nothing to configure | Free for 7 days, paid for by the author |
| **Bring your own key** | Paste your own API key under Settings → Models ([guide](https://typefree.app/setup-guide.en.html), a few minutes) | **Free forever, no word limit**; usage is billed to your own account |
| **Membership** | Don't want to get a key? Membership covers recognition, cleanup and Ask AI | $26 / year |

The trial and membership channels only exist in the signed build (the DMG from the website or Releases). A build you compile yourself has neither — paste your own key after installing and every feature works the same.

## Ask AI anywhere

<p align="center">
  <img src="readme-assets/en-ask.gif" width="768" alt="Hold the mouse on empty space to ask; the answer appears top-right; hold the panel to follow up; click outside to dismiss">
</p>

No window switching, no copying: hold the mouse on some empty space and ask. Hold the answer panel to follow up. Click outside and it shrinks to one line and fades out; click the pin to keep it.

## Voice translation

<p align="center">
  <img src="readme-assets/en-translate.gif" width="768" alt="End your sentence with “in Chinese” and it is typed in Chinese">
</p>

Commands are matched by rule, not guessed by the model. English, Chinese, Japanese and Korean are on by default; French, German and Spanish can be enabled on the Explore page. You can also fix one output language so you never have to say the command.

## Privacy

- Your API keys live in the macOS Keychain and are never uploaded
- With your own key, audio goes straight to the provider you chose, never through the author's server
- The trial and membership channels relay through the author's server, which forwards and does not store audio or text
- History is stored encrypted on your Mac

Full details in the [privacy policy](https://typefree.app/privacy.en.html).

## Build from source

Requires macOS 14+ and Xcode 26.3.

```bash
git clone https://github.com/kdsz001/typefree.git
cd typefree/mac
./build.sh                      # output in dist/
bash scripts/install_app.sh     # installs to /Applications
```

Details, directory layout and tests: [mac/README.md](mac/README.md) (Chinese, with an English summary).

## Repository layout

- `mac/` — the complete macOS app (Swift, GPL-3.0)
- `openspec/` — this fork's specs and change archive (spec-driven workflow)
- `.github/workflows/` — CI: test, build, release (added by the fork)
- root — the website [typefree.app](https://typefree.app) (GitHub Pages)

## License and trademark

The code is licensed under the [GNU GPL-3.0](mac/LICENSE): use, modify and redistribute freely, as long as derived software is also GPL. **The "Typefree" name, icon and website content are not covered by the license** — please don't ship your own build under that name.

## Feedback

- The "Feedback" page in the app's sidebar talks straight to the author, screenshots included
- Or open an [issue](https://github.com/kdsz001/typefree/issues): bugs, ideas, examples of bad transcripts are all welcome, in English or Chinese
- Pull requests are currently limited to small fixes — see [CONTRIBUTING](mac/CONTRIBUTING.md)
