import GoogleMobileAds
import UIKit
import google_mobile_ads

/// Full-screen native ad for the feed's ad pages: media filling the page, a
/// visible "Sponsored" label, then advertiser, headline and call to action
/// over a bottom scrim. Registered with the plugin as `factoryId`.
final class FullScreenNativeAdFactory: NSObject, FLTNativeAdFactory {
  /// Must match `AdConfig.nativeFactoryId` on the Dart side.
  static let factoryId = "fullScreenNative"

  private static let background = UIColor(red: 9 / 255, green: 9 / 255, blue: 13 / 255, alpha: 1)

  func createNativeAd(
    _ nativeAd: NativeAd,
    customOptions: [AnyHashable: Any]? = nil
  ) -> NativeAdView? {
    let adView = NativeAdView()
    adView.backgroundColor = Self.background

    let media = MediaView()
    media.contentMode = .scaleAspectFill
    media.clipsToBounds = true
    media.mediaContent = nativeAd.mediaContent

    let scrim = GradientView()

    let sponsored = PaddedLabel()
    sponsored.text = "Sponsored"
    sponsored.font = .systemFont(ofSize: 12, weight: .bold)
    sponsored.textColor = .white
    sponsored.backgroundColor = UIColor.black.withAlphaComponent(0.35)
    sponsored.layer.cornerRadius = 6
    sponsored.clipsToBounds = true

    let advertiser = UILabel()
    advertiser.font = .systemFont(ofSize: 14)
    advertiser.textColor = UIColor.white.withAlphaComponent(0.7)
    show(nativeAd.advertiser, in: advertiser)

    let headline = UILabel()
    headline.font = .systemFont(ofSize: 22, weight: .bold)
    headline.textColor = .white
    headline.numberOfLines = 2
    show(nativeAd.headline, in: headline)

    let callToAction = UIButton(type: .custom)
    callToAction.backgroundColor = .white
    callToAction.layer.cornerRadius = 26
    callToAction.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
    callToAction.setTitleColor(Self.background, for: .normal)
    callToAction.setTitle(nativeAd.callToAction, for: .normal)
    callToAction.isHidden = nativeAd.callToAction == nil
    // The SDK handles taps on the registered call-to-action view.
    callToAction.isUserInteractionEnabled = false

    let details = UIStackView(arrangedSubviews: [advertiser, headline, callToAction])
    details.axis = .vertical
    details.spacing = 4
    details.setCustomSpacing(16, after: headline)

    for view in [media, scrim, sponsored, details] {
      view.translatesAutoresizingMaskIntoConstraints = false
      adView.addSubview(view)
    }
    let safeArea = adView.safeAreaLayoutGuide
    NSLayoutConstraint.activate([
      media.topAnchor.constraint(equalTo: adView.topAnchor),
      media.bottomAnchor.constraint(equalTo: adView.bottomAnchor),
      media.leadingAnchor.constraint(equalTo: adView.leadingAnchor),
      media.trailingAnchor.constraint(equalTo: adView.trailingAnchor),

      scrim.bottomAnchor.constraint(equalTo: adView.bottomAnchor),
      scrim.leadingAnchor.constraint(equalTo: adView.leadingAnchor),
      scrim.trailingAnchor.constraint(equalTo: adView.trailingAnchor),
      scrim.heightAnchor.constraint(equalToConstant: 360),

      sponsored.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: 12),
      sponsored.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 16),

      details.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 20),
      details.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -20),
      details.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor, constant: -24),
      callToAction.heightAnchor.constraint(equalToConstant: 52),
    ])

    adView.mediaView = media
    adView.headlineView = headline
    adView.advertiserView = advertiser
    adView.callToActionView = callToAction
    adView.nativeAd = nativeAd
    return adView
  }

  /// Shows [text], or hides the label when the ad has none.
  private func show(_ text: String?, in label: UILabel) {
    label.text = text
    label.isHidden = text?.isEmpty ?? true
  }
}

/// A vertical gradient that keeps the ad's text legible over bright media.
private final class GradientView: UIView {
  override class var layerClass: AnyClass { CAGradientLayer.self }

  override init(frame: CGRect) {
    super.init(frame: frame)
    isUserInteractionEnabled = false
    if let gradient = layer as? CAGradientLayer {
      gradient.colors = [
        UIColor.clear.cgColor,
        UIColor.black.withAlphaComponent(0.85).cgColor,
      ]
    }
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) is not supported")
  }
}

/// A label with room around its text, for the "Sponsored" badge.
private final class PaddedLabel: UILabel {
  private let insets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)

  override func drawText(in rect: CGRect) {
    super.drawText(in: rect.inset(by: insets))
  }

  override var intrinsicContentSize: CGSize {
    let size = super.intrinsicContentSize
    return CGSize(
      width: size.width + insets.left + insets.right,
      height: size.height + insets.top + insets.bottom
    )
  }
}
