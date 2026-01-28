# DVD Archival Scripts

A collection of shell scripts for creating preservation-quality archival copies of DVD-VIDEO discs on macOS. These scripts automate the process of creating disk images, extracting video content, and generating access copies with proper deinterlacing.

## Overview

This toolkit provides scripts for DVD preservation workflows:

1. **Create ISO disk images** from physical DVDs using ddrescue (with error recovery)
2. **Extract video titles** to MKV format (preservation masters) using MakeMKV
3. **Generate access MP4 files** with automatic field order detection and deinterlacing
4. **Save technical metadata** as JSON for each title

## Script Comparison

| Script | Status | Features |
|--------|--------|----------|
| `ARCHIVE DVD-VIDEO_ddrescue_improved.zsh` | ✅ **Recommended** | Dependency checking, error handling, 5% safety margin, progress tracking |
| `ARCHIVE DVD-VIDEO_ddrescue.zsh` | Legacy | Original version without safety features |
| `ARCHIVE DVD-VIDEO_WITH_MKV_JSON.zsh` | Alternative | Uses dvdbackup instead of ddrescue |
| `ARCHIVE DVD-VIDEO.zsh` | Alternative | Basic version with dvdbackup |

**Use the improved version** (`ARCHIVE DVD-VIDEO_ddrescue_improved.zsh`) for new work.

## Prerequisites

### System Requirements

- **macOS** (10.15 Catalina or later recommended)
- **Admin privileges** (required for disk imaging with ddrescue)
- **DVD drive** (internal or external USB)
- **Disk space**: At least 10GB free per DVD (more for dual-layer discs)

### Required Software

All dependencies are installed via Homebrew (see Installation section):

- **ffmpeg** - Video transcoding
- **ffprobe** - Media analysis
- **ddrescue** - Disk imaging with error recovery
- **makemkvcon** - DVD title extraction
- **diskutil** - Disk management (included with macOS)

### Optional Software

- **jq** - Faster JSON parsing (recommended)
- **drutil** - Disc ejection (included with macOS)
- **exiftool** - Extended metadata extraction
- **mediainfo** - Media file analysis
- **IINA** - Video player for verification
- **Invisor** - ISO inspection tool (Mac App Store)

## Installation

### Step 1: Install Homebrew

Open Terminal and run:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Follow the on-screen instructions to complete installation.

### Step 2: Install Required Dependencies

```bash
brew install ffmpeg
brew install ddrescue
brew install makemkv
```

### Step 3: Install Optional Tools

```bash
brew install jq
brew install exiftool
brew install mediainfo
brew install iina
```

### Step 4: Configure PATH (Permanent)

Add Homebrew and MakeMKV to your PATH permanently:

```bash
# For Apple Silicon Macs (M1/M2/M3):
echo 'export PATH="/opt/homebrew/bin:$PATH"' >> ~/.zshrc

# For Intel Macs:
echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.zshrc

# Add MakeMKV CLI tool:
echo 'export PATH="/Applications/MakeMKV.app/Contents/MacOS:$PATH"' >> ~/.zshrc

# Reload your shell configuration:
source ~/.zshrc
```

### Step 5: Clone This Repository

```bash
cd ~/Documents  # or your preferred location
git clone https://github.com/tomackroyd/archive-dvd.git
cd archive-dvd
```

### Step 6: Make Scripts Executable

```bash
chmod +x *.zsh
```

### Step 7: Verify Installation

Check that all required tools are accessible:

```bash
which ffmpeg      # Should show /opt/homebrew/bin/ffmpeg (or /usr/local/bin/ffmpeg)
which ddrescue    # Should show /opt/homebrew/bin/ddrescue
which makemkvcon  # Should show /Applications/MakeMKV.app/Contents/MacOS/makemkvcon
```

Run cleanup and diagnostics:

```bash
brew cleanup
brew doctor
```

The improved script will also check for missing dependencies when you run it.

## Usage

### Quick Start

1. Insert a DVD
2. Navigate to the script directory
3. Run the improved script:

```bash
cd ~/Documents/archive-dvd
zsh ARCHIVE DVD-VIDEO_ddrescue_improved.zsh
```

4. Follow the interactive prompts

### Step-by-Step Workflow

#### Option 1: Create ISO from Physical DVD

**When to use:** You have a physical DVD in the drive and want to create a disk image.

1. Insert the DVD
2. Run the script and choose **Option 1**
3. Enter the DVD device identifier (e.g., `disk3`)
   - The script lists available devices to help you choose
4. Enter output ISO filename (e.g., `CA0001234567`)
5. Wait for ddrescue to complete (shows progress and ETA)

**What happens:**
- DVD is unmounted
- Raw disk image created using ddrescue with 3 retry passes
- 5% safety margin added to prevent data truncation
- Progress and time remaining displayed
- Log file created for error tracking

#### Option 2: Create MKV + MP4 from ISO

**When to use:** You have an ISO file and want to extract video titles and create access copies.

