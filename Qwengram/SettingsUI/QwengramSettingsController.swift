import AccountContext
import Display
import Foundation
import ItemListUI
import PresentationDataUtils
import QwengramSettings
import QwengramSettingsSignal
import SwiftSignalKit
import TelegramPresentationData

private enum QwengramSettingsEntry: ItemListNodeEntry {
    case header(Int32, Int32, String)
    case toggle(Int32, Int32, String, Bool, (Bool) -> Void)
    case navigation(Int32, Int32, String, Bool, () -> Void)
    case placeholder(Int32, Int32, String, String)
    case about(Int32, Int32, String)

    var section: ItemListSectionId {
        switch self {
        case let .header(_, section, _), let .toggle(_, section, _, _, _), let .navigation(_, section, _, _, _), let .placeholder(_, section, _, _), let .about(_, section, _):
            return section
        }
    }

    var stableId: Int32 {
        switch self {
        case let .header(id, _, _), let .toggle(id, _, _, _, _), let .navigation(id, _, _, _, _), let .placeholder(id, _, _, _), let .about(id, _, _):
            return id
        }
    }

    static func == (lhs: QwengramSettingsEntry, rhs: QwengramSettingsEntry) -> Bool {
        switch (lhs, rhs) {
        case let (.header(lId, lSection, lText), .header(rId, rSection, rText)):
            return lId == rId && lSection == rSection && lText == rText
        case let (.toggle(lId, lSection, lTitle, lValue, _), .toggle(rId, rSection, rTitle, rValue, _)):
            return lId == rId && lSection == rSection && lTitle == rTitle && lValue == rValue
        case let (.navigation(lId, lSection, lTitle, lEnabled, _), .navigation(rId, rSection, rTitle, rEnabled, _)):
            return lId == rId && lSection == rSection && lTitle == rTitle && lEnabled == rEnabled
        case let (.placeholder(lId, lSection, lTitle, lLabel), .placeholder(rId, rSection, rTitle, rLabel)):
            return lId == rId && lSection == rSection && lTitle == rTitle && lLabel == rLabel
        case let (.about(lId, lSection, lText), .about(rId, rSection, rText)):
            return lId == rId && lSection == rSection && lText == rText
        default:
            return false
        }
    }

    static func < (lhs: QwengramSettingsEntry, rhs: QwengramSettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        switch self {
        case let .header(_, section, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: section)
        case let .toggle(_, section, title, value, updated):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, value: value, sectionId: section, style: .blocks, updated: updated)
        case let .navigation(_, section, title, enabled, action):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: title, enabled: enabled, label: "", sectionId: section, style: .blocks, action: action)
        case let .placeholder(_, section, title, label):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: title, enabled: false, label: label, sectionId: section, style: .blocks, disclosureStyle: .none, action: nil)
        case let .about(_, section, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: section)
        }
    }
}

private final class QwengramSettingsArguments {
    let openBotsHub: () -> Void
    let openQwenProvider: () -> Void

    init(openBotsHub: @escaping () -> Void, openQwenProvider: @escaping () -> Void) {
        self.openBotsHub = openBotsHub
        self.openQwenProvider = openQwenProvider
    }
}

public func qwengramSettingsController(context: AccountContext) -> ViewController {
    var pushControllerImpl: ((ViewController) -> Void)?
    let arguments = QwengramSettingsArguments(
        openBotsHub: { pushControllerImpl?(qwengramBotsController(context: context)) },
        openQwenProvider: { pushControllerImpl?(qwengramAISettingsController(context: context)) }
    )
    let signal = combineLatest(
        context.sharedContext.presentationData,
        qwengramEnabledSignal(),
        botsHubEnabledSignal()
    )
    |> deliverOnMainQueue
    |> map { presentationData, qwengramEnabled, botsHubEnabled -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let entries: [QwengramSettingsEntry] = [
            .header(0, 0, "General"),
            .toggle(1, 0, "Qwengram Enabled", qwengramEnabled, { value in
                QwengramSettings.shared.qwengramEnabled = value
            }),
            .header(2, 1, "Bots"),
            .toggle(3, 1, "Bots Hub Enabled", botsHubEnabled, { value in
                QwengramSettings.shared.botsHubEnabled = value
            }),
            .navigation(4, 1, "Open Bots Hub", botsHubEnabled, arguments.openBotsHub),
            .header(5, 2, "AI"),
            .navigation(6, 2, "Qwen Provider", true, arguments.openQwenProvider),
            .header(7, 3, "Coming Later"),
            .placeholder(8, 3, "Ghost Mode", "Coming soon"),
            .placeholder(9, 3, "Message History", "Coming soon"),
            .placeholder(10, 3, "Media Archive", "Coming soon"),
            .header(11, 4, "About"),
            .about(12, 4, "Qwengram Foundation")
        ]
        let listPresentationData = ItemListPresentationData(presentationData)
        let controllerState = ItemListControllerState(presentationData: listPresentationData, title: .text("Qwengram"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: listPresentationData, entries: entries, style: .blocks, animateChanges: true)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    controller.navigationPresentation = .default
    pushControllerImpl = { [weak controller] viewController in
        (controller?.navigationController as? NavigationController)?.pushViewController(viewController, animated: true)
    }
    return controller
}
