import Foundation
import QwengramSettings
import SwiftSignalKit

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
