import Foundation

/// The addresses Sphere shows and the App Store record points at.
///
/// One place, because they have to agree in three: the links in this app, the
/// Privacy Policy and Support URLs in App Store Connect, and the pages
/// themselves. A record whose privacy URL is not the page the app links to is a
/// rejection with a one-line reason.
enum SphereLinks {
    static let privacyPolicy = URL(string: "https://smidgecraft.com/sphere/privacy")!
    static let support = URL(string: "https://smidgecraft.com/sphere/support")!
    static let contactEmail = "mason@smidgecraft.com"
}
