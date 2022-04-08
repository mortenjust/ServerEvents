

import Foundation


public enum EventSourceState {
    case connecting
    case open
    case closed
}

public protocol EventSourceProtocol {
    
    
    
    var headers: [String: String] { get }

    /// RetryTime: This can be changed remotly if the server sends an event `retry:`
    var retryTime: Int { get }

    /// URL where EventSource will listen for events.
    var url: URL { get }

    /// The last event id received from server. This id is neccesary to keep track of the last event-id received to avoid
    /// receiving duplicate events after a reconnection.
    var lastEventId: String? { get }

    /// Current state of EventSource
    var readyState: EventSourceState { get }

    /// Method used to connect to server. It can receive an optional lastEventId indicating the Last-Event-ID
    ///
    /// - Parameter lastEventId: optional value that is going to be added on the request header to server.
    func connect(lastEventId: String?)

    /// Method used to disconnect from server.
    func disconnect()

    /// Returns the list of event names that we are currently listening for.
    ///
    /// - Returns: List of event names.
    func events() -> [String]

    /// Callback called when EventSource has successfully connected to the server.
    ///
    /// - Parameter onOpenCallback: callback
    func onOpen(_ onOpenCallback: @escaping (() -> Void))

    /// Callback called once EventSource has disconnected from server. This can happen for multiple reasons.
    /// The server could have requested the disconnection or maybe a network layer error, wrong URL or any other
    /// error. The callback receives as parameters the status code of the disconnection, if we should reconnect or not
    /// following event source rules and finally the network layer error if any. All this information is more than
    /// enought for you to take a decition if you should reconnect or not.
    /// - Parameter onOpenCallback: callback
    func onComplete(_ onComplete: @escaping ((Int?, Bool?, NSError?) -> Void))

    /// This callback is called everytime an event with name "message" or no name is received.
    func onMessage(_ onMessageCallback: @escaping ((_ id: String?, _ event: String?, _ data: String?) -> Void))

    /// Add an event handler for an specific event name.
    ///
    /// - Parameters:
    ///   - event: name of the event to receive
    ///   - handler: this handler will be called everytime an event is received with this event-name
    func addEventListener(_ event: String,
                          handler: @escaping ((_ id: String?, _ event: String?, _ data: String?) -> Void))

    /// Remove an event handler for the event-name
    ///
    /// - Parameter event: name of the listener to be remove from event source.
    func removeEventListener(_ event: String)
}
