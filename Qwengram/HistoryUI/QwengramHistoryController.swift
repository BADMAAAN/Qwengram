import AccountContext
import Display
import Foundation
import ItemListUI
import LocalizedPeerData
import Postbox
import PresentationDataUtils
import QwengramHistoryStorage
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData

private struct QwengramHistoryEntry: ItemListNodeEntry {
    let stableId: Int32
    let section: ItemListSectionId
    let title: String
    let text: String
    var action: (() -> Void)? = nil

    static func == (lhs: QwengramHistoryEntry, rhs: QwengramHistoryEntry) -> Bool {
        return lhs.stableId == rhs.stableId && lhs.section == rhs.section && lhs.title == rhs.title && lhs.text == rhs.text && (lhs.action == nil) == (rhs.action == nil)
    }

    static func < (lhs: QwengramHistoryEntry, rhs: QwengramHistoryEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        if let action = action {
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: title, label: text, labelStyle: .multilineDetailText, sectionId: section, style: .blocks, action: action)
        } else {
            return ItemListTextItem(presentationData: presentationData, text: .plain(title.isEmpty ? text : "\(title)\n\n\(text)"), sectionId: section)
        }
    }
}

private struct QwengramHistoryRow {
    let record: QwengramHistoryRecord
    let peer: EnginePeer?
}

private func qwengramHistoryPeer(transaction: Transaction, packedId: Int64) -> EnginePeer? {
    // Archive JSON can decode an arbitrary Int64. Reject invalid packed IDs
    // before PeerId's debug assertions, and only resolve supported cloud peers.
    guard packedId >= 0, UInt64(packedId) >> 59 == 0 else {
        return nil
    }
    let namespace = Int32((packedId >> 32) & 7)
    guard namespace == Namespaces.Peer.CloudUser._internalGetInt32Value()
        || namespace == Namespaces.Peer.CloudGroup._internalGetInt32Value()
        || namespace == Namespaces.Peer.CloudChannel._internalGetInt32Value() else {
        return nil
    }
    switch transaction.getPeer(EnginePeer.Id(packedId)) {
    case let user as TelegramUser:
        return .user(user)
    case let group as TelegramGroup:
        return .legacyGroup(group)
    case let channel as TelegramChannel:
        return .channel(channel)
    default:
        return nil
    }
}

private func qwengramHistoryPeerTitle(_ peer: EnginePeer?, presentationData: PresentationData) -> String {
    let title = peer?.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder).trimmingCharacters(in: .whitespacesAndNewlines)
    return title.flatMap { $0.isEmpty ? nil : $0 } ?? "Unknown or deleted peer"
}

private func qwengramHistoryDateFormatter() -> DateFormatter {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .medium
    return formatter
}

