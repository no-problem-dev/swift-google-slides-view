import GSlidesSchema

/// Typed accessor over the `Request` oneof — mirrors PageElement.Kind: exactly one member is set.
extension Request {
    public enum Kind: Hashable, Sendable {
        case createSlide(CreateSlideRequest)
        case createShape(CreateShapeRequest)
        case createTable(CreateTableRequest)
        case insertText(InsertTextRequest)
        case deleteObject(DeleteObjectRequest)
        case deleteText(DeleteTextRequest)
        case replaceAllText(ReplaceAllTextRequest)
        case updateTextStyle(UpdateTextStyleRequest)
        case updateParagraphStyle(UpdateParagraphStyleRequest)
        case updateShapeProperties(UpdateShapePropertiesRequest)
        case updatePageElementTransform(UpdatePageElementTransformRequest)
        case createImage(CreateImageRequest)
        case createLine(CreateLineRequest)
        case createVideo(CreateVideoRequest)
        /// A request member outside this profile's typed accessor (still encodes/decodes faithfully).
        case other
    }

    /// The first set member as a typed case. Covers the common authoring requests; everything
    /// still round-trips via the stored optional fields even when it maps to `.other`.
    public var kind: Kind {
        if let r = createSlide { return .createSlide(r) }
        if let r = createShape { return .createShape(r) }
        if let r = createTable { return .createTable(r) }
        if let r = insertText { return .insertText(r) }
        if let r = deleteObject { return .deleteObject(r) }
        if let r = deleteText { return .deleteText(r) }
        if let r = replaceAllText { return .replaceAllText(r) }
        if let r = updateTextStyle { return .updateTextStyle(r) }
        if let r = updateParagraphStyle { return .updateParagraphStyle(r) }
        if let r = updateShapeProperties { return .updateShapeProperties(r) }
        if let r = updatePageElementTransform { return .updatePageElementTransform(r) }
        if let r = createImage { return .createImage(r) }
        if let r = createLine { return .createLine(r) }
        if let r = createVideo { return .createVideo(r) }
        return .other
    }
}

extension Request {
    public static func createSlide(_ r: CreateSlideRequest) -> Request { Request(createSlide: r) }
    public static func createShape(_ r: CreateShapeRequest) -> Request { Request(createShape: r) }
    public static func insertText(_ r: InsertTextRequest) -> Request { Request(insertText: r) }
    public static func deleteObject(_ r: DeleteObjectRequest) -> Request { Request(deleteObject: r) }
    public static func replaceAllText(_ r: ReplaceAllTextRequest) -> Request { Request(replaceAllText: r) }
    public static func updateTextStyle(_ r: UpdateTextStyleRequest) -> Request { Request(updateTextStyle: r) }
}

extension BatchUpdatePresentationRequest {
    public init(requests: [Request], writeControl: WriteControl? = nil) {
        self.init()
        self.requests = requests
        self.writeControl = writeControl
    }
}
