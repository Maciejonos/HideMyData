<div align="center">

<img width="180" height="180" alt="HideMyData" src="HideMyData/Assets.xcassets/AppLogo.imageset/logo.png" />

### Local, AI-powered PII redaction for macOS

Built with [OpenMed](https://github.com/maziyarpanahi/openmed), [MLX-Swift](https://github.com/ml-explore/mlx-swift), and Apple Vision

![Swift](https://img.shields.io/badge/Swift-FA7343?style=for-the-badge&logo=swift&logoColor=white)
![Xcode](https://img.shields.io/badge/Xcode-007ACC?style=for-the-badge&logo=Xcode&logoColor=white)
![macOS](https://img.shields.io/badge/mac%20os-000000?style=for-the-badge&logo=apple&logoColor=white)

</div>

> ⚠️ If macOS Gatekeeper blocks the app (it's not signed with a developer certificate), bypass it by running:
>
> ```bash
> xattr -rd com.apple.quarantine /Applications/HideMyData.app
> ```

## Install

Grab the latest `.dmg` from the [Releases](../../releases) page, or build from source - see [Build](#build) below.

https://github.com/user-attachments/assets/57206914-ab93-4029-8fcf-f388f30bd132

## Features

- **Fully local** — model runs on-device, nothing ever leaves your machine
- **PDF and image input** — both formats share the same detection and redaction pipeline
- **OCR** — Apple Vision handles scanned PDFs, images, and rescues PDFs whose embedded fonts hide text from selection
- **AI detection** — OpenAI `privacy-filter` (MLX 8-bit) catches names, emails, phones, addresses, dates, IDs in context
- **Manually maintained regrex** — IBAN, SSN, Personal identifiers, MAC, IPv4/v6, JWT, API keys, crypto wallets and more to come
- **Two redaction styles** — solid black or frosted glass blur
- **Manual editing** — add or remove redaction rectangles by hand before saving
- **Permanent on save** — pages are rasterized and rebuilt - the original text and glyphs are gone, not just hidden

## Requirements

- macOS 26 or later
- Apple Silicon (the MLX backend does not run on Intel)

## Build

```bash
open HideMyData.xcodeproj
# build & run via Xcode (⌘R)
```

On first launch, you will be prompted to download the model (~1.5 GB) from Hugging Face into `~/Library/Application Support/HideMyData/ModelCache/`.

## Tech Stack

Swift 6, SwiftUI, MLX-Swift, Apple Vision, PDFKit, OpenMedKit

## License

GPL-3.0
