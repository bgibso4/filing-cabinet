#if canImport(UIKit)
    import CoreGraphics
    import Testing
    import UIKit

    @testable import Screens

    @MainActor
    struct ZoomableScrollViewTests {
        private func image(width: Int, height: Int) throws -> CGImage {
            let context = try #require(
                CGContext(
                    data: nil,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: 0,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            return try #require(context.makeImage())
        }

        /// A 400 by 800 screen with 100 pt reserved above and below, so a 400 by 600 region.
        private func page(showing image: CGImage?, key: String = "a") -> ZoomableScrollView {
            let view = ZoomableScrollView()
            view.frame = CGRect(x: 0, y: 0, width: 400, height: 800)
            view.fitInsets = UIEdgeInsets(top: 100, left: 0, bottom: 100, right: 0)
            view.show(image, pageKey: key)
            view.layoutIfNeeded()
            return view
        }

        @Test func aTallPageFitsTheRegionHeightAndIsCentredAcross() throws {
            let view = page(showing: try image(width: 100, height: 200))
            #expect(view.contentSize == CGSize(width: 300, height: 600))
            #expect(view.contentInset == UIEdgeInsets(top: 100, left: 50, bottom: 100, right: 50))
            #expect(view.contentOffset == CGPoint(x: -50, y: -100))
        }

        @Test func aWidePageFitsTheWidthAndIsCentredInTheRegion() throws {
            let view = page(showing: try image(width: 200, height: 100))
            #expect(view.contentSize == CGSize(width: 400, height: 200))
            #expect(view.contentInset == UIEdgeInsets(top: 300, left: 0, bottom: 300, right: 0))
            #expect(view.contentOffset == CGPoint(x: 0, y: -300))
        }

        @Test func zoomRunsFromOneToFour() throws {
            let view = page(showing: try image(width: 100, height: 200))
            #expect(view.minimumZoomScale == 1)
            #expect(view.maximumZoomScale == 4)
        }

        @Test func itOnlyScrollsWhenZoomed() throws {
            let view = page(showing: try image(width: 100, height: 200))
            #expect(!view.isScrollEnabled)
            view.setZoomScale(2, animated: false)
            #expect(view.isScrollEnabled)
            view.setZoomScale(1, animated: false)
            #expect(!view.isScrollEnabled)
            #expect(view.contentOffset == CGPoint(x: -50, y: -100))
        }

        @Test func aZoomedPageLargerThanTheScreenReachesItsEdges() throws {
            let view = page(showing: try image(width: 100, height: 200))
            // 600 by 1200: bigger than the 400 by 800 screen both ways, so nothing is held back for the controls.
            view.setZoomScale(2, animated: false)
            #expect(view.contentInset == .zero)
        }

        @Test func doubleTapTogglesTwoTimes() throws {
            let view = page(showing: try image(width: 100, height: 200))
            view.toggleZoom(at: CGPoint(x: 150, y: 300), animated: false)
            #expect(view.zoomScale == 2)
            view.toggleZoom(at: CGPoint(x: 150, y: 300), animated: false)
            #expect(view.zoomScale == 1)
        }

        @Test func anotherPageStartsAtOneTime() throws {
            let view = page(showing: try image(width: 100, height: 200))
            view.setZoomScale(3, animated: false)
            view.show(try image(width: 200, height: 100), pageKey: "b")
            view.layoutIfNeeded()
            #expect(view.zoomScale == 1)
            #expect(view.contentSize == CGSize(width: 400, height: 200))
        }

        @Test func theSamePageKeepsItsZoomWhenItsImageIsShownAgain() throws {
            let picture = try image(width: 100, height: 200)
            let view = page(showing: picture)
            view.setZoomScale(3, animated: false)
            view.show(picture, pageKey: "a")
            view.layoutIfNeeded()
            #expect(view.zoomScale == 3)
        }

        @Test func aPageWithoutAnImageYetTakesItWhenItArrives() throws {
            let view = page(showing: nil)
            #expect(view.contentSize == .zero)
            view.show(try image(width: 100, height: 200), pageKey: "a")
            view.layoutIfNeeded()
            #expect(view.contentSize == CGSize(width: 300, height: 600))
        }
    }
#endif
