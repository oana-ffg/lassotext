import CoreGraphics
import LassoCore
import Testing

struct SelectionGeometryTests {
    @Test func convertsRetinaAndFlipsVerticalOrigin() {
        #expect(SelectionGeometry.pixelRect(selection: CGRect(x: 20, y: 30, width: 100, height: 40),
                                            viewSize: CGSize(width: 500, height: 400),
                                            imageSize: CGSize(width: 1000, height: 800))
                == CGRect(x: 40, y: 660, width: 200, height: 80))
    }

    @Test func clipsAndRejectsAccidentalClick() {
        let size = CGSize(width: 500, height: 400)
        #expect(SelectionGeometry.pixelRect(selection: CGRect(x: -10, y: -20, width: 100, height: 80),
                                            viewSize: size, imageSize: size) == CGRect(x: 0, y: 340, width: 90, height: 60))
        #expect(SelectionGeometry.pixelRect(selection: CGRect(x: 10, y: 10, width: 1, height: 1),
                                            viewSize: size, imageSize: size) == nil)
        #expect(SelectionGeometry.pixelRect(selection: CGRect(x: 800, y: 800, width: 50, height: 50),
                                            viewSize: size, imageSize: size) == nil)
    }

    @Test func handlesReverseDragAndDifferentScaleAxes() {
        #expect(SelectionGeometry.pixelRect(selection: CGRect(x: 120, y: 70, width: -100, height: -40),
                                            viewSize: CGSize(width: 500, height: 400),
                                            imageSize: CGSize(width: 1000, height: 1200))
                == CGRect(x: 40, y: 990, width: 200, height: 120))
    }
}
