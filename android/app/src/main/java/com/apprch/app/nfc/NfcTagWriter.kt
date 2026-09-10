package com.apprch.app.nfc

import android.app.Activity
import android.nfc.FormatException
import android.nfc.NdefMessage
import android.nfc.NdefRecord
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.nfc.tech.Ndef
import android.nfc.tech.NdefFormatable
import android.os.Bundle
import java.io.IOException

class NfcTagWriter(private val activity: Activity) {
    enum class Status {
        Idle,
        Waiting,
        Success,
        Failed
    }

    var status: Status = Status.Idle
        private set
    var message: String = ""
        private set

    private val adapter: NfcAdapter? = NfcAdapter.getDefaultAdapter(activity)
    private var urlToWrite: String? = null
    private var onChange: ((Status, String) -> Unit)? = null

    val isHardwarePresent: Boolean get() = adapter != null
    val isAvailable: Boolean get() = adapter?.isEnabled == true

    val unavailableMessage: String
        get() = when {
            adapter == null -> "This device doesn’t have NFC."
            adapter.isEnabled != true -> "Turn on NFC in Settings, then try again."
            else -> "Hold your phone on the tag to write this Task."
        }

    fun startWrite(url: String, onChange: (Status, String) -> Unit) {
        this.onChange = onChange
        if (!isAvailable) {
            publish(Status.Failed, unavailableMessage)
            return
        }
        urlToWrite = url
            publish(Status.Waiting, "Hold your phone on the tag to write this Task.")
        adapter?.enableReaderMode(
            activity,
            ::onTag,
            NfcAdapter.FLAG_READER_NFC_A or
                NfcAdapter.FLAG_READER_NFC_B or
                NfcAdapter.FLAG_READER_NFC_F or
                NfcAdapter.FLAG_READER_NFC_V or
                NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK,
            Bundle()
        )
    }

    fun stop() {
        runCatching { adapter?.disableReaderMode(activity) }
        urlToWrite = null
        if (status == Status.Waiting) {
            publish(Status.Idle, "")
        }
    }

    private fun onTag(tag: Tag) {
        val url = urlToWrite ?: return
        val result = write(url, tag)
        activity.runOnUiThread {
            adapter?.disableReaderMode(activity)
            urlToWrite = null
            if (result == null) {
                publish(Status.Success, "Tag written.")
            } else {
                publish(Status.Failed, result)
            }
        }
    }

    private fun write(url: String, tag: Tag): String? {
        val record = NdefRecord.createUri(url)
        val message = NdefMessage(arrayOf(record))
        val bytes = message.toByteArray()
        Ndef.get(tag)?.use { ndef ->
            try {
                ndef.connect()
                if (!ndef.isWritable) return "This tag is locked and can’t be written."
                if (ndef.maxSize < bytes.size) return "This tag doesn’t have enough space."
                ndef.writeNdefMessage(message)
                return null
            } catch (_: FormatException) {
                return "Couldn’t write this tag."
            } catch (_: IOException) {
                return "Keep the tag still and try again."
            }
        }
        NdefFormatable.get(tag)?.use { formatable ->
            try {
                formatable.connect()
                formatable.format(message)
                return null
            } catch (_: FormatException) {
                return "This tag isn’t writable."
            } catch (_: IOException) {
                return "Keep the tag still and try again."
            }
        }
        return "This tag isn’t writable."
    }

    private fun publish(next: Status, text: String) {
        status = next
        message = text
        onChange?.invoke(next, text)
    }
}
