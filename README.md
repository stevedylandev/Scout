# Scout

![cover](https://files.stevedylan.dev/titan.png)

A native iOS client for the [Gemini protocol](https://geminiprotocol.net/) — a lightweight, privacy-focused alternative to the web.

>[!NOTE]
>I built this project but have not had the time to deploy + maintain it. If you find it useful, please feel free to take the code and publish it as you wish!

## Features

- Browse Gemini capsules with full `text/gemini` rendering (headers, links, lists, preformatted text)
- URL bar with navigation history (back/forward)
- Tab management
- Bookmarks
- Media preview support (images, audio, video)
- Input prompt handling (status 10/11)
- Automatic redirect following (status 30/31)
- TOFU (Trust on First Use) certificate verification
- Client certificate generation and management
- Theming support (custom background and text colors)

## Requirements

- iOS 16+
- Xcode 15+

## Build & Run

Open `Scout.xcodeproj` in Xcode and run with `Cmd+R`.

## License 

MIT
