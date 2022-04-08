//
//  EventSource.swift
//  EventSource
//
//  Created by Andres on 2/13/15.
//  Copyright (c) 2015 Inaka. All rights reserved.
//

import Foundation


open class EventSource: NSObject, EventSourceProtocol, URLSessionDataDelegate {
    
    public enum Method : String {
        case post = "POST"
        case get = "GET"
    }
    
    
    static let DefaultRetryTime = 3000

    public let url: URL
    public var method : Method = .get
    public var payloadData : Data?
    
    
    private(set) public var lastEventId: String?
    private(set) public var retryTime = EventSource.DefaultRetryTime
    private(set) public var headers: [String: String]
    private(set) public var readyState: EventSourceState

    private var onOpenCallback: (() -> Void)?
    private var onComplete: ((Int?, Bool?, NSError?) -> Void)?
    private var onMessageCallback: ((_ id: String?, _ event: String?, _ data: String?) -> Void)?
    private var eventListeners: [String: (_ id: String?, _ event: String?, _ data: String?) -> Void] = [:]

    private var eventStreamParser: EventStreamParser?
    private var operationQueue: OperationQueue
    private var mainQueue = DispatchQueue.main
    private var urlSession: URLSession?

    // MARK: Init
    public init(
        url: URL,
        headers: [String: String] = [:],
        method: Method = .get,
        payloadData : Data? = nil
    ) {
        self.url = url
        self.headers = headers
        self.method = method
        self.payloadData = payloadData

        readyState = EventSourceState.closed
        operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 1

        super.init()
    }
    
    // MARK: Connect with URLSession
    public func connect(lastEventId: String? = nil) {
        eventStreamParser = EventStreamParser()
        readyState = .connecting

        let configuration = sessionConfiguration(lastEventId: lastEventId)
        urlSession = URLSession(configuration: configuration, delegate: self, delegateQueue: operationQueue)

        var urlRequest = URLRequest(url: self.url)
        urlRequest.httpMethod = self.method.rawValue

        if let payloadData = payloadData {
            urlRequest.httpBody = payloadData
        }
        
        urlSession!.dataTask(with: urlRequest).resume()
    }

    public func disconnect() {
        readyState = .closed
        urlSession?.invalidateAndCancel()
    }

    public func onOpen(_ onOpenCallback: @escaping (() -> Void)) {
        self.onOpenCallback = onOpenCallback
    }

    public func onComplete(_ onComplete: @escaping ((Int?, Bool?, NSError?) -> Void)) {
        self.onComplete = onComplete
    }

    public func onMessage(_ onMessageCallback: @escaping ((_ id: String?, _ event: String?, _ data: String?) -> Void)) {
        self.onMessageCallback = onMessageCallback
    }

    public func addEventListener(_ event: String,
                                 handler: @escaping ((_ id: String?, _ event: String?, _ data: String?) -> Void)) {
        eventListeners[event] = handler
    }

	public func removeEventListener(_ event: String) {
		eventListeners.removeValue(forKey: event)
	}

	public func events() -> [String] {
		return Array(eventListeners.keys)
	}
    
    
    // MARK: URLSession delegate callbacks

    open func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
//        print("session: received data", String(data: data, encoding: .utf8))
        
		if readyState != .open {
            return
        }

        if let events = eventStreamParser?.append(data: data) {
            notifyReceivedEvents(events)
        }
    }

    open func urlSession(_ session: URLSession,
                         dataTask: URLSessionDataTask,
                         didReceive response: URLResponse,
                         completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {

//        print("session: didreceive -> onOpencallback")
        completionHandler(URLSession.ResponseDisposition.allow)

        readyState = .open
        mainQueue.async { [weak self] in self?.onOpenCallback?() }
    }

    open func urlSession(_ session: URLSession,
                         task: URLSessionTask,
                         didCompleteWithError error: Error?) {

//        print("session: diderror -> oncomplete with err")
        
        guard let responseStatusCode = (task.response as? HTTPURLResponse)?.statusCode else {
            mainQueue.async { [weak self] in self?.onComplete?(nil, nil, error as NSError?) }
            return
        }

        let reconnect = shouldReconnect(statusCode: responseStatusCode)
        mainQueue.async { [weak self] in self?.onComplete?(responseStatusCode, reconnect, nil) }
    }

    open func urlSession(_ session: URLSession,
                         task: URLSessionTask,
                         willPerformHTTPRedirection response: HTTPURLResponse,
                         newRequest request: URLRequest,
                         completionHandler: @escaping (URLRequest?) -> Void) {

//        print("session: willperformredirect -> newrequest")
        var newRequest = request
        self.headers.forEach { newRequest.setValue($1, forHTTPHeaderField: $0) }
        completionHandler(newRequest)
    }
}

internal extension EventSource {

    
    // MARK: URSessionConfiguration
    func sessionConfiguration(lastEventId: String?) -> URLSessionConfiguration {

        var additionalHeaders = headers
        if let eventID = lastEventId {
            additionalHeaders["Last-Event-Id"] = eventID
        }

        additionalHeaders["Accept"] = "text/event-stream"
        additionalHeaders["Cache-Control"] = "no-cache"

        let sessionConfiguration = URLSessionConfiguration.default
        sessionConfiguration.timeoutIntervalForRequest = TimeInterval(INT_MAX)
        sessionConfiguration.timeoutIntervalForResource = TimeInterval(INT_MAX)
        sessionConfiguration.httpAdditionalHeaders = additionalHeaders
        
        

        return sessionConfiguration
    }

    func readyStateOpen() {
        readyState = .open
    }
}

private extension EventSource {

    func notifyReceivedEvents(_ events: [Event]) {

        for event in events {
            lastEventId = event.id
            retryTime = event.retryTime ?? EventSource.DefaultRetryTime

            if event.onlyRetryEvent == true {
                continue
            }

            if event.event == nil || event.event == "message" {
                mainQueue.async { [weak self] in self?.onMessageCallback?(event.id, "message", event.data) }
            }

            if let eventName = event.event, let eventHandler = eventListeners[eventName] {
                mainQueue.async { eventHandler(event.id, event.event, event.data) }
            }
        }
    }

    // Following "5 Processing model" from:
    // https://www.w3.org/TR/2009/WD-eventsource-20090421/#handler-eventsource-onerror
    func shouldReconnect(statusCode: Int) -> Bool {
        switch statusCode {
        case 200:
            return false
        case _ where statusCode > 200 && statusCode < 300:
            return true
        default:
            return false
        }
    }
}