1. Run the script and choose **Option 2**
2. Select an existing ISO or provide path to one
3. Optionally eject the physical DVD
4. MakeMKV extracts all titles ≥15 seconds
5. Files are renamed from MakeMKV format to PM (Preservation Master) format
6. JSON metadata is saved for each title
7. Access MP4 files are generated with automatic deinterlacing

**What happens:**
- MakeMKV extracts titles to MKV (preservation format)
- Files renamed: `title_t00.mkv` → `FILENAME-PM01.mkv`
- Field order detected (progressive, TFF, or BFF)
- Appropriate deinterlacing applied (bob deinterlace for interlaced content)
- Access MP4 created: `FILENAME-A01.mp4`
- JSON metadata saved: `FILENAME-PM01.json`

#### Option 3: Create MKV Only (No Access Files)

**When to use:** You only want preservation masters without access copies (saves time).

Same as Option 2, but skips MP4 generation. Useful for batch processing where you'll create access files later.

#### Option 4: Create Access Files from Existing MKVs

**When to use:** You already have MKV files and need to generate or regenerate access MP4s.

1. Run the script and choose **Option 4**
2. Enter path to directory containing MKV files
3. Script processes all `.mkv` files in that directory
4. Shows success/failure count at completion

**Supported naming patterns:**
- `FILENAME-PM01.mkv` (Preservation Master)
- `FILENAME-VTS01.mkv` (Video Title Set)
- `FILENAME-A01.mkv` (Access - will be regenerated)

#### Option 5: Exit

Safely exits the script and moves the log file to the output directory (if available).

### File Naming Convention

**Preservation Masters (MKV):**
- Format: `IDENTIFIER-PM##.mkv`
- Example: `CA0001234567-PM01.mkv`
- PM = Preservation Master
- Numbers increment from 01

**Access Files (MP4):**
- Format: `IDENTIFIER-A##.mp4`
- Example: `CA0001234567-A01.mp4`
- A = Access
- Numbers match corresponding PM file

**Metadata:**
- Format: `IDENTIFIER-PM##.json`
- Example: `CA0001234567-PM01.json`
- Contains ffprobe output (streams, format, technical details)

**Log Files:**
- Format: `archive_dvd_video_YYYYMMDD_HHMMSS.log`
- Moved to output directory on script exit
- Contains complete terminal output for audit trail

## Technical Details

### Deinterlacing Strategy

The script automatically detects field order and applies appropriate deinterlacing:

| Field Order | Action | Filter Applied |
|-------------|--------|----------------|
| Progressive | None | No deinterlacing (direct encode) |
| Top Field First (TFF) | Bob deinterlace | `bwdif=mode=send_field:parity=tff:deint=all` |
| Bottom Field First (BFF) | Bob deinterlace | `bwdif=mode=send_field:parity=bff:deint=all` |
| Unknown/Empty | Bob deinterlace | `bwdif=mode=send_field:parity=tff:deint=all` (safe default) |

**Bob deinterlacing** (send_field mode) doubles the frame rate for smooth motion, ideal for archival access copies.

### Access File Encoding Settings

MP4 files use these settings for broad compatibility and reasonable file sizes:

```
Video:
  - Codec: H.264 (libx264)
  - Bitrate: 3 Mbps (min 3M, max 6M)
  - Preset: medium (balance of speed/quality)
  - Profile: High, Level 3.1
  - Pixel Format: yuv420p (maximum compatibility)

Audio:
  - Codec: AAC
  - Bitrate: 192 kbps
  - Channels: Stereo (2.0)

Container:
  - Format: MP4
  - Fast start enabled (web streaming)
  - Chapters preserved
  - Subtitles excluded
```

### DDrescue Safety Margin

The improved script adds a **5% safety margin** to the OS-reported DVD size:

**Why?** The operating system may slightly underestimate disc size, especially on:
- Damaged or scratched discs
- Dual-layer DVDs
- Discs with unusual formatting

**How it works:**
```bash
Detected size: 4,700,372,992 bytes
With 5% margin: 4,935,391,741 bytes
```

This ensures complete data capture while still allowing ddrescue to show progress percentage and estimated time remaining.

### Error Recovery

**DDrescue** is used instead of `dd` because it:
- Makes 3 retry passes on read errors (`-r3`)
- Continues on errors instead of aborting
- Creates detailed log files for error analysis
- Can resume interrupted copies

Check the `.log` file if ddrescue reports errors. The log shows:
- Which sectors had read errors
- How many retries were attempted
- Whether recovery was successful

## Troubleshooting

### "ERROR: Missing required dependencies"

**Problem:** Script reports missing tools.

**Solution:**
```bash
# Reinstall missing dependencies
brew install ffmpeg ddrescue makemkv

# Verify installation
which ffmpeg
which makemkvcon
```

### "ERROR: Device disk3 not found"

**Problem:** Wrong device identifier or DVD not detected.

**Solution:**
1. Run `diskutil list` to see all devices
2. Look for your DVD drive (usually labeled with disc name)
3. Use the device identifier shown (e.g., `disk3`, not `/dev/disk3`)

