public struct StretchedPictureFill: Codable, Equatable, Sendable {
    public var contentUrl: String?
    public var size: Size?

    public init(contentUrl: String? = nil, size: Size? = nil) {
        self.contentUrl = contentUrl
        self.size = size
    }
}

public struct PageBackgroundFill: Codable, Equatable, Sendable {
    public var propertyState: PropertyState?
    public var solidFill: SolidFill?
    public var stretchedPictureFill: StretchedPictureFill?

    public init(
        propertyState: PropertyState? = nil,
        solidFill: SolidFill? = nil,
        stretchedPictureFill: StretchedPictureFill? = nil
    ) {
        self.propertyState = propertyState
        self.solidFill = solidFill
        self.stretchedPictureFill = stretchedPictureFill
    }
}

public struct PageProperties: Codable, Equatable, Sendable {
    public var pageBackgroundFill: PageBackgroundFill?
    public var colorScheme: ColorScheme?

    public init(pageBackgroundFill: PageBackgroundFill? = nil, colorScheme: ColorScheme? = nil) {
        self.pageBackgroundFill = pageBackgroundFill
        self.colorScheme = colorScheme
    }
}
