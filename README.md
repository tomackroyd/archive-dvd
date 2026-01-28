# ARCHIVE DVD-VIDEO

A shell script for creating preservation-quality archival copies of DVD-VIDEO discs on macOS. Creates ISO disk images, extracts video titles to MKV format (preservation masters), and generates access MP4 files with blend deinterlacing.

## Features

- **ISO Creation**: Uses ddrescue with 5% safety margin for reliable disk imaging
- **MKV Extraction**: Extracts all titles ≥15 seconds using MakeMKV
- **Access Files**: Generates MP4 files with automatic field order detection
- **Blend Deinterlacing**: Uses `bwdif=mode=send_frame` to preserve original frame rate
- **Error Recovery**: Comprehensive error handling and logging throughout
- **Smart Naming**: Automatic file renaming from MakeMKV format to PM (Preservation Master) format

## Requirements

### System
- macOS 10.15 Catalina or later
- Admin privileges (for disk imaging with ddrescue)
- External or internal DVD drive
- At least 10GB free disk space per DVD

### Required Software
- **ffmpeg** - Video transcoding
- **ffprobe** - Media analysis (included with ffmpeg)
- **ddrescue** - Disk imaging with error recovery
- **makemkvcon** - DVD title extraction
- **diskutil** - Disk management (included with macOS)

### Recommended Archival Tools
These tools are not required for the script to run, but are essential for a complete archival workflow:

- **jq** - Faster JSON parsing (recommended for script)
- **exiftool** - Extract and analyze file metadata
- **mediainfo** - Display technical metadata about media files
- **IINA** - Modern video player for verification (or VLC)
- **amiaos** - AMIA Open Source archival tool suite
- **Invisor** - ISO file inspection (Mac App Store) 


## Installation

### 1. Install Homebrew

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 2. Install Required Dependencies

```bash
brew install ffmpeg ddrescue makemkv jq
```

### 3. Install Archival Tools (Recommended)

These tools support a complete archival workflow:

```bash
# Install archival utilities
brew install exiftool mediainfo

# Install AMIA Open Source tools
brew install amiaopensource/amiaos/amiaos

# Install video player
brew install iina

# Cleanup
brew cleanup
brew doctor
```

**Invisor** (ISO inspector) must be installed separately from the Mac App Store.

### 4. Configure PATH

Add Homebrew and MakeMKV to your PATH permanently:

```bash
# For Apple Silicon Macs (M1/M2/M3):
echo 'export PATH="/opt/homebrew/bin:$PATH"' >> ~/.zshrc

# For Intel Macs:
echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.zshrc

# Add MakeMKV CLI:
echo 'export PATH="/Applications/MakeMKV.app/Contents/MacOS:$PATH"' >> ~/.zshrc

# Apply changes:
source ~/.zshrc
```

### 5. Download Script

```bash
cd ~/Documents  # or your preferred location
git clone https://github.com/tomackroyd/archive-dvd.git
cd archive-dvd
chmod +x "ARCHIVE DVD-VIDEO.zsh"
```

### 6. Verify Installation

```bash
which ffmpeg      # Should show /opt/homebrew/bin/ffmpeg
which ddrescue    # Should show /opt/homebrew/bin/ddrescue
which makemkvcon  # Should show /Applications/MakeMKV.app/Contents/MacOS/makemkvcon
```

## Usage

### Quick Start

```bash
cd ~/Documents/archive-dvd
zsh "ARCHIVE DVD-VIDEO.zsh"
```

The script presents an interactive menu with 5 options.

### Menu Options

#### Option 1: Create ISO from DVD

**Purpose**: Create a disk image from a physical DVD.

**Requirements**:
- Admin privileges (script will prompt for sudo password)
- Physical DVD inserted in drive

**Steps**:
1. Insert DVD
2. Choose Option 1
3. Enter device identifier (e.g., `disk3`)
   - Script shows available devices to help you choose
4. Enter output filename (e.g., `CA0001234567`)
   - Script adds `.iso` extension automatically
5. Confirm overwrite if file exists
6. Wait for ddrescue to complete

**What Happens**:
- DVD is unmounted
- Raw disk image created with 3 retry passes (`-r3`)
- 5% safety margin added to prevent data truncation
- Progress and time remaining displayed
- Log file created: `FILENAME.iso.log`

**Output**:
- `FILENAME.iso` - Disk image file
- `FILENAME.iso.log` - ddrescue log for error tracking

---

#### Option 2: Create MKV + MP4 from ISO

