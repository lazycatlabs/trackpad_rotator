import SwiftUI

// MARK: - Tokens
// Every size, spacing, radius and opacity in the UI comes from here, so the look can be tuned in one place.

enum Spacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 6
    static let md: CGFloat = 8
    static let lg: CGFloat = 10
    static let xl: CGFloat = 12
    static let xxl: CGFloat = 16
    static let page: CGFloat = 20
}

enum Radius {
    static let md: CGFloat = 8
    static let lg: CGFloat = 10
}

enum Opacity {
    /// Untouched (hovering) fingers in the touch preview.
    static let faint = 0.25
    /// Tinted backgrounds: the permission banner, the pad's face.
    static let fill = 0.12
    static let border = 0.5
    static let muted = 0.6
    /// Fingers touching the pad in the touch preview.
    static let strong = 0.85
}

enum Metrics {
    static let hairline: CGFloat = 1

    enum Main {
        static let columnSpacing: CGFloat = 14
        static let sidebarWidth: CGFloat = 320
        static let previewCaptionWidth: CGFloat = 520
        /// How often the "Trackpad in use" label is re-read, in seconds.
        static let activityRefresh = 0.1
    }

    enum MenuBar {
        static let width: CGFloat = 340
        static let padding: CGFloat = 14
    }

    enum WhatsNew {
        static let size = CGSize(width: 460, height: 420)
    }

    enum Speed {
        static let range = 0.25...3.0
        static let step = 0.05
    }

    /// The live touch preview: two pads drawn on a `Canvas`.
    enum Pad {
        static let frameRate = 60.0
        static let canvas: CGFloat = 240
        static let readoutHeight: CGFloat = 30
        /// Space kept between the pad and the canvas edge, on each side.
        static let inset: CGFloat = 10
        /// Magic Trackpad, used when the device doesn't report its size.
        static let defaultSizeMM = (w: 160.0, h: 115.0)

        /// The "pad top" marker: its length either side of centre and its label's position, as shares of the pad.
        static let topEdgeHalfLength = 0.2
        static let topLabelPosition = 0.78
        static let topEdgeWidth: CGFloat = 4

        /// The "pad +X" arrow: half its length and how far below centre it sits, as shares of the pad.
        static let axisHalfLength = 0.15
        static let axisOffset = 0.32
        static let axisWidth: CGFloat = 1.5
        static let axisHeadRadius: CGFloat = 3
        static let axisLabelLift: CGFloat = 9

        /// Finger dots: the reported touch size times `touchScale`, kept between these radii.
        static let touchRadius: ClosedRange<Double> = 9...22
        static let touchScale = 14.0
    }
}
