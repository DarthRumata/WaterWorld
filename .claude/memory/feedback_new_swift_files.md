---
name: Add new Swift files to Xcode project
description: Always add new .swift files to project.pbxproj, otherwise they won't compile
type: feedback
---

When creating a new Swift file in this project, always add it to `WaterWorld.xcodeproj/project.pbxproj` in the file list (the group that lists paths like `UI/SimulationSettingsView.swift`). Files not listed there are invisible to the compiler regardless of being on disk.

**Why:** Xcode projects require explicit file registration in pbxproj — dropping a file into the folder is not enough.

**How to apply:** Immediately after writing any new `.swift` file with the Write tool, add its path to the sorted file list in `project.pbxproj`.