### "ERROR: Failed to unmount /dev/disk3"

**Problem:** Disk is in use by another application.

**Solution:**
1. Close any applications accessing the DVD (Finder windows, media players)
2. Try unmounting manually: `diskutil unmountDisk /dev/disk3`
3. If persistent, eject and reinsert the disc

### MakeMKV says "evaluation period has expired"

**Problem:** MakeMKV beta key needs renewal (every 1-2 months).

**Solution:**
1. Go to [MakeMKV Forum Beta Key Thread](https://forum.makemkv.com/forum/viewtopic.php?f=5&t=1053)
2. Copy the latest key from the first post
3. Open MakeMKV GUI
4. Go to **Help → Register**
5. Paste the key and click OK

### "ERROR: makemkvcon: command not found"

**Problem:** MakeMKV CLI not in PATH.

**Solution:**
```bash
# Add to PATH permanently
echo 'export PATH="/Applications/MakeMKV.app/Contents/MacOS:$PATH"' >> ~/.zshrc
source ~/.zshrc

# Verify
which makemkvcon
```

### Access MP4 has wrong field order / looks choppy

**Problem:** Deinterlacing applied incorrectly.

**Solution:**
1. Check the JSON metadata file for `field_order`
2. If incorrect, you can manually regenerate with specific settings
3. File an issue on GitHub with the disc details

### Permission denied when running ddrescue

**Problem:** ddrescue requires admin privileges for raw disk access.

**Solution:**
- The script uses `sudo` and will prompt for your password
- Ensure your user account has admin privileges
- Or run the entire script with: `sudo zsh ARCHIVE DVD-VIDEO_ddrescue_improved.zsh`

### Script hangs at "Copying DVD to ISO"

**Problem:** Disc may have severe damage or drive issue.

**Solution:**
1. Check the `.log` file to see progress
2. Press Ctrl+C to cancel (safe, ddrescue can resume later)
3. Try cleaning the disc
4. Try a different DVD drive

## MakeMKV Beta Key Updates

MakeMKV is **"free while in beta"** but requires periodic key updates:

### Get the Latest Beta Key

1. Visit the [MakeMKV Forum](https://forum.makemkv.com/forum/viewtopic.php?f=5&t=1053)
2. Copy the key from the first post (updated monthly)
3. Open MakeMKV application
4. Go to **Help → Register** (or "Enter registration key")
5. Paste the key and apply

### Key Expiration

- Beta keys typically last **30-60 days**
- The script will fail with "evaluation period has expired" when the key expires
- Bookmark the forum link for quick access

### Commercial License

If you use MakeMKV regularly for institutional work, consider purchasing a commercial license to support development: https://www.makemkv.com/buy/

## Workflow Recommendations

### For Batch Processing

Process multiple DVDs efficiently:

1. **Imaging phase** (requires admin privileges):
   - Create ISOs for all discs using Option 1
   - Name them systematically (CA0001234567, CA0001234568, etc.)
   - Store ISOs in a staging directory

2. **Processing phase** (can run as standard user):
   - Use Option 2 to process each ISO
   - Can be done on a different machine
   - Can be interrupted and resumed

3. **Quality control**:
   - Verify output files play correctly (use IINA)
   - Check JSON metadata for completeness
   - Verify file sizes are reasonable

### For Single Discs

Quick workflow for one-off preservation:

1. Insert DVD
2. Run script, choose Option 2 (MKV + MP4)
3. When prompted, use the just-created ISO
4. Eject disc when safe
5. Verify output files

### Storage Recommendations

**Preservation Masters (MKV):**
- Store on redundant storage (RAID, multiple backups)
- Never delete after creating access copies
- Consider LTO tape for long-term archival

**Access Copies (MP4):**
- Suitable for streaming servers
- Can be regenerated from MKV if lost
- Lower storage priority than masters

**ISOs:**
- Can be deleted after successful MKV extraction
- Or retain for perfect disc reconstruction if needed
- Useful for creating physical copies later

## Contributing

Found a bug or have a suggestion? Please:

1. Check existing issues on GitHub
2. Create a new issue with:
   - Script version used
   - macOS version
   - Complete error message
   - Steps to reproduce

## License

See [LICENSE](LICENSE) file for details.

## Credits

- Uses [GNU ddrescue](https://www.gnu.org/software/ddrescue/) for disk imaging
- Uses [MakeMKV](https://www.makemkv.com/) for DVD extraction
- Uses [FFmpeg](https://ffmpeg.org/) for video transcoding
- Improved with assistance from Claude Code

## Version History

### v2.0 (Improved Version)
- Added dependency checking
- Added error handling and recovery
- Added 5% safety margin to DVD size detection
- Fixed redundant field_order logic
- Added progress tracking for access file creation
- Improved user feedback and error messages

### v1.0 (Original)
- Basic ddrescue ISO creation
- MakeMKV extraction
- Access file generation with deinterlacing
