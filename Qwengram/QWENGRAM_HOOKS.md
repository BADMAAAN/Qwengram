# Qwengram upstream hooks

- **File:** `submodules/Postbox/Sources/SeedConfiguration.swift`
  **Section:** `MessageUpdateSource`, `SeedConfiguration.beforeMessageUpdate`
  **Reason:** Optional synchronous, non-throwing pre-write callback with the current
  transaction, rendered OLD, proposed NEW and source (`addMessages` / `updateMessage`).
  **Module:** Postbox API; no Qwengram storage dependency.
  **Rebase note:** Keep the default `nil`. Callers must not retain the transaction
  or re-enter message/history writes from this callback.

- **File:** `submodules/Postbox/Sources/MessageHistoryTable.swift`
  **Section:** `addMessages`, `processIndexOperations`
  **Reason:** Read OLD by its physical history index before `justUpdate` for
  `InsertExistingMessage`. For timestamp replacement, recognize only adjacent
  `Remove(oldIndex)` + `InsertMessage(new)` with identical MessageId and different
  timestamps; call before OLD is physically removed.
  **Module:** Postbox internal callback (`IntermediateMessage`, `InternalStoreMessage`).
  **Rebase note:** Keep index generation, operation order, removal accumulation,
  read-state commits and deferred media updates unchanged. Do not pre-snapshot the
  input array, look OLD up by the final MessageId index, deduplicate or split batches.
  Plain inserts without OLD do not invoke the callback. Other operation callers
  retain the default `nil` callback.

- **File:** `submodules/Postbox/Sources/Postbox.swift`
  **Section:** `PostboxImpl.addMessages`, `PostboxImpl.updateMessage`
  **Reason:** Capture the live Transaction, render IntermediateMessage as Message,
  convert InternalStoreMessage to StoreMessage, then invoke SeedConfiguration.
  Explicit update calls the hook only after `.update(updatedMessage)` is returned
  and before `messageHistoryTable.updateMessage`; `.skip` has no hook.
  **Module:** Postbox.
  **Rebase note:** Preserve all StoreMessage fields during conversion and keep the
  callback synchronous. Do not install an additional table callback for explicit
  updateMessage, which would double-count that path.

- **File:** `submodules/TelegramCore/Sources/SyncCore/SyncCore_StandaloneAccountTransaction.swift`
  **Section:** `telegramPostboxSeedConfiguration`
  **Reason:** Installs `qwengramBeforeMessageUpdate` for account Postbox writes.
  **Module:** TelegramCore / `Qwengram/HistoryIntegration`.
  **Rebase note:** Integration archives existing cloud messages with unchanged
  identity; secret chats and local-to-cloud reconciliation are excluded.

- **File:** `submodules/TelegramCore/BUILD`
  **Section:** TelegramCore sources and dependencies
  **Reason:** Compiles `//Qwengram/HistoryIntegration:Sources` inside TelegramCore
  and links `//Qwengram/HistoryStorage:QwengramHistoryStorage`.
  **Module:** TelegramCore.
  **Rebase note:** Integration is a source filegroup, not a Swift module importing
  TelegramCore. The dependency direction is TelegramCore -> HistoryStorage ->
  Postbox. Never add a Postbox -> HistoryStorage or HistoryStorage -> TelegramCore
  dependency. Upstream hooks use `// MARK: NAGRAM` as required by AGENTS.md;
  BUILD comments use `# // MARK: NAGRAM` for valid Starlark syntax.

## History edit content and failure contract

The content allowlist compares text, UTF-16 text entities (including URL, language,
mention, custom emoji ID and formatted-date parameters), image/file identity and
contact content. Entities are canonicalized by range, type and sorted parameter
key/value pairs before comparison, preserving duplicate entities. Supported media
are compared as a multiset: embedded/reference rendering order is ignored, but
each occurrence must match once. Custom emoji sticker-pack references are deliberately excluded.
Reactions, views, tags, flags, local state, timestamps/edit timestamps, author,
forward/reply/thread metadata, resources, file references, thumbnails, file
size/duration and download metadata do not trigger revisions. Expired-content
tombstones suppress the entire hook, including any simultaneous TTL text cleanup.
V1 conservatively ignores web previews, polls/results, locations and other media
types; edits confined to those unsupported media types are not archived.

OLD snapshots retain text/entities, original and server-edit timestamps, author,
forward/reply/thread metadata and supported descriptive media metadata. No media
bytes, access hashes, file references, local paths or resources are stored.
After a meaningful change, one load and one upsert append a numbered OLD revision
and its edit event with the same observation time. Source is explicit; addMessages
uses `syncDetectedEdit`, updateMessage uses `edit`. No cross-call deduplication:
reverting content and later editing it again must preserve both transitions.
Read/decode/validation/encoding/size failures are caught inside integration; a
content-free diagnostic is logged and the Telegram write continues. Upsert validates
and encodes before mutating the ordered list, so a failed archive write does not
leave an orphan event. Low-level process/database failures are not recoverable
Swift storage errors and are outside this contract.

## History edit validation cases

Here A/B/C are distinct supported content values of the same cloud MessageId.
Each saved OLD has one matching event. Batch operations remain sequential.

