import GSlidesSchema

// The typed `Request.Kind` accessor and per-kind factories are generated from the discovery
// `Request` schema (see GeneratedRequests.swift) so they can never drift from the wire protocol.
// Only this hand-written convenience — assembling a batch — lives here.
extension BatchUpdatePresentationRequest {
    /// Builds a batch from an ordered list of requests.
    ///
    /// Order matters: the API applies them in sequence, so a request may depend on one before it.
    public init(requests: [Request], writeControl: WriteControl? = nil) {
        self.init()
        self.requests = requests
        self.writeControl = writeControl
    }
}