**Purpose**: Extract preservation masters (MKV) and create access files (MP4).

**Requirements**: ISO file (from Option 1 or existing)

**Steps**:
1. Choose Option 2
2. Select ISO file (uses just-created ISO or prompts for path)
3. Optionally eject physical DVD
4. Wait for processing

**What Happens**:
1. MakeMKV extracts all titles ≥15 seconds to MKV
2. Files renamed: `title_t00.mkv` → `FILENAME-PM01.mkv`
3. Field order detected for each title
4. Access MP4 created with appropriate deinterlacing
5. Log file moved to output directory on exit

**Output**:
- `FILENAME-PM01.mkv`, `FILENAME-PM02.mkv`, etc. - Preservation masters
- `FILENAME-A01.mp4`, `FILENAME-A02.mp4`, etc. - Access files
- `FILENAME-RF.log` - Complete operation log

---

#### Option 3: Create MKV Only

**Purpose**: Extract preservation masters without creating access files.

**Use Case**:
- Batch processing where you'll create access files later
- When you only need archival MKVs
- Saves time when processing multiple discs

Same as Option 2 but skips MP4 generation.

**Output**:
- `FILENAME-PM##.mkv` - Preservation master files only

---

#### Option 4: Create Access Files Only

**Purpose**: Generate access MP4s from existing MKV files.

**Use Case**:
- Regenerate access files with different settings
- Create access files after using Option 3
- Replace corrupted access files

**Steps**:
1. Choose Option 4
2. Enter path to directory containing MKV files
3. Script processes all `.mkv` files found
4. Shows success/failure count

**Supported Naming**:
- `FILENAME-PM##.mkv` (Preservation Master)
- `FILENAME-A##.mkv` (Access - will regenerate)

**Output**:
- `FILENAME-A##.mp4` - Access files for all MKVs

---

#### Option 5: Exit

Safely exits script and moves log file to output directory (if available).

## File Naming Convention

### Preservation Masters (MKV)
- **Format**: `IDENTIFIER-PM##.mkv`
- **Example**: `CA0001234567-PM01.mkv`
- **PM** = Preservation Master
- Numbers start at 01 (MakeMKV title 0 becomes PM01)

### Access Files (MP4)
- **Format**: `IDENTIFIER-A##.mp4`
- **Example**: `CA0001234567-A01.mp4`
- **A** = Access
- Numbers match corresponding PM file

### Log Files
- **Format**: `archive_dvd_video_YYYYMMDD_HHMMSS.log`
- **Final**: `IDENTIFIER-RF.log` (moved to output directory on exit)
- Contains complete terminal output for audit trail

### ISO Files
- **Format**: `IDENTIFIER.iso`
- **Example**: `CA0001234567.iso`
- **Log**: `IDENTIFIER.iso.log` (ddrescue error log)

## Technical Details

### Deinterlacing Strategy

The script automatically detects field order and applies appropriate processing:

| Field Order | Action | FFmpeg Filter |
|-------------|--------|---------------|
| Progressive | None | Direct encode (no deinterlacing) |
| Top Field First (TFF) | Blend deinterlace | `bwdif=mode=send_frame:parity=tff:deint=all` |
| Bottom Field First (BFF) | Blend deinterlace | `bwdif=mode=send_frame:parity=bff:deint=all` |
| Unknown/Empty | Blend deinterlace | `bwdif=mode=send_frame:parity=tff:deint=all` |

**Blend deinterlacing** (`send_frame` mode):
- Preserves original frame rate (30fps stays 30fps)
- Blends fields together for smooth appearance
- Smaller file sizes than bob deinterlacing
- Ideal for standard archival access copies

### Access File Encoding

MP4 files use these settings for broad compatibility:

**Video:**
- Codec: H.264 (libx264)
- Bitrate: 3 Mbps (min 3M, max 6M, buffer 6M)
- Preset: medium
- Profile: High, Level 3.1
- Pixel Format: yuv420p

**Audio:**
- Codec: AAC
- Bitrate: 192 kbps
- Channels: Stereo (2.0)

**Container:**
- Format: MP4
- Fast start enabled (web streaming)
- Chapters preserved
- Subtitles excluded

### DDrescue Safety Margin

The script adds a **5% safety margin** to the OS-reported DVD size.

**Why?**
- OS may underestimate disc size on damaged discs
- Prevents data truncation at end of disc
- Dual-layer DVDs may report inconsistent sizes

