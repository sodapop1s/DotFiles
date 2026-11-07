import QtQuick
import Quickshell.Io

// Runs `bash <script> <args...>` and hands the parsed JSON (or null) plus the raw text to a callback.
Process {
    id: job
    required property string script
    property var done: null
    stdout: StdioCollector {
        onStreamFinished: {
            var r = null
            try { r = JSON.parse(text) } catch(e) {}
            if (job.done) job.done(r, text)
        }
    }
    // returns false if a previous run is still going
    function go(args, cb) {
        if (running) return false
        done = cb
        command = ["bash", script].concat(args)
        running = true
        return true
    }
}