public func qwengramHistoryController(context: AccountContext) -> ViewController {
    var pushControllerImpl: ((ViewController) -> Void)?
    let formatter = qwengramHistoryDateFormatter()
    // Read only the selected account's local archive. No network peer fetches.
    let archive: Signal<([QwengramHistoryRow], Int)?, NoError> = .single(nil)
    |> then(context.account.postbox.transaction { transaction -> ([QwengramHistoryRow], Int)? in
        let result = QwengramHistoryStore.listRecords(transaction: transaction)
        let rows = qwengramHistoryNewestFirst(result.records).map { record in
            QwengramHistoryRow(record: record, peer: qwengramHistoryPeer(transaction: transaction, packedId: record.key.peerId))
        }
        return (rows, result.unreadableCount)
    })
    let signal = combineLatest(context.sharedContext.presentationData, archive)
    |> deliverOnMainQueue
    |> map { presentationData, archive -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var entries: [QwengramHistoryEntry] = []
        if let (rows, unreadableCount) = archive {
            if unreadableCount > 0 {
                entries.append(QwengramHistoryEntry(stableId: 0, section: 0, title: "Some history could not be read", text: "\(unreadableCount) saved records are damaged or unsupported. Other records remain available."))
            }
            if rows.isEmpty {
                entries.append(QwengramHistoryEntry(stableId: 1, section: 1, title: unreadableCount == 0 ? "No saved history" : "No readable history", text: unreadableCount == 0 ? "Saved edits and server deletions will appear here." : "The saved records could not be loaded."))
            }
            for (index, row) in rows.enumerated() {
                let event = qwengramHistoryLatestEvent(row.record)
                let status = event.map { qwengramHistoryEventTitle($0, detail: false) } ?? "Saved revision"
                let time = qwengramHistoryDate(event?.observedTimestamp ?? qwengramHistoryLatestTimestamp(row.record), formatter: formatter)
                entries.append(QwengramHistoryEntry(
                    stableId: Int32(index + 2),
                    section: 1,
                    title: qwengramHistoryPeerTitle(row.peer, presentationData: presentationData),
                    text: "\(status) · \(time)\n\(qwengramHistoryPreview(row.record))",
                    action: { pushControllerImpl?(qwengramHistoryDetailController(context: context, key: row.record.key)) }
                ))
            }
        } else {
            entries.append(QwengramHistoryEntry(stableId: 0, section: 0, title: "", text: "Loading history…"))
        }
        let listPresentationData = ItemListPresentationData(presentationData)
        let controllerState = ItemListControllerState(presentationData: listPresentationData, title: .text("History"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        return (controllerState, (ItemListNodeState(presentationData: listPresentationData, entries: entries, style: .blocks, animateChanges: false), ()))
    }
    let controller = ItemListController(context: context, state: signal)
    controller.navigationPresentation = .default
    pushControllerImpl = { [weak controller] viewController in
        (controller?.navigationController as? NavigationController)?.pushViewController(viewController, animated: true)
    }
    return controller
}

private enum QwengramHistoryDetailState {
    case loading
    case loaded(QwengramHistoryRow)
    case missing
    case unreadable
}

private func qwengramHistoryDetailController(context: AccountContext, key: QwengramHistoryMessageKey) -> ViewController {
    let formatter = qwengramHistoryDateFormatter()
    let record: Signal<QwengramHistoryDetailState, NoError> = .single(.loading)
    |> then(context.account.postbox.transaction { transaction -> QwengramHistoryDetailState in
        do {
            guard let record = try QwengramHistoryStore.load(transaction: transaction, key: key) else {
                return .missing
            }
            return .loaded(QwengramHistoryRow(record: record, peer: qwengramHistoryPeer(transaction: transaction, packedId: key.peerId)))
        } catch {
            return .unreadable
        }
    })
    let signal = combineLatest(context.sharedContext.presentationData, record)
    |> deliverOnMainQueue
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var entries: [QwengramHistoryEntry] = []
        switch state {
        case .loading:
            entries.append(QwengramHistoryEntry(stableId: 0, section: 0, title: "", text: "Loading history…"))
        case .missing:
            entries.append(QwengramHistoryEntry(stableId: 0, section: 0, title: "History no longer available", text: "This record may have reached the archive retention limit."))
        case .unreadable:
            entries.append(QwengramHistoryEntry(stableId: 0, section: 0, title: "Unable to read history", text: "This saved record is damaged or unsupported."))
        case let .loaded(row):
            entries.append(QwengramHistoryEntry(stableId: 0, section: 0, title: qwengramHistoryPeerTitle(row.peer, presentationData: presentationData), text: "Saved history · Oldest first"))
            let timeline = qwengramHistoryTimeline(row.record)
            if timeline.isEmpty {
                entries.append(QwengramHistoryEntry(stableId: 1, section: 1, title: "No saved revisions or events", text: "This record has no saved content."))
            }
            for (index, item) in timeline.enumerated() {
                entries.append(QwengramHistoryEntry(stableId: Int32(index + 1), section: Int32(index + 1), title: "\(item.title) · \(qwengramHistoryDate(item.timestamp, formatter: formatter))", text: item.text))
            }
        }
        let listPresentationData = ItemListPresentationData(presentationData)
        let controllerState = ItemListControllerState(presentationData: listPresentationData, title: .text("Message History"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        return (controllerState, (ItemListNodeState(presentationData: listPresentationData, entries: entries, style: .blocks, animateChanges: false), ()))
    }
    let controller = ItemListController(context: context, state: signal)
    controller.navigationPresentation = .default
    return controller
}
