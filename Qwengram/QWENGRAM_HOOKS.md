# Qwengram upstream hooks

- **File:** `submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/PeerInfoSettingsItems.swift`  
  **Section:** `SettingsSection` and `settingsItems`  
  **Reason:** Adds the Qwengram settings entry.  
  **Module:** `QwengramSettingsUI`  
  **Rebase note:** Preserve the separate section and disclosure action.

- **File:** `submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/PeerInfoScreen.swift`  
  **Section:** `PeerInfoSettingsSection`  
  **Reason:** Adds the Qwengram settings destination.  
  **Module:** `QwengramSettingsUI`  
  **Rebase note:** Preserve the destination case.

- **File:** `submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/PeerInfoScreenSettingsActions.swift`  
  **Section:** `openSettings(section:)`  
  **Reason:** Routes the destination to `qwengramSettingsController(context:)`.  
  **Module:** `QwengramSettingsUI`  
  **Rebase note:** Preserve the import and switch case.

- **File:** `submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/BUILD`  
  **Section:** `PeerInfoScreen` dependencies  
  **Reason:** Links the Qwengram settings UI module.  
  **Module:** `QwengramSettingsUI`  
  **Rebase note:** Preserve the direct Bazel dependency.
