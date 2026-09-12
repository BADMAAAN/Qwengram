import Foundation
import QwengramSettings
import SwiftSignalKit

public func qwengramHistorySettingsSignal() -> Signal<(Bool, Bool, Bool), NoError> {
    return Signal { subscriber in
        let emit = {
            let settings = QwengramSettings.shared
            subscriber.putNext((settings.messageHistoryEnabled, settings.saveEditedMessages, settings.saveServerDeletedMessages))
        }
        let observer = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: UserDefaults.standard,
            queue: nil
        ) { _ in
            emit()
        }
        emit()
        return ActionDisposable {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    |> distinctUntilChanged(isEqual: { lhs, rhs in
        return lhs.0 == rhs.0 && lhs.1 == rhs.1 && lhs.2 == rhs.2
    })
}

public func qwengramEnabledSignal() -> Signal<Bool, NoError> {
    let initial = Signal<Bool, NoError>.single(QwengramSettings.shared.qwengramEnabled)
    let changes = Signal<Bool, NoError> { subscriber in
        let observer = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: UserDefaults.standard,
            queue: nil
        ) { _ in
            subscriber.putNext(QwengramSettings.shared.qwengramEnabled)
        }
        return ActionDisposable {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    return (initial |> then(changes)) |> distinctUntilChanged
}

public func botsHubEnabledSignal() -> Signal<Bool, NoError> {
    let initial = Signal<Bool, NoError>.single(QwengramSettings.shared.botsHubEnabled)
    let changes = Signal<Bool, NoError> { subscriber in
        let observer = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: UserDefaults.standard,
            queue: nil
        ) { _ in
            subscriber.putNext(QwengramSettings.shared.botsHubEnabled)
        }
        return ActionDisposable {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    return (initial |> then(changes)) |> distinctUntilChanged
}
