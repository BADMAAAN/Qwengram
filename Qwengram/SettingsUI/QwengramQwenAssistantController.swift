import AccountContext
import Display
import Foundation
import ItemListUI
import QwengramAI
import QwengramSettings
import SwiftSignalKit
import TelegramPresentationData

private final class QwengramQwenAssistantArguments {
    let updateInput: (String) -> Void
    let send: () -> Void

    init(updateInput: @escaping (String) -> Void, send: @escaping () -> Void) {
        self.updateInput = updateInput
        self.send = send
    }
}

private enum QwengramQwenAssistantEntry: ItemListNodeEntry {
    case header(Int32, Int32, String)
    case message(Int32, Int32, QwengramAIMessage)
    case loading(Int32, Int32)
    case input(Int32, Int32, String, Bool)
    case send(Int32, Int32, Bool)

    var section: ItemListSectionId {
        switch self {
        case let .header(_, section, _), let .message(_, section, _), let .loading(_, section), let .input(_, section, _, _), let .send(_, section, _):
            return section
        }
    }

    var stableId: Int32 {
        switch self {
        case let .header(id, _, _), let .message(id, _, _), let .loading(id, _), let .input(id, _, _, _), let .send(id, _, _):
            return id
        }
    }

    static func == (lhs: QwengramQwenAssistantEntry, rhs: QwengramQwenAssistantEntry) -> Bool {
        switch (lhs, rhs) {
        case let (.header(lId, lSection, lText), .header(rId, rSection, rText)):
            return lId == rId && lSection == rSection && lText == rText
        case let (.message(lId, lSection, lMessage), .message(rId, rSection, rMessage)):
            return lId == rId && lSection == rSection && lMessage == rMessage
        case let (.loading(lId, lSection), .loading(rId, rSection)):
            return lId == rId && lSection == rSection
        case let (.input(lId, lSection, lText, lEnabled), .input(rId, rSection, rText, rEnabled)):
            return lId == rId && lSection == rSection && lText == rText && lEnabled == rEnabled
        case let (.send(lId, lSection, lEnabled), .send(rId, rSection, rEnabled)):
            return lId == rId && lSection == rSection && lEnabled == rEnabled
        default:
            return false
        }
    }

    static func < (lhs: QwengramQwenAssistantEntry, rhs: QwengramQwenAssistantEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! QwengramQwenAssistantArguments
        switch self {
        case let .header(_, section, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: section)
        case let .message(_, section, message):
            let title = message.role == .user ? "You" : "Qwen"
            return ItemListTextItem(presentationData: presentationData, text: .plain("\(title): \(message.content)"), sectionId: section)
        case let .loading(_, section):
            return ItemListTextItem(presentationData: presentationData, text: .plain("Qwen is thinking…"), sectionId: section)
        case let .input(_, section, text, enabled):
            return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(string: "Message", textColor: presentationData.theme.list.itemPrimaryTextColor), text: text, placeholder: "Ask Qwen", type: .regular(capitalization: true, autocorrection: true), clearType: .onFocus, sectionId: section, textUpdated: enabled ? arguments.updateInput : { _ in }, action: {})
        case let .send(_, section, enabled):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: "Send", kind: .generic, alignment: .natural, sectionId: section, style: .blocks, action: enabled ? arguments.send : {})
        }
    }
}

public func qwengramQwenAssistantController(context: AccountContext) -> ViewController {
    let updatePromise = ValuePromise<Int32>(0, ignoreRepeated: false)
    var updateValue: Int32 = 0
    var input = ""
    var messages: [QwengramAIMessage] = []
    var isSending = false
    var controller: ItemListController?
    let refresh: () -> Void = {
        updateValue += 1
        updatePromise.set(updateValue)
    }
    let showError: (String) -> Void = { text in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        controller?.present(textAlertController(context: context, title: "Qwen Assistant", text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
    }
    let arguments = QwengramQwenAssistantArguments(updateInput: { value in
        input = value
    }, send: {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else {
            return
        }
        let apiKey: String
        do {
            guard let storedKey = try QwengramAIKeychain.loadQwenAPIKey(), !storedKey.isEmpty else {
                showError("Configure Qwen Provider in Qwengram Settings → AI before sending a message.")
                return
            }
            apiKey = storedKey
        } catch {
            showError("Unable to access the Qwen API key. Configure Qwen Provider in Qwengram Settings → AI.")
            return
        }
        let model = QwengramSettings.shared.qwenModel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !model.isEmpty else {
            showError("Configure a Qwen model in Qwengram Settings → AI before sending a message.")
            return
        }
        messages.append(QwengramAIMessage(role: .user, content: text))
        input = ""
        isSending = true
        refresh()
        QwengramQwenProvider(apiKey: apiKey).generateText(model: model, messages: messages) { result in
            Queue.mainQueue().async {
                isSending = false
                switch result {
                case let .success(response):
                    messages.append(QwengramAIMessage(role: .assistant, content: response))
                case let .failure(error):
                    let message: String
                    switch error {
                    case .invalidRequest:
                        message = "The Qwen request could not be created. Check the Qwen Provider settings."
                    case .network:
                        message = "Unable to reach Qwen. Check your network connection and try again."
                    case let .httpStatus(status):
                        message = "Qwen returned an error (HTTP \(status)). Check your Provider settings and try again."
                    case .decoding:
                        message = "Qwen returned an unreadable response. Try again later."
                    case .emptyResponse:
                        message = "Qwen returned an empty response. Try again."
                    }
                    showError(message)
                }
                refresh()
            }
        }
    })
    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, updatePromise.get())
    |> map { presentationData, _ -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let listPresentationData = ItemListPresentationData(presentationData)
        var entries: [QwengramQwenAssistantEntry] = [.header(0, 0, "Conversation")]
        var stableId: Int32 = 1
        for message in messages {
            entries.append(.message(stableId, 0, message))
            stableId += 1
        }
        if isSending {
            entries.append(.loading(stableId, 0))
            stableId += 1
        }
        entries.append(.header(stableId, 1, "Message"))
        stableId += 1
        entries.append(.input(stableId, 1, input, !isSending))
        stableId += 1
        entries.append(.send(stableId, 2, !isSending))
        let controllerState = ItemListControllerState(presentationData: listPresentationData, title: .text("Qwen Assistant"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        return (controllerState, (ItemListNodeState(presentationData: listPresentationData, entries: entries, style: .blocks, animateChanges: true), arguments))
    }
    let itemListController = ItemListController(context: context, state: signal)
    itemListController.navigationPresentation = .default
    controller = itemListController
    return itemListController
}
