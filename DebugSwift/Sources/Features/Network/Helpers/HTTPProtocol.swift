//
//  HTTPProtocol.swift
//  DebugSwift
//
//  Created by Matheus Gois on 15/12/23.
//  Copyright © 2023 apple. All rights reserved.
//

import Foundation

public final class CustomHTTPProtocol: URLProtocol, @unchecked Sendable {
    private static let requestProperty = "com.custom.http.protocol"

    public final class func clearCache() {
        URLCache.customHttp.removeAllCachedResponses()
    }

    public final class func start() {
        URLProtocol.registerClass(self)
    }

    public final class func stop() {
        URLProtocol.unregisterClass(self)
    }

    private final class func canServeRequest(_ request: URLRequest) -> Bool {
        if let _ = property(forKey: requestProperty, in: request) { return false }

        // Never intercept WebSocket requests - they should be handled by WebSocketMonitor
        if let scheme = request.url?.scheme?.lowercased() {
            if scheme == "ws" || scheme == "wss" {
                return false
            }
        }

        for onlyScheme in DebugSwift.Network.shared.onlySchemes {
            if let scheme = request.url?.scheme?.lowercased(), scheme == onlyScheme.rawValue {
                return true
            }
        }

        return false
    }

    public override final class func canInit(with request: URLRequest) -> Bool {
        canServeRequest(request)
    }

    public override final class func canInit(with task: URLSessionTask) -> Bool {
        guard let request = task.currentRequest else { return false }
        return canServeRequest(request)
    }

    public override final class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    private var session: URLSession?
    private var dataTask: URLSessionDataTask?
    private var cachePolicy: URLCache.StoragePolicy = .notAllowed
    private var data: Data = .init()
    private var didRetry = false
    private var didReceiveData = false
    private var startTime = Date()
    private var response: HTTPURLResponse?
    private var error: Error?
    private var prevUrl: URL?
    private var prevStartTime: Date?

    private var threadOperator: ThreadOperator?

    private struct NetworkReportData: @unchecked Sendable {
        let url: URL?
        let method: String?
        let requestBody: Data?
        let requestBodyStream: Data?
        let requestHeaderFields: [String: String]?
        let cachePolicy: UInt
        let requestId: String
        let responseMimeType: String?
        let responseStatusCode: Int?
        let responseHeaderFields: [AnyHashable: Any]?
        let data: Data
        let startTime: Date
        let error: (any Error)?
    }

    private func use(_ cache: CachedURLResponse) {
        DebugSwift.Network.shared.delegate?.urlSession(
            self,
            didReceive: cache.response
        )
        client?.urlProtocol(
            self,
            didReceive: cache.response,
            cacheStoragePolicy: .allowed
        )

        DebugSwift.Network.shared.delegate?.urlSession(
            self,
            didReceive: cache.data
        )
        client?.urlProtocol(
            self,
            didLoad: cache.data
        )

        DebugSwift.Network.shared.delegate?.didFinishLoading(self)
        client?.urlProtocolDidFinishLoading(self)
    }

    public override func startLoading() {
        guard let newRequest = (request as NSObject).mutableCopy() as? NSMutableURLRequest else {
            fatalError("Can not convert to NSMutableURLRequest")
        }

        URLProtocol.setProperty(true, forKey: CustomHTTPProtocol.requestProperty, in: newRequest)
        
        // Track request for threshold monitoring
        if let url = request.url {
            NetworkThresholdTracker.shared.trackRequest(url: url)
        }

        if let cache = URLCache.customHttp.validCache(for: request) {
            use(cache)

            Debug.execute {
                if let name = request.url?.lastPathComponent {
                    Debug.print("Use cache for \(name)")
                } else {
                    Debug.print("Use cache")
                }
            }

            return
        }

        Debug.print(request.requestId)
        threadOperator = ThreadOperator()
        startTime = Date()
        prevUrl = request.url
        prevStartTime = startTime
        
        // Use preserved configuration if available, otherwise fall back to default
        let config = getPreservedConfigurationForRequest() ?? URLSessionConfiguration.default
        
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        dataTask = session?.dataTask(with: newRequest as URLRequest)
        dataTask?.resume()
    }
    
