# Privacy Policy - GitPilot

**Last updated: December 15, 2025**

## Overview

GitPilot is designed with privacy as a core principle. All your data stays on your device.

## Data Collection

**GitPilot does NOT collect, store, or transmit any personal data to external servers.**

### What GitPilot stores locally:
- Repository paths you configure
- Build logs and check history
- Notification settings (Telegram bot tokens, Teams webhook URLs)
- App preferences

All this data is stored locally on your Mac using SwiftData and UserDefaults.

## Third-Party Services

GitPilot can optionally integrate with:

### Telegram
If you configure Telegram notifications, GitPilot sends messages to the Telegram Bot API using the token and chat ID you provide. Only the message content (build status, repository name, etc.) is sent.

### Microsoft Teams
If you configure Teams notifications, GitPilot sends messages to the webhook URL you provide. Only the message content is sent.

**GitPilot does not share any data with these services beyond what you explicitly configure for notifications.**

## Git Operations

GitPilot performs Git operations (fetch, pull) on repositories you configure. These operations are performed locally using the `git` command-line tool installed on your system.

## Network Access

GitPilot only makes network requests to:
1. Your Git remotes (via `git fetch`/`git pull`)
2. Telegram API (if configured)
3. Microsoft Teams webhooks (if configured)

## Data Security

- All data is stored locally on your device
- No accounts or cloud services required
- No analytics or tracking
- No data is transmitted to Megamil or any other party

## Open Source

GitPilot is open source. You can review the complete source code at:
https://github.com/Megamil-LTDA/GitPilot

## Contact

If you have questions about this privacy policy, please contact:
- Email: eduardo@megamil.com.br
- GitHub Issues: https://github.com/Megamil-LTDA/GitPilot/issues

## Changes

We may update this privacy policy from time to time. Updates will be posted in the GitHub repository.

---

© 2024 Megamil. All rights reserved.
