import AccountContext
import Display
import Foundation
import ItemListUI
import PresentationDataUtils
import QwengramSettings
import QwengramSettingsSignal
import SwiftSignalKit
import TelegramPresentationData

private struct QwengramHistorySettingsEntry: ItemListNodeEntry {
    let stableId: Int32
    let title: String
    let value: Bool
    let updated: (Bool) -> Void

    var section: ItemListSectionId {
        return stableId == 0 ? 0 : 1
    }

    static func == (lhs: QwengramHistorySettingsEntry, rhs: QwengramHistorySettingsEntry) -> Bool {
        return lhs.stableId == rhs.stableId && lhs.title == rhs.title && lhs.value == rhs.value
    }

    static func < (lhs: QwengramHistorySettingsEntry, rhs: QwengramHistorySettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, value: value, sectionId: section, style: .blocks, updated: updated)
    }
}

public func qwengramHistorySettingsController(context: AccountContext) -> ViewController {
    let signal = combineLatest(context.sharedContext.presentationData, qwengramHistorySettingsSignal())
    |> deliverOnMainQueue
    |> map { presentationData, settings -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let entries: [QwengramHistorySettingsEntry] = [
            QwengramHistorySettingsEntry(stableId: 0, title: "Message History", value: settings.0, updated: {
                QwengramSettings.shared.messageHistoryEnabled = $0
            }),
            QwengramHistorySettingsEntry(stableId: 1, title: "Save edited messages", value: settings.1, updated: {
                QwengramSettings.shared.saveEditedMessages = $0
            }),
            QwengramHistorySettingsEntry(stableId: 2, title: "Save server-deleted messages", value: settings.2, updated: {
                QwengramSettings.shared.saveServerDeletedMessages = $0
            })
        ]
        let listPresentationData = ItemListPresentationData(presentationData)
        let controllerState = ItemListControllerState(presentationData: listPresentationData, title: .text("History Settings"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: listPresentationData, entries: entries, style: .blocks, animateChanges: true)
        return (controllerState, (listState, ()))
    }
    let controller = ItemListController(context: context, state: signal)
    controller.navigationPresentation = .default
    return controller
}