    private func getPreservedConfigurationForRequest() -> URLSessionConfiguration? {
        // Check if we have stored TLS configuration settings
        guard UserDefaults.standard.bool(forKey: "DebugSwift.HasTLSConfig") else {
            return nil
        }
        
        // Create a configuration with preserved TLS settings
        let config = URLSessionConfiguration.default
        
        let minVersion = UserDefaults.standard.integer(forKey: "DebugSwift.TLSMinVersion")
        let maxVersion = UserDefaults.standard.integer(forKey: "DebugSwift.TLSMaxVersion")
        
        if minVersion > 0, let tlsMin = tls_protocol_version_t(rawValue: UInt16(minVersion)) {
            config.tlsMinimumSupportedProtocolVersion = tlsMin
        }
        if maxVersion > 0, let tlsMax = tls_protocol_version_t(rawValue: UInt16(maxVersion)) {
            config.tlsMaximumSupportedProtocolVersion = tlsMax
        }
        
        return config
    }

    public override func stopLoading() {
        dataTask?.cancel()

        if let task = dataTask {
            task.cancel()
            dataTask = nil
        }

        session?.invalidateAndCancel()
        session = nil

        let reportData = NetworkReportData(
            url: request.url,
            method: request.httpMethod,
            requestBody: request.httpBody,
            requestBodyStream: request.httpBodyStream?.toData(),
            requestHeaderFields: request.allHTTPHeaderFields,
            cachePolicy: request.cachePolicy.rawValue,
            requestId: request.requestId,
            responseMimeType: response?.mimeType,
            responseStatusCode: response?.statusCode,
            responseHeaderFields: response?.allHeaderFields,
            data: data,
            startTime: startTime,
            error: error)

        Task { @MainActor in
            guard NetworkHelper.shared.isNetworkEnable
            else { return }
            Self.report(reportData)
        }
    }
    
    @MainActor
    private static func report(_ reportData: NetworkReportData) {
        var model = HttpModel()
        model.url = reportData.url
        model.method = reportData.method
        model.mineType = reportData.responseMimeType

        if let requestBody = reportData.requestBody {
            model.requestData = requestBody
        }

        if let requestBodyStream = reportData.requestBodyStream {
            model.requestData = requestBodyStream
        }

        if let statusCode = reportData.responseStatusCode {
            model.statusCode = "\(statusCode)"
        }

        model.responseData = reportData.data
        model.size = reportData.data.formattedSize()
        model.isImage = (reportData.responseMimeType?.contains("image")) ?? false

        let startTimeDouble = reportData.startTime.timeIntervalSince1970
        let endTimeDouble = Date().timeIntervalSince1970
        let durationDouble = abs(endTimeDouble - startTimeDouble)
        let formattedDuration = String(format: "%.4f", durationDouble)

        model.startTime = "\(reportData.startTime.formatted())"
        model.endTime = "\(Date().formatted())"
        model.totalDuration = "\(formattedDuration) (s)"

        model.errorDescription = reportData.error?.localizedDescription ?? ""
        model.errorLocalizedDescription = reportData.error?.localizedDescription ?? ""
        model.requestHeaderFields = reportData.requestHeaderFields

        if let responseHeaderFields = reportData.responseHeaderFields {
            model.responseHeaderFields = responseHeaderFields.convertKeysToString()
            model.responseHeaderFields?.updateValue(
                getCachePolicyString(value: reportData.cachePolicy),
                forKey: "Cache-Policy")
        }

        if let responseDate = model.endTime {
            model.responseHeaderFields?.updateValue(responseDate, forKey: "Response-Date")
        }

        if reportData.responseMimeType == nil {
            model.isImage = false
        }

        if let urlString = model.url?.absoluteString, urlString.count > 4 {
            let str = String(urlString.suffix(4))
            if ["png", "PNG", "jpg", "JPG", "gif", "GIF"].contains(str) {
                model.isImage = true
            }
        }

        if let urlString = model.url?.absoluteString, urlString.count > 5 {
            let str = String(urlString.suffix(5))
            if ["jpeg", "JPEG"].contains(str) {
                model.isImage = true
            }
        }

        model.requestId = reportData.requestId
        model = ErrorHelper.handle(reportData.error, model: model)
        if HttpDatasource.shared.addHttpRequest(model) {
            NotificationCenter.default.post(
                name: NSNotification.Name("reloadHttp_DebugSwift"),
                object: model.isSuccess)
        }
    }
}

