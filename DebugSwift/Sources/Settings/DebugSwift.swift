//
//  DebugSwift.swift
//  DebugSwift
//
//  Created by Matheus Gois on 16/12/23.
//

import UIKit

public class DebugSwift {
    
    public init() {}
    
    @discardableResult
    @MainActor
    public func setup(
        hideFeatures features: [DebugSwiftFeature] = [],
        disable methods: [DebugSwiftSwizzleFeature] = [],
        enableBetaFeatures betaFeatures: [DebugSwiftBetaFeature] = []
    ) -> Self {
        FeatureHandling.setup(hide: features, disable: methods, enableBeta: betaFeatures)
        LaunchTimeTracker.shared.measureAppStartUpTime()

        return self
    }

    @discardableResult
    public func show() -> Self {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            FloatViewManager.show()
        }

        return self
    }

    @discardableResult
    @MainActor
    public func hide() -> Self {
        FloatViewManager.remove()
        return self
    }

    @discardableResult
    @MainActor
    public func toggle() -> Self {
        FloatViewManager.toggle()
<<<<<<< HEAD
    }
    
    public static func theme(appearance: Appearance) {
        Theme.shared.setAppearance(appearance: appearance)
    }
    
    public static func toggleDebugger(_ enable: Bool) {
        DebugSwift.Debugger.enable = enable
    }
}

extension DebugSwift {
    public enum Network {
        public static var ignoredURLs = [String]()
        public static var onlyURLs = [String]()
    }

    public enum App {
        public static var customInfo: (() -> [CustomData])?
        public static var customAction: (() -> [CustomAction])?
        public static var customControllers: (() -> [UIViewController])?
    }

    public enum Console {
        public static var ignoredLogs = [String]()
        public static var onlyLogs = [String]()
    }

    enum Debugger {
        @UserDefaultAccess(key: .debugger, defaultValue: true)
        public static var enable: Bool
=======

        return self
>>>>>>> upstream/main
    }
}
