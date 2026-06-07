import CoreGraphics
import GSlidesSchema

public enum EMU {
    public static let perInch: Double = 914_400
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
        return CGRect(x: x, y: y, width: width * scaleX, height: height * scaleY)
    }

    public static func pageSize(of presentation: Presentation) -> CGSize {
        let size = presentation.pageSize ?? EMU.defaultPageSize
        return CGSize(
            width: size.width?.emuMagnitude ?? 9_144_000,
            height: size.height?.emuMagnitude ?? 5_143_500
        )
    }
}
