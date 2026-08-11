import CoreGraphics
import GSlidesSchema

/// Conversion constants for the English Metric Unit the Slides API uses for every length.
///
/// EMU are integers by convention, which is why the API can express both inches and points exactly:
/// 914,400 EMU = 1 inch, 12,700 EMU = 1 point.
public enum EMU {
    /// EMU per inch (1 in = 914,400 EMU).
    public static let perInch: Double = 914_400
    /// EMU per typographic point (1 pt = 12,700 EMU).
    public static let perPoint: Double = 12_700

    /// The standard 16:9 page, 10 in × 5.625 in, used when a presentation declares no `pageSize`.
    public static let defaultPageSize = Size(
        width: Dimension(magnitude: 9_144_000, unit: .emu),
        height: Dimension(magnitude: 5_143_500, unit: .emu)
    )
}

extension Dimension {
    /// The magnitude normalized to EMU: PT is converted, EMU and an unspecified unit pass through.
    ///
    /// nil when no magnitude is set. An unspecified unit is read as EMU, matching what the API returns.
    public var emuMagnitude: Double? {
        guard let magnitude else { return nil }
        switch unit {
        case .pt: return magnitude * EMU.perPoint
        default: return magnitude
        }
    }

    /// The magnitude normalized to typographic points — the unit SwiftUI font sizes want.
    public var pointMagnitude: Double? {
        emuMagnitude.map { $0 / EMU.perPoint }
    }
}

/// Turns the API's `size` + `transform` pair into rectangles in EMU page coordinates.
public enum PageGeometry {
    /// The element's axis-aligned frame in EMU page coordinates, origin top-left, y growing down.
    ///
    /// Applies the transform's translation and scale to the base size and normalizes a negative
    /// scale into a positive rectangle. **Shear is ignored** — an element with a non-zero `shearX`
    /// or `shearY` gets the same frame as an unsheared one, so a rotated element reports its
    /// pre-rotation box.
    ///
    /// - Returns: nil when the element declares no size, which is the case for a placeholder that
    ///   has not been resolved against its layout yet. Run `PlaceholderResolver` first.
    public static func frame(of element: PageElement) -> CGRect? {
        guard let width = element.size?.width?.emuMagnitude,
              let height = element.size?.height?.emuMagnitude
        else { return nil }
        let transform = element.transform
        let scaleX = transform?.scaleX ?? 1
        let scaleY = transform?.scaleY ?? 1
        var x = transform?.translateX ?? 0
        var y = transform?.translateY ?? 0
        if transform?.unit == .pt {
            x *= EMU.perPoint
            y *= EMU.perPoint
        }
        // A negative scale is a flip: normalize to a positive rect by moving the origin to the
        // top-left. Positive scales are unaffected (min(·, 0) == 0), so existing geometry is unchanged.
        let signedW = width * scaleX
        let signedH = height * scaleY
        return CGRect(x: x + min(signedW, 0), y: y + min(signedH, 0), width: abs(signedW), height: abs(signedH))
    }

    /// The presentation's page size in EMU, falling back to the standard 16:9 page when unset.
    public static func pageSize(of presentation: Presentation) -> CGSize {
        let size = presentation.pageSize ?? EMU.defaultPageSize
        return CGSize(
            width: size.width?.emuMagnitude ?? 9_144_000,
            height: size.height?.emuMagnitude ?? 5_143_500
        )
    }
}
