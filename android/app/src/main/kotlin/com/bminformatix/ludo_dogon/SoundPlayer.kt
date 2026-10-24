package com.bminformatix.ludo_dogon

import android.content.Context
import android.media.AudioAttributes
import android.media.SoundPool

/**
 * Sons courts du jeu (dé, cri quand un pion est avalé), joués avec SoundPool
 * pour être instantanés. Les fichiers sont dans res/raw : pour changer un son,
 * il suffit de remplacer le fichier .wav (ou .ogg) en gardant le même nom.
 */
class SoundPlayer(context: Context) {
    private val prefs = context.getSharedPreferences("ludo_dogon", Context.MODE_PRIVATE)

    private val pool: SoundPool = SoundPool.Builder()
        .setMaxStreams(4)
        .setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_GAME)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
        )
        .build()

    private val sounds: Map<String, Int> = mapOf(
        "dice" to pool.load(context, R.raw.de, 1),
        "capture" to pool.load(context, R.raw.cri_avale, 1),
    )

    /** Son activé ou coupé (réglage gardé même après fermeture du jeu). */
    var enabled: Boolean
        get() = prefs.getBoolean("sound", true)
        set(value) {
            prefs.edit().putBoolean("sound", value).apply()
        }

    fun play(name: String) {
        if (!enabled) return
        val id = sounds[name] ?: return
        pool.play(id, 1f, 1f, 1, 0, 1f)
    }

    fun release() {
        pool.release()
    }
}
