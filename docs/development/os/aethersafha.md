# Aethersafha — Wayland Compositor

- **Version**: 0.1.0
- **Repo**: [MacCracken/aethersafha](https://github.com/MacCracken/aethersafha)
- **License**: AGPL-3.0-only
- **Tests**: 785
- **Role**: AI-augmented desktop compositor

Wayland compositor, AI features, plugin host, XWayland, screen capture/recording, accessibility, theme bridge, security UI, gesture recognition, HUD overlays.

**Consumers**: AGNOS desktop, plugin authors, daimon (screen capture API)

## Desktop Components

### trump — Recycle Bin

The desktop recycle bin. Where everything deleted goes, nothing useful comes out.

- **Crate**: `trump`
- **Role**: Soft-delete, restore, permanent purge. Desktop trash management.
- **Consumers**: aethersafha (desktop icon/widget), file manager, agnoshi (shell `rm` → trump soft-delete)
- **Features**:
  - Soft-delete: moves files to `~/.local/share/trump/` with metadata (original path, delete timestamp)
  - Restore: returns files to original location
  - Purge: permanent deletion (scheduled or manual)
  - Size tracking: reports how much space the trash is consuming
  - Auto-purge: configurable retention (default: 30 days)
- **Status**: Planned
