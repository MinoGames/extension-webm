package webm;

import haxe.ds.Option;
import haxe.io.Bytes;

import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.PixelSnapping;
import openfl.events.Event;
import openfl.utils.ByteArray;
import openfl.Lib;
import webm.*;

#if (sys && !neko && !disableThread2)
import webm.ThreadSync;
#end

@:enum
abstract WebmSent(Int) from Int to Int {
    var Frame = 100;
    var Info  = 103;
}

@:enum
abstract WebmReceived(Int) from Int to Int {
    var Play = 400;
    var Stop = 401;
}

@:access(webm.WebmPlayer)
class WebmThread extends Bitmap {

    #if (sys && !neko && !disableThread2)
    var thread:ThreadProcess;
    #else
    var webm:WebmPlayer;
    #end

    public var lastRequestedVideoFrame = 0;
    public var frameRate = 24;
    public var duration = 5;

    public static function create(path:String) {
        var webm = new WebmThread(path);
        return webm;
    }

    public function getId() {
        #if (sys && !neko && !disableThread2)
        return thread.id;
        #else
        return -1;
        #end
    }

    public function new(path:String) {
        super(null, PixelSnapping.AUTO, true);

        #if (sys && !neko && !disableThread2)
        thread = ThreadSync.create(path, function(sendMessage, path) {
            // Initialization

            // Create WebSocket object
            var webm = new WebmPlayer(new WebmIoFile(path), false, true, function(bytes) {
                sendMessage(Frame, bytes);
            });
            webm.play();

            sendMessage(Info, { width: webm.width, height: webm.height });

            return {
            fps: webm.frameRate,    
            received: function(type, data) {
                // Message Received from Thread
                return switch(type) {
                    case Play : 
                        webm.play();
                        false;
                    case Stop : 
                        webm.stop();
                        true;
                    default: 
                        false;
                }
                // -- Received
            }, processed: function() {
                webm.process();
            }, disposed: function() {
                webm.dispose();
            }};
            // -- Initialization
        }, function(type, data) {
            // Message Sent from Thread
            switch(type) {
                case Info  : 
                    bitmapData = new BitmapData(data.width, data.width, true, 0x00000000);
                    smoothing = true;
                case Frame : 
                    if (bitmapData != null) onFrame(cast data);
                case -1:
                    if (bitmapData != null) bitmapData.dispose();
            }
            // -- Sent
        });
        #else
        // Create WebSocket object
        webm = new WebmPlayer(new WebmIoFile(path), false, true, function(bytes) {
            onFrame(bytes);
        });
        bitmapData = new BitmapData(webm.width2, webm.width2, true, 0x00000000);
        webm.play();
        #end
    }

    public function play() {
        #if (sys && !neko && !disableThread2)
        thread.sendMessage(Play, {});
        #else
        webm.play();
        #end
    }

    function onFrame(bytes) {
        var byteArray:ByteArray = ByteArray.fromBytes(bytes);

        bitmapData.lock();
        bitmapData.setPixels(bitmapData.rect, byteArray);
        bitmapData.unlock();

        smoothing = true;
    }

    public function stop() {
        #if (sys && !neko && !disableThread2)
        thread.sendMessage(Stop, {});
        #else
        webm.stop();
        webm.dispose();
        #end
    }

    public function dispose() {
        stop();

        if (bitmapData != null) bitmapData.dispose();
        bitmapData = null;
    }

    public function destroy() {
        // Stop
        stop();
    }
}