extension CustomHTTPProtocol: URLSessionDataDelegate {
    public func urlSession(
        _: URLSession,
        task _: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        threadOperator?.execute { [weak self] in
            guard let self else { return }
            Debug.print(#function)

            self.client?.urlProtocol(self, wasRedirectedTo: request, redirectResponse: response)
            self.response = response
            completionHandler(request)
        }
    }

    public func urlSession(
        _: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        threadOperator?.execute { [weak self] in
            guard let self else { return }
            Debug.print(#function)

            if let response = response as? HTTPURLResponse, let request = dataTask.originalRequest {
                self.cachePolicy = CacheHelper.cacheStoragePolicy(for: request, and: response)
            }

            DebugSwift.Network.shared.delegate?.urlSession(
                self,
                didReceive: response
            )
            self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: self.cachePolicy)
            self.response = response as? HTTPURLResponse
            completionHandler(.allow)
        }
    }

    public func urlSession(_: URLSession, dataTask _: URLSessionDataTask, didReceive data: Data) {
        threadOperator?.execute { [weak self] in
            guard let self else { return }
            Debug.print(#function)

            var hasAddedData = false
            if self.cachePolicy == .allowed {
                self.data.append(data)
                hasAddedData = true
            }

            DebugSwift.Network.shared.delegate?.urlSession(
                self,
                didReceive: data
            )
            self.client?.urlProtocol(self, didLoad: data)
            self.didReceiveData = true
            if prevUrl == response?.url, prevStartTime == startTime {
                if !hasAddedData { self.data.append(data) }
            } else {
                self.data = data
            }
        }
    }

    private func canRetry(error: NSError) -> Bool {
        guard error.code == Int(CFNetworkErrors.cfurlErrorNetworkConnectionLost.rawValue),
              !didRetry,
              !didReceiveData
        else {
            return false
        }

        Debug.print("Retry download...")
        return true
    }

    private static func getCachePolicyString(value: UInt?) -> String {
        switch value {
        case 0:
            return "useProtocolCachePolicy"
        case 1:
            return "reloadIgnoringLocalCacheData"
        case 4:
            return "reloadIgnoringLocalAndRemoteCacheData"
        case 3:
            return "returnCacheDataDontLoad"
        case 2:
            return "returnCacheDataElseLoad"
        case 5:
            return "reloadRevalidatingCacheData"
        default:
            return "reloadIgnoringCacheData"
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        threadOperator?.execute { [weak self] in
            guard let self else { return }
            if let error {
                self.error = error
                if self.canRetry(error: error as NSError), let request = task.originalRequest {
                    self.didRetry = true
                    self.dataTask = session.dataTask(with: request)
                    self.dataTask?.resume()
                    return
                }
                DebugSwift.Network.shared.delegate?.urlSession(
                    self,
                    didFailWithError: error
                )
                self.client?.urlProtocol(self, didFailWithError: error)
                return
            }

            DebugSwift.Network.shared.delegate?.didFinishLoading(self)
            self.client?.urlProtocolDidFinishLoading(self)

            if self.cachePolicy == .allowed {
                URLCache.customHttp.storeIfNeeded(for: task, data: self.data)
            }
        }
    }
}

extension CustomHTTPProtocol: URLSessionTaskDelegate {
    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        threadOperator?.execute { [weak self] in
            guard let self else { return }
            Debug.print(#function)

            DebugSwift.Network.shared.delegate?.urlSession(
                self,
                session,
                task: task,
                didSendBodyData: bytesSent,
                totalBytesSent: totalBytesSent,
                totalBytesExpectedToSend: totalBytesExpectedToSend
            )
        }
    }
}
