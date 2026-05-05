# 0.2.0

## HideMyData is now notarized!

* Integrate Sparkle for automatic updates. 
* `Check for Updates…` menu item in the app menu.
* Switched to xcodegen.
* Allow removing metadata from files when saving.

### ⚠️ Manual cleanup for users on v0.1.0

Because of the notarization and because I changed the app bundle ID, a one-timemanual reinstall is needed.

* If you use Raycast or AppCleaner - you're good, just uninstall there.

Manually:

* Drag the app to trash
* The old sandbox container at `~/Library/Containers/com.maciejonos.HideMyData/` is left behind. To reclaim the disk space:

```bash
rm -rf ~/Library/Containers/com.maciejonos.HideMyData
```

No further bundle ID changes are planned — future versions update in place via Sparkle.

# 0.1.0

* Initial release.
