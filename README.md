# zSkyridingBar

A World of Warcraft addon for tracking skyriding information and speed. This addon is a standalone implementation based on the popular "Liroo - Dragonriding" WeakAuras aura, providing native WoW frames and overlays for skyriding tracking.

## Features

### Core Functionality
- **Real-time Speed Tracking**: Displays your current skyriding speed with support for both yd/s and percentage units
- **Vigor Bar System**: Shows individual skyriding charges with visual progress bars
- **Zone Awareness**: Automatically adjusts for different zones (full speed vs. slow skyriding areas)
- **Buff Tracking**: Monitors "Thrill of the Skies" and ascent boost effects with visual indicators
- **Native UI Integration**: Uses Blizzard's frame system for optimal performance and compatibility

### Visual Elements
- **Speed Bar**: Horizontal status bar showing current speed (20-100% range)
- **Vigor Bars**: Individual charge indicators showing current vigor and regeneration
- **Color Coding**: Dynamic color changes for different states (normal, boosting, thrill)
- **Text Overlays**: Speed values and angle information displayed on bars

### Configuration Options
- **Positioning**: Full control over frame position, scale, and strata
- **Appearance**: Customizable colors for all elements
- **Display Options**: Toggle speed display, change units, hide default UI
- **Font Settings**: Choose fonts, sizes, and outline styles
- **Profile Support**: Save and switch between different configurations

## Installation

1. Extract the addon to your `World of Warcraft/Interface/AddOns/` directory
2. Ensure the folder is named `zSkyridingBar`
3. Restart WoW or reload your UI (`/reload`)
4. The addon will automatically activate when skyriding is available

## Usage

### Commands
- `/skybar` or `/zskyridingbar` - Show command help
- `/skybar toggle` - Enable/disable the addon
- `/skybar config` - Open the configuration panel

### Configuration
Access the options panel through:
- Slash command: `/skybar config`
- Game Menu: Interface → AddOns → zSkyridingBar
- Blizzard Options panel

### Automatic Behavior
The addon automatically:
- Shows when skyriding/dragonriding becomes available
- Hides in areas where skyriding is not usable
- Adjusts speed calculations based on current zone
- Tracks vigor charges and regeneration
- Monitors relevant buffs and effects

## Technical Details

### Based on WeakAuras Implementation
This addon replicates the functionality of the popular "Liroo - Dragonriding" WeakAuras, including:
- Speed tracking using `C_PlayerInfo.GetGlidingInfo()`
- Zone detection for speed adjustment ratios
- Ascent spell tracking (spell ID: 372610)
- Thrill of the Skies buff monitoring (buff ID: 377234)
- 20 FPS update rate for smooth tracking

### Libraries Used
- **Ace3 Framework**: For addon structure, configuration, and database management
- **LibSharedMedia-3.0**: For font and texture resources
- **Native WoW APIs**: For skyriding data and UI frames

### Compatibility
- **WoW Version**: 11.0.2+ (The War Within and later)
- **Dependencies**: None (all libraries included)
- **Conflicts**: Designed to coexist with WeakAuras and other addons

## Development Notes

### Key Features Ported from WeakAuras
1. **Speed Calculation**: Exact replication of speed tracking logic
2. **Zone Awareness**: Same zone detection and speed ratio adjustments
3. **Buff Tracking**: Identical spell and buff ID monitoring
4. **Visual States**: Color coding for different flight states
5. **UI Hiding**: Option to hide default Blizzard vigor UI

### Files Structure
- `zSkyridingBar.lua` - Main addon logic and UI creation
- `Options.lua` - Configuration panel using Ace3Config
- `zSkyridingBar.toc` - Addon metadata and file loading
- `Libs/` - Required Ace3 and supporting libraries

### Customization
The addon is designed to be easily customizable through the options panel. All visual elements, positioning, and behavior can be adjusted without code modifications.

## Credits

- **Original WeakAuras**: Based on "Liroo - Dragonriding" by Liroo
- **Framework**: Built with the Ace3 addon framework
- **Inspiration**: zBarButtonBG addon for options panel design patterns

## License

This addon is released under the same license as the original WeakAuras implementation.