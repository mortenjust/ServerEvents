//
//  ServerEvents.swift
//  StreamGPT
//
//  Created by Morten Just on 4/7/22.
//


/// FILE 1

import Foundation
import Combine


/// Combine wrapper for EventSource

public class ServerEvents : Publisher {
    public typealias Output = String
    public typealias Failure = Error
    
    struct Constants {
        static var end = "[END]"
    }
    
    deinit {
        
        Swift.print("SE deinit")}
    
    var eventSource : EventSource?
    
    var url : URL
    var headers = [String: String]()
    var payload : Data?
    var method : EventSource.Method = .get
    var contentType = "application/json"
    
    public var subject = PassthroughSubject<Output, Failure>()
    
    public init(url: URL, headers: [String:String]? = nil,
         payload: Data?,
         method: EventSource.Method,
         authKey: String? = nil) {

        Swift.print("SSE Init")
        
        self.url = url
        self.headers = headers ?? [String:String]()
        self.payload = payload
        self.method = method
        
        if let authKey = authKey {
            self.headers["Authorization"] = "Bearer \(authKey)"
        }
        self.headers["Content-Type"] = self.contentType
        
    }
    
    public func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, String == S.Input {
        subject.subscribe(subscriber)
        connectToServer(withSubject: subject)
    }
    
    func connectToServer(withSubject subject : PassthroughSubject<Output, Failure>) {
        Swift.print("SSE: connect to server")
        
        eventSource = EventSource(
            url: self.url,
            headers: self.headers,
            method: self.method,
            payloadData: payload)
        
        Swift.print("SSE: event source connecting")
        eventSource?.connect()
        eventSource?.onOpen {
        }
        eventSource?.onComplete({ statusCode, reconnect, error in
            subject.send(completion: .finished)
        })
        
        eventSource?.onMessage({ id, event, data in
            Swift.print("SSE: event source onMessage")
            if let message = data, message != Constants.end {
                subject.send(message)
            }
        })
        
        
    }
    
    
    
    
  
}

