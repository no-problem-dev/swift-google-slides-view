import CoreGraphics
import GSlidesSchema

/// English Metric Unit constants used by the Slides API for all length values.
/// 914,400 EMU = 1 inch; 12,700 EMU = 1 point.
public enum EMU {
    /// EMU per inch (1 inch = 914,400 EMU).
    public static let perInch: Double = 914_400
    /// EMU per typographic point (1 pt = 12,700 EMU).
    public static let perPoint: Double = 12_700

    /// Standard 16:9 page (10in × 5.625in).
    public static let defaultPageSize = Size(
        width: Dimension(magnitude: 9_144_000, unit: .emu),
        height: Dimension(magnitude: 5_143_500, unit: .emu)
    )
}

extension Dimension {
    /// Magnitude normalized to EMU (PT values are converted, EMU passes through).
    public var emuMagnitude: Double? {
        guard let magnitude else { return nil }
        switch unit {
        case .pt: return magnitude * EMU.perPoint
        default: return magnitude
        }
    }

    public var pointMagnitude: Double? {
        emuMagnitude.map { $0 / EMU.perPoint }
    }
}

public enum PageGeometry {
    /// Element frame in EMU page coordinates: translate + scale applied to the base size
    /// (shear is out of profile and ignored).
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

    public static func pageSize(of presentation: Presentation) -> CGSize {
        let size = presentation.pageSize ?? EMU.defaultPageSize
        return CGSize(
            width: size.width?.emuMagnitude ?? 9_144_000,
            height: size.height?.emuMagnitude ?? 5_143_500
        )
    }
}
