// SPDX-License-Identifier: GPL-3.0-or-later
package aora.aoranet.aoravpn

import android.animation.ValueAnimator
import android.app.Activity
import android.os.Build
import android.view.animation.DecelerateInterpolator

internal object AndroidSplash {
    fun configure(activity: Activity) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
        activity.splashScreen.setOnExitAnimationListener { splash ->
            if (!ValueAnimator.areAnimatorsEnabled()) {
                splash.remove()
            } else {
                splash.animate()
                    .alpha(0f)
                    .setDuration(140L)
                    .setInterpolator(DecelerateInterpolator())
                    .withEndAction { splash.remove() }
                    .start()
            }
        }
    }
}
