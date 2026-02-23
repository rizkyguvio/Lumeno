import UIKit

/// Centralized haptic feedback manager for Lumeño, ported from ThinkTank.
final class HapticManager {

    static let shared = HapticManager()

    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private let notification = UINotificationFeedbackGenerator()
    private let selection = UISelectionFeedbackGenerator()

    private init() {
        prepareAll()
    }

    private func prepareAll() {
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        rigidImpact.prepare()
        softImpact.prepare()
        notification.prepare()
        selection.prepare()
    }

    // MARK: - Study Feedback

    func studyAgain() {
        notification.notificationOccurred(.error)
        heavyImpact.impactOccurred(intensity: 1.0)
        prepareAll()
    }

    func studyHard() {
        mediumImpact.impactOccurred(intensity: 0.8)
        mediumImpact.prepare()
    }

    func studyGood() {
        selection.selectionChanged()
        selection.prepare()
    }

    func studyEasy() {
        notification.notificationOccurred(.success)
        notification.prepare()
    }

    // MARK: - General Interactions

    func success() {
        notification.notificationOccurred(.success)
        notification.prepare()
    }

    func softTap() {
        softImpact.impactOccurred(intensity: 0.4)
        softImpact.prepare()
    }

    func selectionTick() {
        selection.selectionChanged()
        selection.prepare()
    }

    func lightTap() {
        lightImpact.impactOccurred(intensity: 0.5)
        lightImpact.prepare()
    }
}
