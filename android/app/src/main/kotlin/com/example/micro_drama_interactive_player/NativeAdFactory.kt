package com.example.micro_drama_interactive_player

import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.NativeAdFactory

/**
 * Full-screen native ad for the feed's ad pages: media filling the page, a
 * visible "Sponsored" label, then advertiser, headline and call to action over
 * a bottom scrim. Registered with the plugin as [FACTORY_ID].
 */
class FullScreenNativeAdFactory(private val inflater: LayoutInflater) : NativeAdFactory {
    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?,
    ): NativeAdView {
        val adView = inflater.inflate(R.layout.full_screen_native_ad, null) as NativeAdView

        val media = adView.findViewById<MediaView>(R.id.ad_media)
        media.setImageScaleType(ImageView.ScaleType.CENTER_CROP)
        media.setMediaContent(nativeAd.mediaContent)
        adView.mediaView = media

        adView.headlineView = adView.findViewById<TextView>(R.id.ad_headline).apply {
            show(nativeAd.headline)
        }
        adView.advertiserView = adView.findViewById<TextView>(R.id.ad_advertiser).apply {
            show(nativeAd.advertiser)
        }
        adView.callToActionView = adView.findViewById<Button>(R.id.ad_call_to_action).apply {
            show(nativeAd.callToAction)
        }

        adView.setNativeAd(nativeAd)
        return adView
    }

    /** Shows [value], or removes the view when the ad has none. */
    private fun TextView.show(value: String?) {
        text = value
        visibility = if (value.isNullOrBlank()) View.GONE else View.VISIBLE
    }

    companion object {
        /** Must match `AdConfig.nativeFactoryId` on the Dart side. */
        const val FACTORY_ID = "fullScreenNative"
    }
}