| Input | OLD revisions | Telegram final content |
| --- | --- | --- |
| A -> B | A | B |
| A -> [B, C] | A, B | C |
| A -> [B, B] | A | B |
| Entity permutation only (including duplicate entities) | none | reordered entities |
| Media permutation only (including embedded/reference order) | none | reordered media |
| Text, entity range/type/parameter or supported media content change | A | B |
| Entity or supported media multiplicity change | A | B |
| A(t1) -> [B(t2), C(t3)] | A(t1), B(t2) | C(t3) |
| New message without OLD | none | new message |
| Technical-only update | none | updated technical state |
| Storage failure | no partial revision/event write | NEW still written |

These cases are checked by source review and an operation-order model on Windows;
they are not a live Postbox/Swift runtime test. Full app build and runtime validation
still require macOS/Xcode. No Actions are used.

## Server delete capture

- **File:** `submodules/TelegramCore/Sources/Account/AccountIntermediateState.swift`
  **Section:** `DeleteMessages`, `deleteMessages`
  **Reason:** Carries an optional typed server source with the existing ordered
  deletion operation. The default is `nil`, including scheduled/ephemeral/quick-reply
  callers. Global-ID deletion operations originate only in `updateDeleteMessages`.
  **Rebase note:** Preserve the source through operation replay/optimization.
  Swift modification sites use `// MARK: NAGRAM`.

- **File:** `submodules/TelegramCore/Sources/State/AccountStateManagementUtils.swift`
  **Section:** accepted `updateDeleteChannelMessages`, channel difference
  `otherUpdates`, and deletion operation replay
  **Reason:** Marks only explicit server delete updates. During replay, calls
  `qwengramBeforeServerDelete` before the existing physical deletion. Global IDs
  are resolved by `Transaction.messageIdsForGlobalIds`, the same lookup used by
  Telegram's delete path (cloud users and basic groups); channel/supergroup IDs
  retain their peer ID and cloud namespace.
  **Rebase note:** Keep pts acceptance, operation order, resource cleanup, thread
  statistics and deleted-message notifications unchanged. Do not mark generic
  deletes or infer deletes from missing messages in channel differences.

Integration requires a live OLD cloud message in a private chat, basic group,
channel or supergroup. Each ID is captured once per call. It appends one OLD
revision and one `.delete` event with reason `serverDelete` and source
`updateDeleteMessages`, `updateDeleteChannelMessages` or `channelDifference`, then
performs one validated upsert. The event confirms server-reported deletion; the
initiator is unknown. It must never be displayed as "deleted by the interlocutor".
The existing snapshot fields and TelegramCore -> HistoryStorage -> Postbox
dependency direction are reused; no Postbox API or BUILD change is needed.

Local delete-for-me/delete-for-everyone, clear history, validation cleanup,
min-available history, and local expiration do not call this hook. Scheduled,
ephemeral, quick-reply and secret-chat namespaces are excluded. Delete updates
carry no cause, so all messages with autoremove/autoclear attributes (including
unstarted timers and view-once) are conservatively skipped, even for a manual
server deletion. Expired-media tombstones and history-cleared placeholders are
also skipped. A local interactive delete physically removes OLD in its transaction;
a subsequent server echo or repeated update has no live OLD and does not archive
an earlier HistoryStorage revision as a new delete snapshot.

Read/decode/validation/encoding/size errors are caught per ID, with a content-free
diagnostic. Other IDs and Telegram's normal delete continue; snapshot/event are
never written separately. Process/database failures remain outside Swift error
recovery, as with edit capture.

Delete validation uses source review and a transaction-order model on Windows:
private/basic-group global-ID resolution, channel/supergroup peer identity,
duplicate IDs/echoes, local deletion followed by echo, all excluded namespaces,
TTL/autoclear/expired/clear placeholders, non-server cleanup paths and injected
storage failures. This is not a Swift/Postbox runtime test; macOS/Xcode build and
runtime validation remain unavailable here. No Actions are used.

## Other upstream hooks

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

- **File:** `submodules/TelegramUI/Sources/ChatInterfaceStateContextMenus.swift`
  **Section:** `contextMenuForChatPresentationInterfaceState(...)`
  **Reason:** Adds the Qwengram AI message context-menu entry for a single, non-empty, non-secret text message.
  **Module:** `QwengramSettingsUI`
  **Rebase note:** Preserve the local-only handoff to `qwengramMessageAIController(context:text:)`; do not invoke an AI provider from the menu action.

- **File:** `submodules/TelegramUI/BUILD`
  **Section:** `TelegramUI` dependencies
  **Reason:** Makes `QwengramSettingsUI` available to the TelegramUI context-menu hook.
  **Module:** `QwengramSettingsUI`
  **Rebase note:** Preserve the direct Bazel dependency next to the other fork UI dependencies.

- **File:** `Nagram/Demo/Sources/NagramDemo.swift`
  **Section:** Demo message seeding
  **Reason:** Splits a large `StoreMessage` map expression into smaller typed expressions so Xcode 26.2 can type-check it during the ARM64 build.
  **Module:** `NagramDemo`
  **Rebase note:** Compatibility-only refactor; preserve behavior and re-test whether the workaround is still required after upstream changes.