**How it works:**
```
Detected size:     4,700,372,992 bytes
Safety margin (5%):  235,018,650 bytes
Total read:        4,935,391,642 bytes
```

This ensures complete capture while maintaining progress reporting.

### Error Recovery

**DDrescue** (not `dd`) provides:
- 3 retry passes on read errors (`-r3`)
- Continues on errors instead of aborting
- Detailed log files showing bad sectors
- Can resume interrupted operations

Check the `.iso.log` file after imaging for any read errors.

## Workflow Recommendations

### Single Disc Workflow

1. Insert DVD
2. Run script → Option 1 (create ISO)
3. Continue → Option 2 (create MKV + MP4)
4. Verify output files
5. Store ISO separately or delete after verification

### Batch Processing Workflow

**Phase 1: Imaging** (requires admin privileges)
1. Create ISOs for all discs using Option 1
2. Name systematically: `CA0001234567`, `CA0001234568`, etc.
3. Store ISOs in staging directory

**Phase 2: Processing** (can run as standard user)
1. Use Option 2 to process each ISO
2. Can run on different machine
3. Can interrupt and resume

**Phase 3: Quality Control**
1. Verify MKV files play correctly
2. Check access MP4 files for quality
3. Verify file sizes are reasonable

### Storage Guidelines

**Preservation Masters (MKV)**:
- Store on redundant storage (RAID, cloud backup)
- Never delete after creating access copies
- Consider LTO tape for long-term archival
- These are your master copies

**Access Copies (MP4)**:
- Suitable for streaming servers and general use
- Can be regenerated from MKV if lost
- Lower storage priority than masters

**ISOs**:
- Can delete after successful MKV extraction
- Retain if you need perfect disc reconstruction
- Useful for creating physical copies later

## Troubleshooting

### "ERROR: Missing required dependencies"

**Solution:**
```bash
brew install ffmpeg ddrescue makemkv
which ffmpeg
which makemkvcon
```

### "ERROR: Device disk3 not found"

**Solution:**
1. Run `diskutil list` to see all devices
2. Look for your DVD (shows disc name)
3. Use device identifier (e.g., `disk3` not `/dev/disk3`)

### "ERROR: Failed to unmount"

**Solution:**
1. Close applications accessing the DVD
2. Try: `diskutil unmountDisk /dev/disk3`
3. Eject and reinsert disc if persistent

### MakeMKV "evaluation period expired"

MakeMKV is free during beta but requires periodic key updates.

**Solution:**
1. Visit [MakeMKV Forum](https://forum.makemkv.com/forum/viewtopic.php?f=5&t=1053)
2. Copy latest key from first post
3. Open MakeMKV GUI → Help → Register
4. Paste key and apply

Beta keys last 30-60 days. Bookmark the forum link.

### "makemkvcon: command not found"

**Solution:**
```bash
echo 'export PATH="/Applications/MakeMKV.app/Contents/MacOS:$PATH"' >> ~/.zshrc
source ~/.zshrc
which makemkvcon
```

### Permission denied with ddrescue

**Solution:**
- Script uses `sudo` and will prompt for password
- Ensure your account has admin privileges
- Or run entire script with: `sudo zsh "ARCHIVE DVD-VIDEO.zsh"`

### Script hangs during ISO creation

**Solution:**
1. Check `.iso.log` file for progress
2. Press Ctrl+C to cancel (safe - can resume)
3. Try cleaning disc
4. Try different DVD drive

### Access files look choppy

**Solution:**
1. Check if blend deinterlacing is appropriate for your content
2. For sports/action, consider using ARCHIVE DVD-VIDEO_HOME.zsh (bob deinterlacing)
3. Progressive content needs no deinterlacing

## Version Information

**Script**: ARCHIVE DVD-VIDEO.zsh
**Deinterlacing**: Blend (send_frame mode)
**Frame Rate**: Preserves original
**Dependencies**: ffmpeg, ddrescue, makemkvcon
**Platform**: macOS 10.15+

## Related Scripts

- **ARCHIVE DVD-VIDEO_HOME.zsh** - Uses bob deinterlacing (doubles frame rate)
- See repository for other variants

## License

See [LICENSE](LICENSE) file for details.

## Credits

- [GNU ddrescue](https://www.gnu.org/software/ddrescue/) - Disk imaging
- [MakeMKV](https://www.makemkv.com/) - DVD extraction
- [FFmpeg](https://ffmpeg.org/) - Video transcoding
- bwdif filter - High-quality deinterlacing
